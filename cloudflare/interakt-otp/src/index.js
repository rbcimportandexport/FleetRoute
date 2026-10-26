import { createHash } from 'node:crypto';

const json = (body, status = 200, request) => {
  const origin = request?.headers.get('Origin') || '*';
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Cache-Control': 'no-store',
      'Vary': 'Origin',
    },
  });
};

const b64url = bytes => btoa(String.fromCharCode(...bytes))
  .replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');

const fromB64url = value => {
  const normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  return Uint8Array.from(atob(padded), character => character.charCodeAt(0));
};

async function md5(value) {
  return createHash('md5').update(value).digest('hex');
}

let firebaseJwks = null;
let firebaseJwksExpiresAt = 0;
let protrackToken = '';
let protrackTokenExpiresAt = 0;

async function requireFirebaseFleetUser(request) {
  const authorization = request.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) throw new Error('UNAUTHENTICATED');
  const token = authorization.slice(7).trim();
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('UNAUTHENTICATED');
  let header;
  let payload;
  try {
    header = JSON.parse(new TextDecoder().decode(fromB64url(parts[0])));
    payload = JSON.parse(new TextDecoder().decode(fromB64url(parts[1])));
  } catch {
    throw new Error('UNAUTHENTICATED');
  }
  const now = Math.floor(Date.now() / 1000);
  if (header.alg !== 'RS256' || !header.kid || payload.aud !== 'transport-one' ||
      payload.iss !== 'https://securetoken.google.com/transport-one' ||
      !payload.sub || payload.exp <= now || payload.iat > now + 60) {
    throw new Error('UNAUTHENTICATED');
  }
  if (!firebaseJwks || Date.now() >= firebaseJwksExpiresAt) {
    const response = await fetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
    if (!response.ok) throw new Error('AUTH_SERVICE_UNAVAILABLE');
    firebaseJwks = await response.json();
    const maxAge = Number((response.headers.get('cache-control') || '').match(/max-age=(\d+)/)?.[1] || 3600);
    firebaseJwksExpiresAt = Date.now() + Math.min(maxAge, 21600) * 1000;
  }
  const jwk = firebaseJwks.keys?.find(key => key.kid === header.kid);
  if (!jwk) throw new Error('UNAUTHENTICATED');
  const key = await crypto.subtle.importKey(
    'jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', key, fromB64url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!valid) throw new Error('UNAUTHENTICATED');
  if (!['admin', 'super_admin', 'driver'].includes(payload.role)) throw new Error('FORBIDDEN');
  return payload;
}

async function getProtrackToken(env) {
  if (protrackToken && Date.now() < protrackTokenExpiresAt) return protrackToken;
  if (!env.PROTRACK_ACCOUNT || !env.PROTRACK_PASSWORD) throw new Error('PROTRACK_NOT_CONFIGURED');
  const time = Math.floor(Date.now() / 1000);
  const signature = await md5(`${await md5(env.PROTRACK_PASSWORD)}${time}`);
  const url = new URL('https://api.protrack365.com/api/authorization');
  url.searchParams.set('time', String(time));
  url.searchParams.set('account', env.PROTRACK_ACCOUNT);
  url.searchParams.set('signature', signature);
  const response = await fetch(url, { signal: AbortSignal.timeout(10000) });
  const result = await response.json();
  if (!response.ok || result.code != 0 || !result.record?.access_token) {
    console.error('Protrack authorization failed', response.status, result.code);
    if (result.code == 10007) throw new Error('PROTRACK_OPEN_API_DISABLED');
    if (result.code == 20001) throw new Error('PROTRACK_INVALID_CREDENTIALS');
    throw new Error(`PROTRACK_AUTH_FAILED_${result.code ?? 'UNKNOWN'}`);
  }
  protrackToken = String(result.record.access_token);
  const lifetime = Math.max(60, Math.min(Number(result.record.expires_in) || 7200, 7200));
  protrackTokenExpiresAt = Date.now() + (lifetime - 60) * 1000;
  return protrackToken;
}

async function proxyProtrack(request, env, path) {
  const user = await requireFirebaseFleetUser(request);
  const accessToken = await getProtrackToken(env);
  const upstream = new URL(`https://api.protrack365.com${path === '/protrack/devices' ? '/api/device/list' : '/api/track'}`);
  upstream.searchParams.set('access_token', accessToken);
  if (path === '/protrack/track') {
    const imeis = (new URL(request.url).searchParams.get('imeis') || '')
      .split(',').map(value => value.trim()).filter(value => /^\d{15}$/.test(value));
    if (!imeis.length || imeis.length > 100) return json({ error: 'INVALID_IMEIS' }, 400, request);
    if (user.role === 'driver') {
      const allowed = new Set(String(user.assignedImeis || '').split(',').filter(Boolean));
      if (!allowed.size || imeis.some(imei => !allowed.has(imei))) {
        return json({ error: 'IMEI_NOT_ASSIGNED' }, 403, request);
      }
    }
    upstream.searchParams.set('imeis', imeis.join(','));
  } else if (user.role === 'driver') {
    return json({ error: 'FORBIDDEN' }, 403, request);
  }
  const response = await fetch(upstream, { signal: AbortSignal.timeout(10000) });
  return new Response(await response.text(), {
    status: response.status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

async function hmac(secret, value) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64url(new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(value))));
}

function phone10(raw) {
  const digits = String(raw || '').replace(/\D/g, '');
  const value = digits.startsWith('91') && digits.length === 12 ? digits.slice(2) : digits;
  return /^[6-9]\d{9}$/.test(value) ? value : null;
}

function randomOtp() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return String(100000 + (values[0] % 900000));
}

async function parseBody(request) {
  try { return await request.json(); } catch { return {}; }
}

async function issueSession(env, phone, role) {
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const now = Math.floor(Date.now() / 1000);
  const payload = b64url(new TextEncoder().encode(JSON.stringify({
    sub: `phone:+91${phone}`, phone: `+91${phone}`, role, iat: now, exp: now + 86400,
  })));
  return `${header}.${payload}.${await hmac(env.SESSION_SIGNING_SECRET, `${header}.${payload}`)}`;
}

async function sendOtp(request, env) {
  const body = await parseBody(request);
  const phone = phone10(body.phoneNumber);
  if (!phone) return json({ success: false, message: 'Valid 10-digit mobile number required.' }, 400, request);
  if (phone !== phone10(env.AUTHORIZED_ADMIN_PHONE)) {
    return json({ success: false, message: 'This phone is not authorized for Transport One.' }, 403, request);
  }

  const phoneKey = await hmac(env.OTP_HASH_SECRET, phone);
  const recent = await env.OTP_STORE.get(`rate:${phoneKey}`);
  if (recent) return json({ success: false, message: 'Please wait before requesting another OTP.' }, 429, request);

  const otp = randomOtp();
  const nonce = crypto.randomUUID();
  const otpHash = await hmac(env.OTP_HASH_SECRET, `${phone}:${otp}:${nonce}`);
  await env.OTP_STORE.put(`otp:${phoneKey}`, JSON.stringify({ otpHash, nonce, attempts: 0 }), { expirationTtl: 300 });
  await env.OTP_STORE.put(`rate:${phoneKey}`, '1', { expirationTtl: 60 });

  const response = await fetch('https://api.interakt.ai/v1/public/message/', {
    method: 'POST',
    headers: { Authorization: `Basic ${env.INTERAKT_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      countryCode: '+91', phoneNumber: phone, callbackData: `transport-one:${nonce}`,
      type: 'Template',
      template: {
        name: env.INTERAKT_TEMPLATE_NAME,
        languageCode: env.INTERAKT_TEMPLATE_LANGUAGE,
        bodyValues: [otp],
        buttonValues: { '0': [otp] },
      },
    }),
  });
  if (!response.ok) {
    await env.OTP_STORE.delete(`otp:${phoneKey}`);
    const providerBody = await response.text();
    console.error('Interakt rejected OTP request', response.status, providerBody.slice(0, 500));
    return json({ success: false, message: 'WhatsApp provider rejected the OTP request.' }, 502, request);
  }
  return json({ success: true, message: `OTP sent to WhatsApp +91******${phone.slice(-4)}.`, expiresIn: 300 }, 200, request);
}

async function verifyOtp(request, env) {
  const body = await parseBody(request);
  const phone = phone10(body.phoneNumber);
  const otp = String(body.otp || '').trim();
  if (!phone || !/^\d{6}$/.test(otp)) return json({ success: false, message: 'Phone or OTP format is invalid.' }, 400, request);
  if (phone !== phone10(env.AUTHORIZED_ADMIN_PHONE)) return json({ success: false, message: 'Unauthorized phone.' }, 403, request);

  const phoneKey = await hmac(env.OTP_HASH_SECRET, phone);
  const key = `otp:${phoneKey}`;
  const saved = await env.OTP_STORE.get(key, 'json');
  if (!saved) return json({ success: false, message: 'OTP expired. Request a new OTP.' }, 401, request);
  if ((saved.attempts || 0) >= 5) {
    await env.OTP_STORE.delete(key);
    return json({ success: false, message: 'Too many attempts. Request a new OTP.' }, 429, request);
  }
  const candidate = await hmac(env.OTP_HASH_SECRET, `${phone}:${otp}:${saved.nonce}`);
  if (candidate !== saved.otpHash) {
    saved.attempts = (saved.attempts || 0) + 1;
    await env.OTP_STORE.put(key, JSON.stringify(saved), { expirationTtl: 300 });
    return json({ success: false, message: 'Incorrect OTP.' }, 401, request);
  }
  await env.OTP_STORE.delete(key);
  return json({
    success: true,
    token: await issueSession(env, phone, 'admin'),
    user: { phone: `+91${phone}`, role: 'admin', name: 'Transport One Admin' },
  }, 200, request);
}

export default {
  async fetch(request, env) {
    try {
      if (request.method === 'OPTIONS') return json({}, 204, request);
      const path = new URL(request.url).pathname;
      if (request.method === 'GET' && path === '/health') return json({ ok: true, service: 'transport-one-otp' }, 200, request);
      if (request.method === 'POST' && path === '/send') return sendOtp(request, env);
      if (request.method === 'POST' && path === '/verify') return verifyOtp(request, env);
      if (request.method === 'GET' && (path === '/protrack/devices' || path === '/protrack/track')) {
        return await proxyProtrack(request, env, path);
      }
      return json({ success: false, message: 'Not found.' }, 404, request);
    } catch (error) {
      const code = error?.message || 'UPSTREAM_UNAVAILABLE';
      const status = code === 'UNAUTHENTICATED' ? 401 : code === 'FORBIDDEN' ? 403 : 502;
      if (status === 502) console.error('Worker request failed', code);
      return json({ error: code }, status, request);
    }
  },
};

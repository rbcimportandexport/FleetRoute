'use strict';

const crypto = require('node:crypto');
const admin = require('firebase-admin');
const {onRequest} = require('firebase-functions/v2/https');
const {defineSecret, defineString} = require('firebase-functions/params');

admin.initializeApp();

const protrackAccount = defineSecret('PROTRACK_ACCOUNT');
const protrackPassword = defineSecret('PROTRACK_PASSWORD');
const seatbeltAiUrl = defineSecret('SEATBELT_AI_URL');
const seatbeltAiKey = defineSecret('SEATBELT_AI_KEY');
const allowedOrigins = defineString('ALLOWED_ORIGINS', {default: ''});

let cachedProtrackToken = '';
let cachedProtrackTokenExpiresAt = 0;

function applyCors(req, res) {
  const origin = String(req.get('origin') || '').trim();
  if (!origin) return true; // Android/iOS and server-to-server requests.
  const projectId = process.env.GCLOUD_PROJECT || '';
  const configured = allowedOrigins.value().split(',')
    .map((value) => value.trim()).filter(Boolean);
  const firebaseHosting = projectId ? [
    `https://${projectId}.web.app`,
    `https://${projectId}.firebaseapp.com`,
  ] : [];
  const localDevelopment = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  if (!localDevelopment && !configured.includes(origin) && !firebaseHosting.includes(origin)) {
    res.status(403).json({error: 'ORIGIN_NOT_ALLOWED'});
    return false;
  }
  res.set('Access-Control-Allow-Origin', origin);
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return false;
  }
  return true;
}

async function requireUser(req, allowedRoles = ['admin', 'driver']) {
  const header = String(req.get('authorization') || '');
  if (!header.startsWith('Bearer ')) throw new Error('UNAUTHENTICATED');
  const decoded = await admin.auth().verifyIdToken(header.slice(7), true);
  if (!allowedRoles.includes(decoded.role)) throw new Error('FORBIDDEN');
  return decoded;
}

function sendError(res, error) {
  const code = error && error.message;
  if (code === 'UNAUTHENTICATED') return res.status(401).json({error: code});
  if (code === 'FORBIDDEN') return res.status(403).json({error: code});
  console.error(error);
  return res.status(502).json({error: 'UPSTREAM_UNAVAILABLE'});
}

async function getProtrackToken() {
  if (cachedProtrackToken && Date.now() < cachedProtrackTokenExpiresAt) {
    return cachedProtrackToken;
  }
  const account = protrackAccount.value();
  const password = protrackPassword.value();
  const time = Math.floor(Date.now() / 1000);
  const passwordMd5 = crypto.createHash('md5').update(password).digest('hex');
  const signature = crypto.createHash('md5').update(passwordMd5 + time).digest('hex');
  const loginUrl = new URL('https://api.protrack365.com/api/authorization');
  loginUrl.searchParams.set('time', String(time));
  loginUrl.searchParams.set('account', account);
  loginUrl.searchParams.set('signature', signature);
  const response = await fetch(loginUrl, {signal: AbortSignal.timeout(10000)});
  const login = await response.json();
  if (!response.ok || !login.record?.access_token) throw new Error('PROTRACK_AUTH_FAILED');
  cachedProtrackToken = String(login.record.access_token);
  const lifetimeSeconds = Math.max(60, Math.min(Number(login.record.expires_in) || 1800, 3600));
  cachedProtrackTokenExpiresAt = Date.now() + (lifetimeSeconds - 30) * 1000;
  return cachedProtrackToken;
}

exports.protrackProxy = onRequest(
  {region: 'asia-south1', secrets: [protrackAccount, protrackPassword]},
  async (req, res) => {
    try {
      if (!applyCors(req, res)) return;
      const user = await requireUser(req);
      if (req.method !== 'GET' || !req.path.endsWith('/track')) {
        return res.status(404).json({error: 'NOT_FOUND'});
      }
      const imeis = String(req.query.imeis || '')
        .split(',').map((value) => value.trim()).filter((value) => /^\d{15}$/.test(value));
      if (!imeis.length || imeis.length > 100) {
        return res.status(400).json({error: 'INVALID_IMEIS'});
      }
      if (user.role === 'driver') {
        const allowed = new Set(String(user.assignedImeis || '').split(',').filter(Boolean));
        if (!allowed.size) return res.status(403).json({error: 'NO_TRACKER_ASSIGNED'});
        if (imeis.some((imei) => !allowed.has(imei))) {
          return res.status(403).json({error: 'IMEI_NOT_ASSIGNED'});
        }
      }
      const accessToken = await getProtrackToken();
      const trackUrl = new URL('https://api.protrack365.com/api/track');
      trackUrl.searchParams.set('access_token', accessToken);
      trackUrl.searchParams.set('imeis', imeis.join(','));
      const trackResponse = await fetch(trackUrl, {signal: AbortSignal.timeout(10000)});
      const body = await trackResponse.text();
      res.status(trackResponse.status).type('application/json').send(body);
    } catch (error) {
      sendError(res, error);
    }
  },
);

exports.routingProxy = onRequest({region: 'asia-south1'}, async (req, res) => {
  try {
    if (!applyCors(req, res)) return;
    await requireUser(req);
    const coords = String(req.query.coords || '');
    if (!/^-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?(?:;-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?)+$/.test(coords)) {
      return res.status(400).json({error: 'INVALID_COORDS'});
    }
    const points = coords.split(';').map((pair) => pair.split(',').map(Number));
    if (points.length < 2 || points.length > 25 ||
        points.some(([lng, lat]) => !Number.isFinite(lat) || !Number.isFinite(lng) ||
          lat < -90 || lat > 90 || lng < -180 || lng > 180)) {
      return res.status(400).json({error: 'INVALID_COORDS'});
    }
    const url = `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=false`;
    const upstream = await fetch(url, {
      headers: {'User-Agent': 'TransportOne/1.1'},
      signal: AbortSignal.timeout(12000),
    });
    res.status(upstream.status).type('application/json').send(await upstream.text());
  } catch (error) {
    sendError(res, error);
  }
});

exports.adminApi = onRequest({region: 'asia-south1'}, async (req, res) => {
  try {
    if (!applyCors(req, res)) return;
    await requireUser(req, ['admin', 'super_admin']);
    if (!req.path.endsWith('/drivers')) {
      return res.status(404).json({error: 'NOT_FOUND'});
    }
    const email = String(req.body?.email || '').trim().toLowerCase();
    if (!/^\S+@\S+\.\S+$/.test(email)) {
      return res.status(400).json({error: 'INVALID_EMAIL'});
    }
    if (req.method === 'POST') {
      const password = String(req.body?.password || '');
      const name = String(req.body?.name || '').trim();
      const assignedVehicle = String(req.body?.assignedVehicle || '').trim().toUpperCase();
      const assignedImei = String(req.body?.assignedImei || '').trim();
      if (password.length < 8 || !name) {
        return res.status(400).json({error: 'INVALID_DRIVER'});
      }
      if (assignedImei && !/^\d{15}$/.test(assignedImei)) {
        return res.status(400).json({error: 'INVALID_IMEI'});
      }
      let user;
      try {
        user = await admin.auth().getUserByEmail(email);
        user = await admin.auth().updateUser(user.uid, {password, displayName: name});
      } catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
        user = await admin.auth().createUser({email, password, displayName: name});
      }
      await admin.auth().setCustomUserClaims(user.uid, {
        role: 'driver',
        assignedVehicle,
        assignedImeis: assignedImei,
      });
      await admin.firestore().collection('drivers').doc(user.uid).set({
        email,
        name,
        phone: String(req.body?.phone || '').trim(),
        assignedVehicle,
        role: 'driver',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return res.status(200).json({uid: user.uid});
    }
    if (req.method === 'DELETE') {
      const user = await admin.auth().getUserByEmail(email);
      await admin.auth().deleteUser(user.uid);
      await admin.firestore().collection('drivers').doc(user.uid).delete();
      return res.status(204).send('');
    }
    return res.status(405).json({error: 'METHOD_NOT_ALLOWED'});
  } catch (error) {
    sendError(res, error);
  }
});

exports.safetyApi = onRequest(
  {region: 'asia-south1', secrets: [seatbeltAiUrl, seatbeltAiKey]},
  async (req, res) => {
    try {
      if (!applyCors(req, res)) return;
      await requireUser(req, ['driver']);
      if (req.method !== 'POST' || !req.path.endsWith('/verifySeatbelt')) {
        return res.status(404).json({error: 'NOT_FOUND'});
      }
      const image = req.body && req.body.image;
      if (typeof image !== 'string' || image.length < 5000 || image.length > 14000000) {
        return res.status(400).json({error: 'INVALID_IMAGE'});
      }
      const upstream = await fetch(seatbeltAiUrl.value(), {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'authorization': `Bearer ${seatbeltAiKey.value()}`,
        },
        body: JSON.stringify({image}),
        signal: AbortSignal.timeout(15000),
      });
      const result = await upstream.json();
      const response = {
        isApproved: result.isApproved === true,
        confidence: Number(result.confidence) || 0,
        livenessPassed: result.livenessPassed === true,
        seatbeltDetected: result.seatbeltDetected === true,
        driverPresent: result.driverPresent === true,
        message: String(result.message || 'Verification completed.'),
      };
      if (!upstream.ok) response.isApproved = false;
      res.status(upstream.ok ? 200 : 502).json(response);
    } catch (error) {
      sendError(res, error);
    }
  },
);

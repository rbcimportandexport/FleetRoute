const parsePositiveInteger = (name, fallback) => {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }
  return value;
};

const nodeEnv = process.env.NODE_ENV || 'development';
const isProduction = nodeEnv === 'production';
const publicEmbeddedAccess = process.env.PUBLIC_EMBEDDED_ACCESS === 'true';
const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(origin => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);

function validateProductionConfig() {
  if (!isProduction) return;

  const missing = [];
  if (!process.env.MONGODB_URI && !process.env.MONGO_URI) missing.push('MONGODB_URI');
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) missing.push('JWT_SECRET (minimum 32 characters)');
  if (corsOrigins.length === 0) missing.push('CORS_ORIGINS');

  if (missing.length > 0) {
    throw new Error(`Invalid production configuration. Required: ${missing.join(', ')}`);
  }
}

validateProductionConfig();

const corsOptions = {
  credentials: false,
  origin(origin, callback) {
    // Native mobile clients and server-to-server calls commonly have no Origin header.
    if (!origin) return callback(null, true);
    const normalizedOrigin = origin.replace(/\/$/, '');
    const isLocalDevelopment = !isProduction && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(normalizedOrigin);
    if (isLocalDevelopment || corsOrigins.includes(normalizedOrigin)) return callback(null, true);
    const error = new Error('Origin is not allowed by FleetRoute CORS policy.');
    error.status = 403;
    error.code = 'CORS_ORIGIN_DENIED';
    return callback(error);
  }
};

module.exports = Object.freeze({
  nodeEnv,
  isProduction,
  port: parsePositiveInteger('PORT', 5000),
  jsonBodyLimit: process.env.JSON_BODY_LIMIT || '15mb',
  authRateLimitWindowMs: parsePositiveInteger('AUTH_RATE_LIMIT_WINDOW_MS', 15 * 60 * 1000),
  authRateLimitMax: parsePositiveInteger('AUTH_RATE_LIMIT_MAX', 10),
  trustProxy: process.env.TRUST_PROXY === 'true' ? 1 : false,
  publicEmbeddedAccess,
  corsOrigins,
  corsOptions
});

// server/auth.js
// Authentication & Role-Based Authorization Engine
// STRICTLY ZERO EMOJIS. NO FIXED HARDCODED FALLBACK SECRETS.

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('./db');
const config = require('./config');

// Require configured JWT secret. Never use a fixed documented default secret.
let JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  if (process.env.NODE_ENV === 'production') {
    console.error('[FleetRoute Security CRITICAL] JWT_SECRET environment variable is missing.');
    throw new Error('FATAL: JWT_SECRET environment variable is required in production.');
  } else {
    // Generate an ephemeral cryptographic secret for local dev/test if not provided in env.
    JWT_SECRET = crypto.randomBytes(32).toString('hex');
  }
}

const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';

// Hash password with salt
async function hashPassword(plainPassword) {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(plainPassword, salt);
}

// Compare plain password with hash
async function comparePassword(plainPassword, hash) {
  return bcrypt.compare(plainPassword, hash);
}

// Generate JWT token
function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role,
      driverId: user.driverId || null,
      name: user.name,
      tokenVersion: Number(user.tokenVersion) || 0
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

// Create a short-lived, signed principal for an explicitly enabled embedded
// presentation. This principal is not persisted as a fake user record.
function generateEmbeddedAccessToken() {
  return jwt.sign(
    {
      id: 'fleetroute-embedded-access',
      name: 'FleetRoute Operations',
      role: 'admin',
      accessMode: 'embedded'
    },
    JWT_SECRET,
    { expiresIn: '2h' }
  );
}

// Authenticate token middleware
async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required. Please log in.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    if (
      config.publicEmbeddedAccess &&
      decoded.accessMode === 'embedded' &&
      decoded.id === 'fleetroute-embedded-access'
    ) {
      req.user = {
        id: decoded.id,
        name: decoded.name,
        role: 'admin',
        status: 'active',
        accessMode: 'embedded',
        mustChangePassword: false
      };
      return next();
    }

    const user = await db.collection('users').findById(decoded.id);

    if (!user) {
      return res.status(401).json({ error: 'Session user account not found.' });
    }

    if (user.status === 'disabled') {
      return res.status(403).json({ error: 'Account has been disabled by central administrator.' });
    }

    if ((Number(decoded.tokenVersion) || 0) !== (Number(user.tokenVersion) || 0)) {
      return res.status(401).json({ error: 'Session has been revoked. Please log in again.' });
    }

    req.user = {
      id: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role,
      driverId: user.driverId,
      name: user.name,
      status: user.status,
      mustChangePassword: Boolean(user.mustChangePassword)
    };
    if (user.mustChangePassword && !['/api/auth/me', '/api/auth/change-password'].includes(req.originalUrl?.split('?')[0])) {
      return res.status(403).json({
        error: 'Password change is required before using operational features.',
        code: 'PASSWORD_CHANGE_REQUIRED'
      });
    }
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Session expired. Please log in again.' });
    }
    return res.status(401).json({ error: 'Invalid authentication token.' });
  }
}

// Admin role check middleware
function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Access denied. Administrator privileges required.' });
  }
  next();
}

// Driver role check middleware
function requireDriver(req, res, next) {
  if (!req.user || req.user.role !== 'driver') {
    return res.status(403).json({ error: 'Access denied. Driver account privileges required.' });
  }
  next();
}

module.exports = {
  hashPassword,
  comparePassword,
  generateToken,
  generateEmbeddedAccessToken,
  requireAuth,
  requireAdmin,
  requireDriver,
  getJWTSecret: () => JWT_SECRET
};

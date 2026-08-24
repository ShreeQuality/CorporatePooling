// ============================================================
// Corporate Pooling App — Main Server
// ============================================================

'use strict';

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

// Route imports
const authRoutes          = require('./routes/auth');
const rideRoutes          = require('./routes/rides');
const requestRoutes       = require('./routes/requests');
const walletRoutes        = require('./routes/wallet');
const adminRoutes         = require('./routes/admin');
const notificationRoutes  = require('./routes/notifications');
const kycRoutes           = require('./routes/kyc');

const app = express();
const PORT = process.env.PORT || 3000;
const BASE = '/api/v1';

// ─── Security & Logging ───────────────────────────────────────
app.use(helmet());
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// ─── CORS ─────────────────────────────────────────────────────
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ─── Body Parsing ─────────────────────────────────────────────
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

// ─── Global Rate Limiting ─────────────────────────────────────
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests. Please slow down.' },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20, // stricter for auth endpoints
  message: { success: false, message: 'Too many auth attempts. Try again in 15 minutes.' },
});

app.use(globalLimiter);
app.use(`${BASE}/auth`, authLimiter);

// ─── Routes ───────────────────────────────────────────────────
app.use(`${BASE}/auth`,           authRoutes);
app.use(`${BASE}/kyc`,            kycRoutes);
app.use(`${BASE}/rides`,          rideRoutes);
app.use(`${BASE}`,                requestRoutes);   // /requests/my, /rides/:id/request, etc.
app.use(`${BASE}/wallet`,         walletRoutes);
app.use(`${BASE}/admin`,          adminRoutes);
app.use(`${BASE}/notifications`,  notificationRoutes);

// ─── Health Check ─────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    success: true,
    service: 'Corporate Pooling API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    env: process.env.NODE_ENV || 'development',
  });
});

// ─── 404 Handler ──────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route not found: ${req.method} ${req.path}` });
});

// ─── Global Error Handler ─────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('[GlobalError]', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { debug: err.message }),
  });
});

// ─── Start ────────────────────────────────────────────────────
// Pre-warm wallet settings cache (Issue 3 fix: avoids ~50ms cold-load on first
// booking request). walletService already calls this on module load, but
// requiring it here makes the startup sequence explicit and testable.
require('./services/walletService').initSettingsCache()
  .then(() => console.log('[Startup] Wallet settings cache pre-warmed ✓'))
  .catch((e) => console.warn('[Startup] Settings cache pre-warm failed (will use defaults):', e.message));

app.listen(PORT, () => {
  console.log(`\n🚗 Corporate Pooling API`);
  console.log(`📡 Listening on http://localhost:${PORT}`);
  console.log(`🔗 Base URL: http://localhost:${PORT}${BASE}`);
  console.log(`🏥 Health: http://localhost:${PORT}/health`);
  console.log(`🌍 Env: ${process.env.NODE_ENV || 'development'}\n`);
});

module.exports = app;

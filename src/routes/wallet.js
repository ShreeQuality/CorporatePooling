// ============================================================
// Wallet Routes — /api/v1/wallet/*
// Source of Truth: SRS §4.9, §5.3, §11.2, §12.5, §12.7, §14
// ============================================================

'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/walletController');
const { requireAuth, optionalAuth } = require('../middleware/auth');

// ─── 1. Full 3-Tier Wallet Profile ─────────────────────────────
router.get('/', requireAuth, ctrl.getWalletDetails);

// ─── 2. Lightweight Home Summary Banner Widget ─────────────────
router.get('/summary', requireAuth, ctrl.getSummary);

// ─── 3. Double-Entry Paginated Ledger History ──────────────────
router.get('/transactions', requireAuth, ctrl.getTransactions);

// ─── 4. Pure Mathematical Fare Quote (Open / Optional Auth) ────
router.post('/fare-estimate', optionalAuth, ctrl.getFareEstimate);

// ─── 5. Pre-Booking Solvency & Overdraft Check ──────────────────
router.get('/check-balance', requireAuth, ctrl.checkBalance);

// ─── 6. Colleague-to-Colleague Coin Gift (peer_transfer) ───────
router.post('/transfer', requireAuth, ctrl.transferCoins);

module.exports = router;

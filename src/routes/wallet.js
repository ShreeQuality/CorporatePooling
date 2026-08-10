// ============================================================
// Wallet Routes — /api/v1/wallet/*
// ============================================================
'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/walletController');
const { requireAuth } = require('../middleware/auth');
const { requireAdmin } = require('../middleware/auth');

router.get('/',              requireAuth, ctrl.getWallet);
router.get('/transactions',  requireAuth, ctrl.getTransactions);
router.post('/credit',       requireAdmin, ctrl.creditCoins); // Admin only

module.exports = router;

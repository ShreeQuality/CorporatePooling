// ============================================================
// KYC Routes ?" /api/v1/kyc/*
// ============================================================
'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/kycController');
const { requireAuth } = require('../middleware/auth');

// Protected KYC endpoints
router.post('/vahan', requireAuth, ctrl.processVahan);

module.exports = router;

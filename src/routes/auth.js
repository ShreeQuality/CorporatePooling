// ============================================================
// Auth Routes — /api/v1/auth/*
// ============================================================
'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/authController');
const { requireAuth } = require('../middleware/auth');
const { upload, handleUploadError } = require('../middleware/upload');

// Public endpoints
router.post('/register-corporate', ctrl.registerCorporate);
router.post('/register-public',    ctrl.registerPublic);
router.post('/request-otp',        ctrl.requestPhoneOtp);
router.post('/verify-otp',         ctrl.verifyOtp);
router.post('/verify-phone-otp',   ctrl.verifyPhoneOtp);
router.post('/resend-otp',         ctrl.resendOtp);
router.post('/login',              ctrl.login);

// Protected endpoints
router.get('/me',                       requireAuth, ctrl.getMe);
router.post('/upload-document',         requireAuth, upload.single('file'), handleUploadError, ctrl.uploadDocument);
router.patch('/emergency-contacts',     requireAuth, ctrl.updateEmergencyContacts);

module.exports = router;

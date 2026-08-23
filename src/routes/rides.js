// ============================================================
// Ride Routes — /api/v1/rides/*
// Source of Truth: SRS §4.7, §6.1, §8.4, §8.9, §10.1
// ============================================================

'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/rideController');
const { requireAuth } = require('../middleware/auth');
const { checkSubscription } = require('../middleware/subscriptionGuard');

// All ride routes require authentication
router.use(requireAuth);

// ─── Query Endpoints (Must be declared before /:id parameter) ─
router.get('/search',             ctrl.searchRides);       // GET /api/v1/rides/search
router.get('/my',                 ctrl.getMyRides);         // GET /api/v1/rides/my

// ─── Single Ride Operations ──────────────────────────────────
router.get('/:id',                ctrl.getRide);            // GET /api/v1/rides/:id
router.post('/',                  checkSubscription, ctrl.postRide); // POST /api/v1/rides
router.patch('/:id/start',        ctrl.startRide);          // PATCH /api/v1/rides/:id/start
router.post('/:id/verify-boarding', ctrl.verifyBoarding);   // POST /api/v1/rides/:id/verify-boarding
router.patch('/:id/location',     ctrl.updateLocation);     // PATCH /api/v1/rides/:id/location (GPS)
router.patch('/:id/complete',     ctrl.completeRide);       // PATCH /api/v1/rides/:id/complete
router.delete('/:id',             ctrl.cancelRide);         // DELETE /api/v1/rides/:id

module.exports = router;

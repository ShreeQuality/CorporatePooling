// ============================================================
// Ride Routes — /api/v1/rides/*
// ============================================================
'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/rideController');
const { requireAuth } = require('../middleware/auth');
const { checkSubscription } = require('../middleware/subscriptionGuard');

// All ride routes require auth
router.use(requireAuth);

router.get('/my',           ctrl.getMyRides);        // GET /rides/my
router.get('/search',       ctrl.searchRides);        // GET /rides/search?pickup_lat=...
router.get('/:id',          ctrl.getRide);             // GET /rides/:id
router.post('/',            checkSubscription, ctrl.postRide);       // POST /rides
router.patch('/:id/start',  ctrl.startRide);          // PATCH /rides/:id/start
router.patch('/:id/location', ctrl.updateLocation);  // PATCH /rides/:id/location (GPS)
router.delete('/:id',       ctrl.cancelRide);         // DELETE /rides/:id

module.exports = router;

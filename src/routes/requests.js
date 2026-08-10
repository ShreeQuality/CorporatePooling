// ============================================================
// Request Routes — /api/v1/requests/* and /api/v1/rides/:id/*
// ============================================================
'use strict';

const router = require('express').Router({ mergeParams: true });
const ctrl = require('../controllers/requestController');
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

// Rider actions
router.get('/my',                          ctrl.getMyRequests);       // GET /requests/my
router.post('/rides/:id/request',          ctrl.createRequest);       // POST /rides/:id/request
router.patch('/:id/accept',                ctrl.acceptRequest);       // PATCH /requests/:id/accept
router.patch('/:id/reject',                ctrl.rejectRequest);       // PATCH /requests/:id/reject
router.post('/rides/:id/verify-otp',       ctrl.verifyPickupOtp);     // POST /rides/:id/verify-otp
router.patch('/:id/driver-arrive',         ctrl.driverMarkArrival);   // PATCH /requests/:id/driver-arrive
router.patch('/:id/rider-confirm',         ctrl.riderConfirmArrival); // PATCH /requests/:id/rider-confirm

module.exports = router;

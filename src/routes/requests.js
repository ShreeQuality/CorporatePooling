// ============================================================
// Request Routes — /api/v1/requests/* and /api/v1/rides/:id/*
// Source of Truth: SRS §5.3, §8.1, §8.3, §8.9, §15.2, §21.2
// ============================================================

'use strict';

const router = require('express').Router({ mergeParams: true });
const ctrl = require('../controllers/requestController');
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

// ─── 1. Rider Request Creation ─────────────────────────────────
router.post('/rides/:id/request', ctrl.createRequest);

// ─── 2. Driver Acceptance & Rejection ──────────────────────────
router.patch('/:id/accept',       ctrl.acceptRequest);
router.patch('/:id/reject',       ctrl.rejectRequest);

// ─── 3. Dynamic Cancellation Engine ────────────────────────────
router.post('/:id/cancel',        ctrl.cancelRequest);

// ─── 4. Request Queries & Details ──────────────────────────────
router.get('/my',                 ctrl.getMyRequests);
router.get('/:id',                ctrl.getRequestDetails);

module.exports = router;

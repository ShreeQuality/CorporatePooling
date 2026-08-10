// ============================================================
// Admin Routes — /api/v1/admin/*
// All routes require admin auth
// ============================================================
'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/adminController');
const { requireAdmin } = require('../middleware/auth');

router.use(requireAdmin);

// Dashboard
router.get('/dashboard',                  ctrl.getDashboardStats);

// Users
router.get('/users',                      ctrl.listUsers);
router.get('/users/:id',                  ctrl.getUserDetail);
router.patch('/users/:id/toggle-active',  ctrl.toggleUserActive);

// Document verifications
router.get('/documents/pending',          ctrl.listPendingDocuments);
router.patch('/documents/:id/approve',    ctrl.approveDocument);
router.patch('/documents/:id/reject',     ctrl.rejectDocument);

// Companies
router.get('/companies',                  ctrl.listCompanies);
router.post('/companies',                 ctrl.createCompany);
router.patch('/companies/:id',            ctrl.updateCompany);

// Rides
router.get('/rides',                      ctrl.listAllRides);

module.exports = router;

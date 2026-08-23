// ============================================================
// Admin Routes — /api/v1/admin/*
// Super Admin & Corporate HR Portal Access
// Source of Truth: SRS §13, §14, §17.6
// ============================================================

'use strict';

const router = require('express').Router();
const ctrl = require('../controllers/adminController');
const { requireAdmin } = require('../middleware/auth');

router.use(requireAdmin);

// Dashboard Metrics
router.get('/dashboard',                     ctrl.getDashboardStats);

// User Management
router.get('/users',                         ctrl.listUsers);
router.get('/users/:id',                     ctrl.getUserDetail);
router.patch('/users/:id/ban',               ctrl.banUser);
router.patch('/users/:id/verify-dl',         ctrl.verifyDriverDl);

// Company & B2B Subscriptions
router.get('/companies',                     ctrl.listCompanies);
router.post('/companies',                    ctrl.createCompany);
router.patch('/companies/:id',               ctrl.updateCompany);

// Corporate ESG Sustainability Report (SRS §13.3)
router.get('/company/:company_id/esg-report', ctrl.getCompanyEsgReport);

// Emergency SOS Live Incident Monitor (SRS §17.6)
router.get('/sos/active',                    ctrl.listActiveSosIncidents);

// Rides Audit
router.get('/rides',                         ctrl.listAllRides);

module.exports = router;

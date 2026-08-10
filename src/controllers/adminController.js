// ============================================================
// Admin Controller — Corporate Pooling App
// User mgmt, document approvals, company mgmt, analytics
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { ok, created, badRequest, notFound, serverError } = require('../utils/response');

// ─── Users ────────────────────────────────────────────────────

async function listUsers(req, res) {
  try {
    const { user_type, is_verified, search, limit = 50, offset = 0 } = req.query;
    let query = supabaseAdmin
      .from('users')
      .select('id, full_name, email, phone, user_type, company_id, is_email_verified, is_document_verified, is_driver_verified, is_active, coin_balance, karma_score, created_at, companies(name)')
      .order('created_at', { ascending: false })
      .range(parseInt(offset), parseInt(offset) + parseInt(limit) - 1);

    if (user_type) query = query.eq('user_type', user_type);
    if (is_verified !== undefined) query = query.eq('is_document_verified', is_verified === 'true');
    if (search) query = query.or(`full_name.ilike.%${search}%,email.ilike.%${search}%`);

    const { data, error } = await query;
    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

async function getUserDetail(req, res) {
  try {
    const { data, error } = await supabaseAdmin
      .from('users')
      .select('*, companies(id, name, email_domain, subscription_status), document_verifications(*), vehicles(*)')
      .eq('id', req.params.id)
      .single();

    if (error || !data) return notFound(res, 'User not found');
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

async function toggleUserActive(req, res) {
  try {
    const { is_active } = req.body;
    const { data, error } = await supabaseAdmin
      .from('users').update({ is_active }).eq('id', req.params.id).select().single();
    if (error) return serverError(res, error);
    return ok(res, data, `User ${is_active ? 'activated' : 'deactivated'}`);
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Document Verifications ───────────────────────────────────

async function listPendingDocuments(req, res) {
  try {
    const { data, error } = await supabaseAdmin
      .from('document_verifications')
      .select('id, user_id, doc_type, doc_url, status, created_at, users(full_name, email, user_type)')
      .eq('status', 'pending')
      .order('created_at', { ascending: true });

    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

async function approveDocument(req, res) {
  try {
    const docId = req.params.id;
    const { data: doc } = await supabaseAdmin
      .from('document_verifications').select('user_id, doc_type').eq('id', docId).single();
    if (!doc) return notFound(res, 'Document not found');

    await supabaseAdmin.from('document_verifications').update({
      status: 'approved',
      reviewed_by: req.admin.id,
      reviewed_at: new Date().toISOString(),
    }).eq('id', docId);

    // Update user flags
    const updates = {};
    if (doc.doc_type === 'aadhaar' || doc.doc_type === 'photo') updates.is_document_verified = true;
    if (doc.doc_type === 'driving_licence') updates.is_driver_verified = true;
    if (Object.keys(updates).length > 0) {
      await supabaseAdmin.from('users').update(updates).eq('id', doc.user_id);
    }

    return ok(res, null, 'Document approved');
  } catch (err) {
    return serverError(res, err);
  }
}

async function rejectDocument(req, res) {
  try {
    const { reason } = req.body;
    const docId = req.params.id;
    await supabaseAdmin.from('document_verifications').update({
      status: 'rejected',
      rejection_reason: reason || 'Does not meet requirements',
      reviewed_by: req.admin.id,
      reviewed_at: new Date().toISOString(),
    }).eq('id', docId);
    return ok(res, null, 'Document rejected');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Companies ────────────────────────────────────────────────

async function listCompanies(req, res) {
  try {
    const { data, error } = await supabaseAdmin
      .from('companies')
      .select('*, subscriptions(*)')
      .order('created_at', { ascending: false });
    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

async function createCompany(req, res) {
  try {
    const { name, email_domain, max_employees } = req.body;
    if (!name) return badRequest(res, 'Company name required');

    const { data, error } = await supabaseAdmin
      .from('companies')
      .insert({ name, email_domain: email_domain || null, max_employees: max_employees || 100 })
      .select().single();

    if (error) return serverError(res, error);

    // Create default 90-day trial subscription
    await supabaseAdmin.from('subscriptions').insert({
      company_id: data.id,
      plan: 'free_trial',
      status: 'active',
      expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
    });

    return created(res, data, 'Company created with 90-day free trial');
  } catch (err) {
    return serverError(res, err);
  }
}

async function updateCompany(req, res) {
  try {
    const { name, email_domain, subscription_status, is_active, max_employees } = req.body;
    const { data, error } = await supabaseAdmin
      .from('companies')
      .update({ name, email_domain, subscription_status, is_active, max_employees })
      .eq('id', req.params.id)
      .select().single();
    if (error) return serverError(res, error);
    return ok(res, data, 'Company updated');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Analytics Dashboard ──────────────────────────────────────

async function getDashboardStats(req, res) {
  try {
    const [
      { count: totalUsers },
      { count: totalRides },
      { count: pendingDocs },
      { count: totalCompanies },
      { count: activeRides },
    ] = await Promise.all([
      supabaseAdmin.from('users').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('rides').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('document_verifications').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
      supabaseAdmin.from('companies').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('rides').select('*', { count: 'exact', head: true }).in('ride_status', ['posted', 'started', 'in_progress']),
    ]);

    return ok(res, {
      total_users: totalUsers,
      total_rides: totalRides,
      active_rides: activeRides,
      pending_documents: pendingDocs,
      total_companies: totalCompanies,
    });
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── All Rides ────────────────────────────────────────────────

async function listAllRides(req, res) {
  try {
    const { status, limit = 50, offset = 0 } = req.query;
    let query = supabaseAdmin
      .from('rides')
      .select('id, from_address, to_address, ride_status, total_seats, available_seats, coin_per_seat, depart_time, distance_km, created_at, users!driver_id(full_name, email)')
      .order('created_at', { ascending: false })
      .range(parseInt(offset), parseInt(offset) + parseInt(limit) - 1);

    if (status) query = query.eq('ride_status', status);
    const { data, error } = await query;
    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = {
  listUsers, getUserDetail, toggleUserActive,
  listPendingDocuments, approveDocument, rejectDocument,
  listCompanies, createCompany, updateCompany,
  getDashboardStats, listAllRides,
};

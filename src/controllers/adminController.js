// ============================================================
// Admin Controller — Corporate Pooling Backend
// Super Admin & Corporate HR Portal Operations
// Source of Truth: SRS §13 (ESG Reports), §14 (Corporate Grants), §17.6 (SOS Monitor), Schema 014
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { ok, created, badRequest, notFound, forbidden, serverError } = require('../utils/response');

// ============================================================
// 1. DASHBOARD ANALYTICS & OVERVIEW
// ============================================================

async function getDashboardStats(req, res) {
  try {
    const [
      { count: totalUsers },
      { count: totalRides },
      { count: activeRides },
      { count: totalCompanies },
      { count: activeSosIncidents },
      { count: totalCarpoolAttendance },
    ] = await Promise.all([
      supabaseAdmin.from('users').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('rides').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('rides').select('*', { count: 'exact', head: true }).in('ride_status', ['posted', 'started', 'in_progress']),
      supabaseAdmin.from('companies').select('*', { count: 'exact', head: true }),
      supabaseAdmin.from('emergency_sos_incidents').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      supabaseAdmin.from('corporate_attendance').select('*', { count: 'exact', head: true }).eq('transport_mode', 'carpool'),
    ]);

    const totalCo2SavedKg = Number(((totalCarpoolAttendance || 0) * 1.88).toFixed(2));

    return ok(res, {
      total_users: totalUsers || 0,
      total_rides: totalRides || 0,
      active_rides: activeRides || 0,
      total_companies: totalCompanies || 0,
      active_sos_alerts: activeSosIncidents || 0,
      total_carpool_trips: totalCarpoolAttendance || 0,
      total_co2_saved_kg: totalCo2SavedKg,
    }, 'Dashboard metrics retrieved successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// 2. USER MANAGEMENT & BAN CONTROLS
// ============================================================

async function listUsers(req, res) {
  try {
    const { role, is_banned, company_id, search, limit = 50, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('users')
      .select(`
        id, full_name, work_email, phone_number, role, gender,
        company_id, building_id, dl_verified, is_banned, trust_score, created_at,
        companies (id, name, domain),
        wallets (available_balance, corporate_grant_balance, locked_balance)
      `, { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(parseInt(offset, 10), parseInt(offset, 10) + parseInt(limit, 10) - 1);

    if (role) query = query.eq('role', role);
    if (is_banned !== undefined) query = query.eq('is_banned', is_banned === 'true');
    if (company_id) query = query.eq('company_id', company_id);
    if (search) query = query.or(`full_name.ilike.%${search}%,work_email.ilike.%${search}%`);

    const { data: users, error, count } = await query;
    if (error) return serverError(res, error, 'Failed to fetch users list.');

    return ok(res, {
      users: users || [],
      total_count: count || 0,
      limit: parseInt(limit, 10),
      offset: parseInt(offset, 10),
    });
  } catch (err) {
    return serverError(res, err);
  }
}

async function getUserDetail(req, res) {
  try {
    const { id } = req.params;

    const { data: user, error } = await supabaseAdmin
      .from('users')
      .select(`
        *,
        companies (*),
        vehicles (*),
        wallets (*)
      `)
      .eq('id', id)
      .single();

    if (error || !user) return notFound(res, 'User not found.');
    return ok(res, user);
  } catch (err) {
    return serverError(res, err);
  }
}

async function banUser(req, res) {
  try {
    const { id } = req.params;
    const { is_banned, ban_reason } = req.body;

    if (typeof is_banned !== 'boolean') {
      return badRequest(res, 'is_banned boolean flag is required.');
    }

    const { data, error } = await supabaseAdmin
      .from('users')
      .update({
        is_banned,
        ban_reason: is_banned ? (ban_reason || 'Administrative action') : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select('id, full_name, is_banned, ban_reason')
      .single();

    if (error) return serverError(res, error, 'Failed to update user ban status.');
    return ok(res, data, `User ${is_banned ? 'suspended' : 're-activated'} successfully.`);
  } catch (err) {
    return serverError(res, err);
  }
}

async function verifyDriverDl(req, res) {
  try {
    const { id } = req.params;
    const { dl_verified, dl_number } = req.body;

    const updates = {
      dl_verified: Boolean(dl_verified),
      updated_at: new Date().toISOString(),
    };
    if (dl_number) updates.dl_number = dl_number.trim();

    const { data, error } = await supabaseAdmin
      .from('users')
      .update(updates)
      .eq('id', id)
      .select('id, full_name, dl_verified, dl_number')
      .single();

    if (error) return serverError(res, error, 'Failed to update DL verification.');
    return ok(res, data, `Driver license ${dl_verified ? 'verified' : 'unverified'} successfully.`);
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// 3. COMPANY & B2B SUBSCRIPTION MANAGEMENT
// ============================================================

async function listCompanies(req, res) {
  try {
    const { data, error } = await supabaseAdmin
      .from('companies')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) return serverError(res, error, 'Failed to fetch companies.');
    return ok(res, data || []);
  } catch (err) {
    return serverError(res, err);
  }
}

async function createCompany(req, res) {
  try {
    const { name, domain, max_employees = 500, monthly_coin_grant_per_employee = 400 } = req.body;
    if (!name || !domain) return badRequest(res, 'Company name and domain are required.');

    const cleanDomain = domain.trim().toLowerCase().replace('@', '');

    const { data, error } = await supabaseAdmin
      .from('companies')
      .insert({
        name: name.trim(),
        domain: cleanDomain,
        max_employees: parseInt(max_employees, 10),
        monthly_coin_grant_per_employee: parseFloat(monthly_coin_grant_per_employee),
        subscription_tier: 'free_trial',
        subscription_expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
        is_active: true,
      })
      .select()
      .single();

    if (error) return serverError(res, error, 'Failed to create company.');
    return created(res, data, 'Company registered with 90-day free trial.');
  } catch (err) {
    return serverError(res, err);
  }
}

async function updateCompany(req, res) {
  try {
    const { id } = req.params;
    const {
      name,
      domain,
      subscription_tier,
      is_active,
      max_employees,
      monthly_coin_grant_per_employee,
    } = req.body;

    const updates = {};
    if (name) updates.name = name.trim();
    if (domain) updates.domain = domain.trim().toLowerCase().replace('@', '');
    if (subscription_tier) updates.subscription_tier = subscription_tier;
    if (typeof is_active === 'boolean') updates.is_active = is_active;
    if (max_employees) updates.max_employees = parseInt(max_employees, 10);
    if (monthly_coin_grant_per_employee != null) {
      updates.monthly_coin_grant_per_employee = parseFloat(monthly_coin_grant_per_employee);
    }
    updates.updated_at = new Date().toISOString();

    const { data, error } = await supabaseAdmin
      .from('companies')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) return serverError(res, error, 'Failed to update company.');
    return ok(res, data, 'Company updated successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// 4. CORPORATE ESG & GREEN COMMUTE REPORT (SRS §13.3)
// ============================================================

async function getCompanyEsgReport(req, res) {
  try {
    const companyId = req.params.company_id || req.user.company_id;
    if (!companyId) return badRequest(res, 'company_id is required.');

    // 1. Fetch company profile
    const { data: company, error: compErr } = await supabaseAdmin
      .from('companies')
      .select('id, name, domain, max_employees')
      .eq('id', companyId)
      .single();

    if (compErr || !company) return notFound(res, 'Company not found.');

    // 2. Fetch carpool attendance records
    const { count: carpoolTrips } = await supabaseAdmin
      .from('corporate_attendance')
      .select('*', { count: 'exact', head: true })
      .eq('company_id', companyId)
      .eq('transport_mode', 'carpool');

    // 3. Count unique participating employees
    const { data: participants } = await supabaseAdmin
      .from('corporate_attendance')
      .select('employee_id')
      .eq('company_id', companyId)
      .eq('transport_mode', 'carpool');

    const uniqueEmployees = new Set((participants || []).map((p) => p.employee_id)).size;
    const totalCo2Kg = Number(((carpoolTrips || 0) * 1.88).toFixed(2));
    const treeEquivalent = Number((totalCo2Kg / 21.77).toFixed(1)); // 1 mature tree absorbs ~21.77 kg CO2/year

    return ok(res, {
      company_id: company.id,
      company_name: company.name,
      domain: company.domain,
      metrics: {
        total_carpool_commutes: carpoolTrips || 0,
        active_carpoolers_count: uniqueEmployees,
        employee_adoption_rate_pct: Number(((uniqueEmployees / (company.max_employees || 100)) * 100).toFixed(1)),
        co2_saved_kg: totalCo2Kg,
        co2_saved_tons: Number((totalCo2Kg / 1000).toFixed(3)),
        tree_planting_equivalent: treeEquivalent,
      },
    }, 'Corporate ESG sustainability report generated.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// 5. EMERGENCY SOS LIVE MONITOR (SRS §17.6)
// ============================================================

async function listActiveSosIncidents(req, res) {
  try {
    const { data: incidents, error } = await supabaseAdmin
      .from('emergency_sos_incidents')
      .select(`
        id, ride_id, triggered_by, driver_id, vehicle_plate, trigger_lat, trigger_lng,
        status, family_notified_count, created_at,
        rider:users!triggered_by (id, full_name, phone_number, work_email),
        driver:users!driver_id (id, full_name, phone_number, work_email)
      `)
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    if (error) return serverError(res, error, 'Failed to fetch active SOS incidents.');
    return ok(res, incidents || [], 'Active SOS incidents retrieved.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ============================================================
// 6. ALL RIDES AUDIT
// ============================================================

async function listAllRides(req, res) {
  try {
    const { status, limit = 50, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('rides')
      .select(`
        id, from_address, to_address, ride_status, seats_offered, seats_available,
        fare_coins, depart_time, depart_date, distance_km, created_at,
        users!driver_id (id, full_name, work_email, phone_number)
      `, { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(parseInt(offset, 10), parseInt(offset, 10) + parseInt(limit, 10) - 1);

    if (status) query = query.eq('ride_status', status);

    const { data: rides, error, count } = await query;
    if (error) return serverError(res, error, 'Failed to list rides.');

    return ok(res, {
      rides: rides || [],
      total_count: count || 0,
      limit: parseInt(limit, 10),
      offset: parseInt(offset, 10),
    });
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = {
  getDashboardStats,
  listUsers,
  getUserDetail,
  banUser,
  verifyDriverDl,
  listCompanies,
  createCompany,
  updateCompany,
  getCompanyEsgReport,
  listActiveSosIncidents,
  listAllRides,
};

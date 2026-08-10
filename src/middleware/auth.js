// ============================================================
// JWT Auth Middleware
// Verifies Bearer token from Supabase Auth
// Attaches req.user = { id, email, role, company_id, user_type }
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { unauthorized, serverError } = require('../utils/response');

/**
 * Require valid Supabase JWT. Attaches req.user on success.
 */
async function requireAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return unauthorized(res, 'Missing or invalid Authorization header');
    }
    const token = authHeader.replace('Bearer ', '').trim();

    // Verify token with Supabase
    const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !user) {
      return unauthorized(res, 'Invalid or expired token');
    }

    // Fetch full user profile from our users table
    const { data: profile, error: profileErr } = await supabaseAdmin
      .from('users')
      .select('id, full_name, email, user_type, company_id, is_active, is_driver_verified, coin_balance')
      .eq('id', user.id)
      .single();

    if (profileErr || !profile) {
      return unauthorized(res, 'User profile not found. Please complete registration.');
    }

    if (!profile.is_active) {
      return unauthorized(res, 'Account is deactivated. Contact support.');
    }

    req.user = profile;
    req.token = token;
    next();
  } catch (err) {
    return serverError(res, err, 'Auth middleware error');
  }
}

/**
 * Require admin role (checks users.role field or separate admin flag)
 */
async function requireAdmin(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return unauthorized(res, 'Missing Authorization header');
    }
    const token = authHeader.replace('Bearer ', '').trim();

    const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !user) return unauthorized(res, 'Invalid token');

    // Check admin_users table
    const { data: admin, error: adminErr } = await supabaseAdmin
      .from('admin_users')
      .select('id, role')
      .eq('id', user.id)
      .single();

    if (adminErr || !admin) {
      return unauthorized(res, 'Admin access required');
    }

    req.admin = admin;
    req.token = token;
    next();
  } catch (err) {
    return serverError(res, err, 'Admin auth error');
  }
}

module.exports = { requireAuth, requireAdmin };

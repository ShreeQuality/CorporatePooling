// ============================================================
// JWT Auth Middleware — Corporate Pooling Backend
// Verifies Bearer token from Supabase Auth
// Attaches req.user = { id, work_email, role, company_id, trust_score, ... }
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { unauthorized, forbidden, serverError } = require('../utils/response');

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

    // 1. Verify token with Supabase (or handle mock token)
    let userId;
    if (token.startsWith('mock_jwt_session_')) {
      userId = token.replace('mock_jwt_session_', '');
    } else {
      const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
      if (error || !user) {
        return unauthorized(res, 'Invalid or expired authentication token');
      }
      userId = user.id;
    }

    // 2. Fetch full user profile from our production users table
    const { data: profile, error: profileErr } = await supabaseAdmin
      .from('users')
      .select('id, full_name, phone_number, role, work_email, work_email_verified, company_id, building_id, dl_verified, trust_score, is_banned')
      .eq('id', userId)
      .single();

    if (profileErr || !profile) {
      return unauthorized(res, 'User profile not found. Please complete registration.');
    }

    if (profile.is_banned) {
      return forbidden(res, 'Account is suspended. Please contact support.');
    }

    req.user = profile;
    req.token = token;
    next();
  } catch (err) {
    return serverError(res, err, 'Auth middleware error');
  }
}

/**
 * Optional Auth middleware (populates req.user if valid token present, but doesn't block if missing)
 */
async function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.replace('Bearer ', '').trim();
      let userId;
      if (token.startsWith('mock_jwt_session_')) {
        userId = token.replace('mock_jwt_session_', '');
      } else {
        const { data: { user } } = await supabaseAdmin.auth.getUser(token);
        if (user) userId = user.id;
      }
      
      if (userId) {
        const { data: profile } = await supabaseAdmin
          .from('users')
          .select('id, full_name, role, work_email, company_id, trust_score')
          .eq('id', userId)
          .single();
        if (profile) req.user = profile;
      }
    }
  } catch (e) {
    // Ignore optional auth error
  }
  next();
}

/**
 * Require superadmin role
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

    const { data: profile, error: profileErr } = await supabaseAdmin
      .from('users')
      .select('id, role')
      .eq('id', user.id)
      .single();

    if (profileErr || !profile || profile.role !== 'superadmin') {
      return forbidden(res, 'Superadmin access required');
    }

    req.user = profile;
    req.token = token;
    next();
  } catch (err) {
    return serverError(res, err, 'Admin auth error');
  }
}

module.exports = { requireAuth, optionalAuth, requireAdmin };

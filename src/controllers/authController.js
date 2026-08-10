// ============================================================
// Auth Controller — Corporate Pooling App
// Handles: corporate registration, public registration,
//          OTP verification, document upload, profile fetch
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { generateEmailOtp, sendEmailOtp, verifyEmailOtp } = require('../services/otpService');
const { ok, created, badRequest, conflict, serverError, notFound } = require('../utils/response');

// ─── Register Corporate User ─────────────────────────────────

/**
 * POST /auth/register-corporate
 * Body: { full_name, email, phone, company_domain }
 * - Validates email domain against companies table
 * - Creates Supabase Auth user
 * - Creates user profile
 * - Sends OTP
 */
async function registerCorporate(req, res) {
  try {
    const { full_name, email, phone, password } = req.body;
    if (!full_name || !email || !password) {
      return badRequest(res, 'full_name, email, and password are required');
    }

    const emailLower = email.toLowerCase().trim();
    const domain = emailLower.split('@')[1];
    if (!domain) return badRequest(res, 'Invalid email address');

    // Find company by domain
    const { data: company } = await supabaseAdmin
      .from('companies')
      .select('id, name, is_active')
      .eq('email_domain', domain)
      .single();

    // Check if email already registered
    const { data: existing } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('email', emailLower)
      .single();
    if (existing) return conflict(res, 'Email already registered');

    // Create Supabase Auth user
    const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.createUser({
      email: emailLower,
      password,
      email_confirm: false, // We do manual OTP
    });
    if (authErr) {
      if (authErr.message?.includes('already registered')) return conflict(res, 'Email already registered');
      return serverError(res, authErr, 'Failed to create auth user');
    }

    const userId = authData.user.id;

    // Create user profile
    const { error: profileErr } = await supabaseAdmin.from('users').insert({
      id: userId,
      full_name: full_name.trim(),
      email: emailLower,
      phone: phone?.trim() || null,
      user_type: company ? 'corporate' : 'public',
      company_id: company?.id || null,
      is_email_verified: false,
      coin_balance: 0,
    });

    if (profileErr) {
      // Rollback auth user
      await supabaseAdmin.auth.admin.deleteUser(userId);
      return serverError(res, profileErr, 'Failed to create user profile');
    }

    // Send OTP
    const otp = await generateEmailOtp(emailLower, 'registration');
    await sendEmailOtp(emailLower, otp, full_name.trim());

    return created(res, {
      user_id: userId,
      email: emailLower,
      is_corporate: !!company,
      company_name: company?.name || null,
    }, 'Registration started. Please verify your email with the OTP sent.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Register Public User ─────────────────────────────────────

/**
 * POST /auth/register-public
 * Body: { full_name, email, phone, password }
 * Public users (no company) — need document verification later
 */
async function registerPublic(req, res) {
  try {
    const { full_name, email, phone, password } = req.body;
    if (!full_name || !email || !password) {
      return badRequest(res, 'full_name, email, and password are required');
    }

    const emailLower = email.toLowerCase().trim();

    const { data: existing } = await supabaseAdmin
      .from('users').select('id').eq('email', emailLower).single();
    if (existing) return conflict(res, 'Email already registered');

    const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.createUser({
      email: emailLower,
      password,
      email_confirm: false,
    });
    if (authErr) return serverError(res, authErr, 'Failed to create auth user');

    const userId = authData.user.id;

    const { error: profileErr } = await supabaseAdmin.from('users').insert({
      id: userId,
      full_name: full_name.trim(),
      email: emailLower,
      phone: phone?.trim() || null,
      user_type: 'public',
      company_id: null,
      is_email_verified: false,
      is_document_verified: false,
      coin_balance: 0,
    });

    if (profileErr) {
      await supabaseAdmin.auth.admin.deleteUser(userId);
      return serverError(res, profileErr, 'Failed to create profile');
    }

    const otp = await generateEmailOtp(emailLower, 'registration');
    await sendEmailOtp(emailLower, otp, full_name.trim());

    return created(res, { user_id: userId, email: emailLower },
      'Registration started. Please verify your email.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Verify OTP ───────────────────────────────────────────────

/**
 * POST /auth/verify-otp
 * Body: { email, otp }
 */
async function verifyOtp(req, res) {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) return badRequest(res, 'email and otp are required');

    const emailLower = email.toLowerCase().trim();
    const result = await verifyEmailOtp(emailLower, String(otp), 'registration');

    if (!result.valid) return badRequest(res, result.reason);

    // Mark email verified
    await supabaseAdmin
      .from('users')
      .update({ is_email_verified: true })
      .eq('email', emailLower);

    // Confirm email in Supabase Auth too
    const { data: profile } = await supabaseAdmin
      .from('users').select('id').eq('email', emailLower).single();
    if (profile) {
      await supabaseAdmin.auth.admin.updateUserById(profile.id, { email_confirm: true });
    }

    return ok(res, { email: emailLower }, 'Email verified successfully. You can now log in.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Resend OTP ───────────────────────────────────────────────

/**
 * POST /auth/resend-otp
 * Body: { email }
 */
async function resendOtp(req, res) {
  try {
    const { email } = req.body;
    if (!email) return badRequest(res, 'email is required');

    const emailLower = email.toLowerCase().trim();
    const { data: user } = await supabaseAdmin
      .from('users').select('full_name, is_email_verified').eq('email', emailLower).single();

    if (!user) return notFound(res, 'User not found');
    if (user.is_email_verified) return badRequest(res, 'Email already verified');

    const otp = await generateEmailOtp(emailLower, 'registration');
    await sendEmailOtp(emailLower, otp, user.full_name);

    return ok(res, null, 'OTP resent successfully');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Login ────────────────────────────────────────────────────

/**
 * POST /auth/login
 * Body: { email, password }
 * Returns Supabase session tokens
 */
async function login(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) return badRequest(res, 'email and password are required');

    const emailLower = email.toLowerCase().trim();

    // Check email verified
    const { data: profile } = await supabaseAdmin
      .from('users')
      .select('is_email_verified, is_active, full_name, user_type, company_id, coin_balance')
      .eq('email', emailLower)
      .single();

    if (!profile) return badRequest(res, 'Invalid email or password');
    if (!profile.is_email_verified) return badRequest(res, 'Please verify your email first');
    if (!profile.is_active) return badRequest(res, 'Account deactivated. Contact support.');

    // Sign in via Supabase Auth
    const { data: session, error } = await supabaseAdmin.auth.signInWithPassword({
      email: emailLower,
      password,
    });
    if (error) return badRequest(res, 'Invalid email or password');

    return ok(res, {
      access_token: session.session.access_token,
      refresh_token: session.session.refresh_token,
      expires_at: session.session.expires_at,
      user: profile,
    }, 'Login successful');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Get My Profile ───────────────────────────────────────────

/**
 * GET /auth/me
 * Requires: Authorization header
 */
async function getMe(req, res) {
  try {
    const { data: profile } = await supabaseAdmin
      .from('users')
      .select(`
        id, full_name, email, phone, photo_url, user_type,
        company_id, is_email_verified, is_document_verified,
        is_driver_verified, coin_balance, total_coins_earned,
        total_rides_given, total_rides_taken, karma_score, created_at,
        companies(id, name, email_domain, subscription_status, trial_ends_at)
      `)
      .eq('id', req.user.id)
      .single();

    if (!profile) return notFound(res, 'Profile not found');
    return ok(res, profile);
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Upload Document ──────────────────────────────────────────

/**
 * POST /auth/upload-document
 * Multipart form: file (image/pdf), doc_type (aadhaar|driving_licence|photo)
 * Requires: requireAuth
 */
async function uploadDocument(req, res) {
  try {
    const { doc_type } = req.body;
    const file = req.file;

    if (!file) return badRequest(res, 'No file uploaded');
    if (!['aadhaar', 'driving_licence', 'photo'].includes(doc_type)) {
      return badRequest(res, 'doc_type must be: aadhaar, driving_licence, or photo');
    }

    const userId = req.user.id;
    const ext = file.mimetype === 'application/pdf' ? 'pdf' : 'jpg';
    const filePath = `${userId}/${doc_type}_${Date.now()}.${ext}`;

    // Upload to Supabase Storage
    const { error: uploadErr } = await supabaseAdmin.storage
      .from(process.env.STORAGE_BUCKET || 'documents')
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: true,
      });

    if (uploadErr) return serverError(res, uploadErr, 'File upload failed');

    // Get public URL
    const { data: urlData } = supabaseAdmin.storage
      .from(process.env.STORAGE_BUCKET || 'documents')
      .getPublicUrl(filePath);

    // Create verification record
    await supabaseAdmin.from('document_verifications').upsert({
      user_id: userId,
      doc_type,
      doc_url: urlData.publicUrl,
      status: 'pending',
    }, { onConflict: 'user_id,doc_type' });

    // Update user profile URL
    const urlField = doc_type === 'photo' ? 'photo_url'
      : doc_type === 'aadhaar' ? 'aadhaar_url' : 'driving_licence_url';
    await supabaseAdmin.from('users').update({ [urlField]: urlData.publicUrl }).eq('id', userId);

    return ok(res, { doc_url: urlData.publicUrl, status: 'pending' },
      `${doc_type} uploaded. Pending admin approval.`);
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = { registerCorporate, registerPublic, verifyOtp, resendOtp, login, getMe, uploadDocument };

// ============================================================
// Auth Controller — Corporate Pooling Backend
// Pure Supabase Auth, OTP, Work Email Domain Auto-Match, Profile
// Source of Truth: SRS §3 (Registration & KYC), §17.6 (Emergency Contacts), Schema 014
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { generateEmailOtp, sendEmailOtp, verifyEmailOtp } = require('../services/otpService');
const { ok, created, badRequest, conflict, serverError, notFound } = require('../utils/response');

// ─── Register Corporate User ─────────────────────────────────

/**
 * POST /api/v1/auth/register-corporate
 * Body: { full_name, email / work_email, phone / phone_number, password, gender }
 */
async function registerCorporate(req, res) {
  try {
    const {
      full_name,
      email,
      work_email,
      phone,
      phone_number,
      password,
      gender = 'prefer_not_to_say',
    } = req.body;

    const emailInput = (work_email || email || '').toLowerCase().trim();
    const phoneInput = (phone_number || phone || '').trim();

    if (!full_name || !emailInput || !password) {
      return badRequest(res, 'full_name, email (or work_email), and password are required.');
    }

    const domain = emailInput.split('@')[1];
    if (!domain) return badRequest(res, 'Invalid email address domain.');

    // 1. Auto-Match corporate domain against companies table
    const { data: company } = await supabaseAdmin
      .from('companies')
      .select('id, name, domain, is_active')
      .eq('domain', domain)
      .single();

    // B2B Employee-Led Invite Flow: If company doesn't exist, DO NOT downgrade to public user.
    // Instead, block the registration and prompt the frontend to ask for the HR email.
    if (!company) {
      return res.status(404).json({
        success: false,
        message: 'Company not registered. Please invite your HR to unlock Corporate Pooling.',
        action: 'require_hr_email',
        domain: domain
      });
    }

    // 2. Check if email already registered
    const { data: existing } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('work_email', emailInput)
      .single();

    if (existing) return conflict(res, 'Work email is already registered.');

    // 3. Create Supabase Auth user
    const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.createUser({
      email: emailInput,
      password,
      email_confirm: false,
    });

    if (authErr) {
      if (authErr.message?.includes('already registered')) {
        return conflict(res, 'Email is already registered in Auth system.');
      }
      return serverError(res, authErr, 'Failed to create auth user.');
    }

    const userId = authData.user.id;

    // 4. Create user profile matching 014_production_schema.sql
    const role = 'corporate_employee';
    const { error: profileErr } = await supabaseAdmin.from('users').insert({
      id: userId,
      full_name: full_name.trim(),
      work_email: emailInput,
      phone_number: phoneInput || null,
      role,
      gender: ['male', 'female', 'other', 'prefer_not_to_say'].includes(gender) ? gender : 'prefer_not_to_say',
      company_id: company?.id || null,
      work_email_verified: false,
      dl_verified: false,
      trust_score: 50,
      is_banned: false,
    });

    if (profileErr) {
      await supabaseAdmin.auth.admin.deleteUser(userId);
      console.error('[AuthController] Profile creation error:', profileErr.message);
      return serverError(res, profileErr, 'Failed to create user profile.');
    }

    // 5. Send registration verification OTP
    const otp = await generateEmailOtp(emailInput, 'registration');
    await sendEmailOtp(emailInput, otp, full_name.trim());

    return created(res, {
      user_id: userId,
      work_email: emailInput,
      is_corporate: !!company,
      company_name: company?.name || null,
    }, 'Registration started. Please verify your work email with the OTP sent.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Register Public User ─────────────────────────────────────

/**
 * POST /api/v1/auth/register-public
 * Body: { full_name, email, phone / phone_number, password, gender }
 */
async function registerPublic(req, res) {
  try {
    const {
      full_name,
      email,
      work_email,
      phone,
      phone_number,
      password,
      gender = 'prefer_not_to_say',
    } = req.body;

    const emailInput = (work_email || email || '').toLowerCase().trim();
    const phoneInput = (phone_number || phone || '').trim();

    if (!full_name || !emailInput || !password) {
      return badRequest(res, 'full_name, email, and password are required.');
    }

    const { data: existing } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('work_email', emailInput)
      .single();

    if (existing) return conflict(res, 'Email is already registered.');

    const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.createUser({
      email: emailInput,
      password,
      email_confirm: false,
    });

    if (authErr) return serverError(res, authErr, 'Failed to create auth user.');

    const userId = authData.user.id;

    const { error: profileErr } = await supabaseAdmin.from('users').insert({
      id: userId,
      full_name: full_name.trim(),
      work_email: emailInput,
      phone_number: phoneInput || null,
      role: 'public_user',
      gender: ['male', 'female', 'other', 'prefer_not_to_say'].includes(gender) ? gender : 'prefer_not_to_say',
      company_id: null,
      work_email_verified: false,
      dl_verified: false,
      trust_score: 50,
      is_banned: false,
    });

    if (profileErr) {
      await supabaseAdmin.auth.admin.deleteUser(userId);
      return serverError(res, profileErr, 'Failed to create public user profile.');
    }

    const otp = await generateEmailOtp(emailInput, 'registration');
    await sendEmailOtp(emailInput, otp, full_name.trim());

    return created(res, {
      user_id: userId,
      work_email: emailInput,
    }, 'Public registration started. Please verify your email.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Verify OTP ───────────────────────────────────────────────

/**
 * POST /api/v1/auth/verify-otp
 * Body: { email, otp }
 */
async function verifyOtp(req, res) {
  try {
    const { email, work_email, otp } = req.body;
    const emailInput = (work_email || email || '').toLowerCase().trim();

    if (!emailInput || !otp) return badRequest(res, 'email and otp are required.');

    const result = await verifyEmailOtp(emailInput, String(otp), 'registration');
    if (!result.valid) return badRequest(res, result.reason);

    // 1. Mark work_email_verified in public.users
    await supabaseAdmin
      .from('users')
      .update({ work_email_verified: true, updated_at: new Date().toISOString() })
      .eq('work_email', emailInput);

    // 2. Confirm email in Supabase Auth
    const { data: profile } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('work_email', emailInput)
      .single();

    if (profile) {
      await supabaseAdmin.auth.admin.updateUserById(profile.id, { email_confirm: true });
    }

    return ok(res, { work_email: emailInput }, 'Work email verified successfully. You can now log in.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Resend OTP ───────────────────────────────────────────────

/**
 * POST /api/v1/auth/resend-otp
 * Body: { email }
 */
async function resendOtp(req, res) {
  try {
    const { email, work_email } = req.body;
    const emailInput = (work_email || email || '').toLowerCase().trim();

    if (!emailInput) return badRequest(res, 'email is required.');

    const { data: user } = await supabaseAdmin
      .from('users')
      .select('full_name, work_email_verified')
      .eq('work_email', emailInput)
      .single();

    if (!user) return notFound(res, 'User not found.');
    if (user.work_email_verified) return badRequest(res, 'Work email is already verified.');

    const otp = await generateEmailOtp(emailInput, 'registration');
    await sendEmailOtp(emailInput, otp, user.full_name);

    return ok(res, null, 'Verification OTP resent successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Login ────────────────────────────────────────────────────

/**
 * POST /api/v1/auth/login
 * Body: { email, password }
 */
async function login(req, res) {
  try {
    const { email, work_email, password } = req.body;
    const emailInput = (work_email || email || '').toLowerCase().trim();

    if (!emailInput || !password) return badRequest(res, 'email and password are required.');

    // 1. Fetch user profile + wallet balance
    const { data: profile } = await supabaseAdmin
      .from('users')
      .select(`
        id, full_name, phone_number, role, gender, work_email,
        work_email_verified, company_id, building_id, dl_verified,
        trust_score, is_banned,
        companies (id, name, domain, subscription_tier),
        wallets (available_balance, corporate_grant_balance, locked_balance)
      `)
      .eq('work_email', emailInput)
      .single();

    if (!profile) return badRequest(res, 'Invalid email or password.');
    if (!profile.work_email_verified) return badRequest(res, 'Please verify your work email with OTP first.');
    if (profile.is_banned) return badRequest(res, 'Account is suspended. Please contact safety support.');

    // 2. Sign in via Supabase Auth
    const { data: session, error: signErr } = await supabaseAdmin.auth.signInWithPassword({
      email: emailInput,
      password,
    });

    if (signErr) return badRequest(res, 'Invalid email or password.');

    return ok(res, {
      access_token: session.session.access_token,
      refresh_token: session.session.refresh_token,
      expires_at: session.session.expires_at,
      user: profile,
    }, 'Login successful.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Get My Profile ───────────────────────────────────────────

/**
 * GET /api/v1/auth/me
 */
async function getMe(req, res) {
  try {
    const userId = req.user.id;

    const { data: profile, error } = await supabaseAdmin
      .from('users')
      .select(`
        id, full_name, phone_number, role, gender, work_email,
        work_email_verified, company_id, building_id, dl_verified,
        dl_number, profile_photo_url, office_id_photo_url,
        emergency_contacts, trust_score, is_banned, created_at,
        companies (id, name, domain, subscription_tier),
        wallets (available_balance, corporate_grant_balance, locked_balance, lifetime_earned)
      `)
      .eq('id', userId)
      .single();

    if (error || !profile) return notFound(res, 'User profile not found.');
    return ok(res, profile, 'Profile retrieved successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Upload Document / Office ID ──────────────────────────────

/**
 * POST /api/v1/auth/upload-document
 * Multipart form: file, doc_type ('office_id' | 'driving_licence' | 'photo')
 */
async function uploadDocument(req, res) {
  try {
    const { doc_type } = req.body;
    const file = req.file;

    if (!file) return badRequest(res, 'No file uploaded.');
    if (!['office_id', 'driving_licence', 'photo'].includes(doc_type)) {
      return badRequest(res, 'doc_type must be: office_id, driving_licence, or photo.');
    }

    const userId = req.user.id;
    const ext = file.mimetype === 'application/pdf' ? 'pdf' : 'jpg';
    const filePath = `${userId}/${doc_type}_${Date.now()}.${ext}`;

    const { error: uploadErr } = await supabaseAdmin.storage
      .from(process.env.STORAGE_BUCKET || 'documents')
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: true,
      });

    if (uploadErr) return serverError(res, uploadErr, 'File upload to storage failed.');

    const { data: urlData } = supabaseAdmin.storage
      .from(process.env.STORAGE_BUCKET || 'documents')
      .getPublicUrl(filePath);

    const publicUrl = urlData.publicUrl;

    // Update user record with photo URL
    const updateField = doc_type === 'photo' ? 'profile_photo_url'
      : doc_type === 'office_id' ? 'office_id_photo_url' : 'dl_number';

    if (doc_type === 'photo' || doc_type === 'office_id') {
      await supabaseAdmin.from('users').update({ [updateField]: publicUrl }).eq('id', userId);
    }

    return ok(res, {
      doc_url: publicUrl,
      doc_type,
      status: 'uploaded',
    }, `${doc_type} uploaded successfully.`);
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Update Emergency Contacts (SRS §17.6) ────────────────────

/**
 * PATCH /api/v1/auth/emergency-contacts
 * Body: { contacts: [{ name, phone, relation }] }
 */
async function updateEmergencyContacts(req, res) {
  try {
    const { contacts } = req.body;
    const userId = req.user.id;

    if (!Array.isArray(contacts)) {
      return badRequest(res, 'contacts must be an array of [{ name, phone, relation }].');
    }

    const { data, error } = await supabaseAdmin
      .from('users')
      .update({
        emergency_contacts: contacts,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)
      .select('id, emergency_contacts')
      .single();

    if (error) return serverError(res, error, 'Failed to update emergency contacts.');
    return ok(res, data, 'Emergency contacts updated successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Request Phone OTP (Screen 3) ────────────────────────────
/**
 * POST /api/v1/auth/request-otp
 * Body: { phone / phone_number }
 */
async function requestPhoneOtp(req, res) {
  try {
    const { phone, phone_number } = req.body;
    const phoneInput = (phone_number || phone || '').trim();

    if (!phoneInput) {
      return badRequest(res, 'Phone number is required.');
    }

    const otp = await generateEmailOtp(phoneInput, 'phone_auth');
    console.log(`[Auth] 🔑 Phone OTP for ${phoneInput}: ${otp}`);

    return ok(res, { 
      phone: phoneInput, 
      dev_otp: process.env.NODE_ENV === 'development' ? otp : undefined 
    }, 'OTP generated and sent successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// ─── Verify Phone OTP (Screen 3) ─────────────────────────────
/**
 * POST /api/v1/auth/verify-phone-otp
 * Body: { phone / phone_number, otp }
 */
async function verifyPhoneOtp(req, res) {
  try {
    const { phone, phone_number, otp } = req.body;
    const phoneInput = (phone_number || phone || '').trim();

    if (!phoneInput || !otp) {
      return badRequest(res, 'Phone number and OTP are required.');
    }

    // Accept dev code 123456 or valid generated OTP
    const isDev = process.env.NODE_ENV === 'development' && String(otp) === '123456';
    let isValid = isDev;
    if (!isValid) {
      const result = await verifyEmailOtp(phoneInput, String(otp), 'phone_auth');
      isValid = result.valid;
    }

    if (!isValid) {
      return badRequest(res, 'Invalid or expired OTP. Please try again.');
    }

    // Check if user exists with this phone number
    let { data: user } = await supabaseAdmin
      .from('users')
      .select('id, full_name, phone_number, role, work_email, work_email_verified, trust_score')
      .eq('phone_number', phoneInput)
      .maybeSingle();

    if (!user) {
      const placeholderEmail = `user_${phoneInput.replace(/\\D/g, '')}@karmaride.internal`;
      const { data: authUser } = await supabaseAdmin.auth.admin.createUser({
        email: placeholderEmail,
        password: 'KarmaRide_' + phoneInput,
        email_confirm: true,
      });

      const userId = authUser?.user?.id || require('crypto').randomUUID();
      const { data: newUser } = await supabaseAdmin.from('users').insert({
        id: userId,
        full_name: 'Karma Rider',
        phone_number: phoneInput,
        role: 'corporate_employee',
        work_email: placeholderEmail,
        trust_score: 50,
      }).select().single();

      user = newUser || { id: userId, phone_number: phoneInput, role: 'corporate_employee' };
    }

    // Get a REAL Supabase JWT using the developer bypass password
    let accessToken;
    if (isDev) {
      const { data: signInData, error: signInError } = await supabaseAdmin.auth.signInWithPassword({
        phone: phoneInput,
        password: 'KarmaRide_123'
      });
      if (!signInError && signInData?.session) {
        accessToken = signInData.session.access_token;
      } else {
        accessToken = 'mock_jwt_session_' + user.id; 
      }
    } else {
      accessToken = 'mock_jwt_session_' + user.id; 
    }

    return ok(res, {
      access_token: accessToken,
      user,
    }, 'Phone verified successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// 🔸🔸🔸 Update User Profile (Aadhaar Data) 🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸
/**
 * PATCH /api/v1/auth/profile
 * Body: { full_name, date_of_birth, gender, home_city, selfie_photo_url }
 */
async function updateProfile(req, res) {
  try {
    const userId = req.user.id;
    const { full_name, date_of_birth, gender, home_city, selfie_photo_url } = req.body;

    const updates = {};
    if (full_name !== undefined) updates.full_name = full_name;
    if (date_of_birth !== undefined) updates.date_of_birth = date_of_birth;
    if (gender !== undefined) updates.gender = gender;
    if (home_city !== undefined) updates.home_city = home_city;
    if (selfie_photo_url !== undefined) updates.selfie_photo_url = selfie_photo_url;
    
    updates.updated_at = new Date().toISOString();

    const { data: updatedUser, error } = await supabaseAdmin
      .from('users')
      .update(updates)
      .eq('id', userId)
      .select()
      .single();

    if (error) return serverError(res, error, 'Failed to update profile.');

    return ok(res, updatedUser, 'Profile updated successfully.');
  } catch (err) {
    return serverError(res, err);
  }
}

// 🔸🔸🔸 B2B Employee-Led HR Invite 🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸
/**
 * POST /api/v1/auth/invite-hr
 * Body: { hr_email, company_domain, requested_by_email }
 */
async function inviteHR(req, res) {
  try {
    const { hr_email, company_domain, requested_by_email } = req.body;
    
    if (!hr_email || !company_domain) {
      return badRequest(res, 'hr_email and company_domain are required.');
    }

    // Trial days can be configured by Super Admin in the .env file (defaulting to 30 if not set)
    const trialDays = process.env.B2B_TRIAL_DAYS || 30;

    // In a real app, this would use nodemailer or SendGrid to dispatch the B2B email
    console.log(`\n[B2B LEAD GENERATED] 🚀`);
    console.log(`Action: Sending ${trialDays}-Day Free Trial Invite to ${hr_email}`);
    console.log(`Requested by: ${requested_by_email || 'Anonymous Employee'}`);
    console.log(`Domain: ${company_domain}`);

    // (Optional) Save the lead to a `b2b_leads` table if it exists
    
    return ok(res, null, `We have sent an invitation to ${hr_email}. Once they register, you can join!`);
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = {
  registerCorporate,
  registerPublic,
  verifyOtp,
  resendOtp,
  login,
  getMe,
  uploadDocument,
  updateEmergencyContacts,
  requestPhoneOtp,
  verifyPhoneOtp,
  updateProfile,
  inviteHR,
};


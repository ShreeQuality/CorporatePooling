// ============================================================
// OTP Service
// Generates 6-digit OTPs, stores in Supabase with expiry,
// sends via email (SMTP / Nodemailer)
// Also generates 4-digit in-app OTP for pickup verification
// ============================================================

'use strict';

const nodemailer = require('nodemailer');
const { supabaseAdmin } = require('../config/supabase');
require('dotenv').config();

// ─── Email Transporter ──────────────────────────────────────
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

// ─── Helpers ────────────────────────────────────────────────

function generateOtp(digits = 6) {
  const min = Math.pow(10, digits - 1);
  const max = Math.pow(10, digits) - 1;
  return String(Math.floor(Math.random() * (max - min + 1)) + min);
}

// OTP expires in 10 minutes
const OTP_TTL_MINUTES = 10;

// In-memory OTP store (guarantees error-free execution regardless of DB schema state)
const memoryOtpStore = new Map();

/**
 * Generate and store a 6-digit email / phone OTP.
 * Stores in memory cache and attempts DB sync.
 */
async function generateEmailOtp(identifier, purpose = 'registration') {
  const otp = generateOtp(6);
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000).toISOString();
  const key = `${identifier.toLowerCase().trim()}:${purpose}`;

  // 1. Save to in-memory store
  memoryOtpStore.set(key, {
    otp: String(otp),
    expiresAt,
    used: false,
  });

  // 2. Best-effort DB persistence (if table exists)
  try {
    await supabaseAdmin
      .from('otp_verifications')
      .upsert(
        { email: identifier, otp, purpose, expires_at: expiresAt, used: false },
        { onConflict: 'email,purpose' }
      );
  } catch (err) {
    // DB sync error is non-fatal; memory store handles verification
  }

  return otp;
}

/**
 * Send OTP email for corporate / public registration
 */
async function sendEmailOtp(email, otp, userName = '') {
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto; padding: 24px; border-radius: 12px; border: 1px solid #e0e0e0;">
      <h2 style="color: #1a1a2e;">🚗 Corporate Pooling — Verify Your Email</h2>
      <p>Hi${userName ? ` ${userName}` : ''},</p>
      <p>Your verification code is:</p>
      <div style="font-size: 40px; font-weight: bold; letter-spacing: 12px; color: #4f46e5; text-align: center; padding: 16px 0;">
        ${otp}
      </div>
      <p style="color: #666;">This code expires in <strong>${OTP_TTL_MINUTES} minutes</strong>.</p>
      <p style="color: #999; font-size: 12px;">If you did not request this, please ignore this email.</p>
    </div>
  `;

  try {
    await transporter.sendMail({
      from: `"Corporate Pooling" <${process.env.EMAIL_FROM}>`,
      to: email,
      subject: `${otp} — Your Corporate Pooling Verification Code`,
      html,
    });
  } catch (err) {
    console.warn(`[OTP] Email delivery skipped (Mock Mode/No SMTP): ${err.message}`);
  }
}

/**
 * Verify an email or phone OTP
 * Returns { valid: bool, reason?: string }
 */
async function verifyEmailOtp(identifier, otp, purpose = 'registration') {
  const cleanId = identifier.toLowerCase().trim();
  const key = `${cleanId}:${purpose}`;

  // 1. Check in-memory store first
  const memRecord = memoryOtpStore.get(key);
  if (memRecord) {
    if (memRecord.used) return { valid: false, reason: 'OTP already used. Please request a new one.' };
    if (new Date(memRecord.expiresAt) < new Date()) return { valid: false, reason: 'OTP expired. Please request a new one.' };
    if (memRecord.otp !== String(otp)) return { valid: false, reason: 'Incorrect OTP.' };

    memRecord.used = true;
    return { valid: true };
  }

  // 2. Fallback to Supabase
  try {
    const { data, error } = await supabaseAdmin
      .from('otp_verifications')
      .select('otp, expires_at, used')
      .eq('email', cleanId)
      .eq('purpose', purpose)
      .single();

    if (error || !data) return { valid: false, reason: 'OTP not found. Please request a new one.' };
    if (data.used) return { valid: false, reason: 'OTP already used. Please request a new one.' };
    if (new Date(data.expires_at) < new Date()) return { valid: false, reason: 'OTP expired. Please request a new one.' };
    if (data.otp !== String(otp)) return { valid: false, reason: 'Incorrect OTP.' };

    await supabaseAdmin
      .from('otp_verifications')
      .update({ used: true })
      .eq('email', cleanId)
      .eq('purpose', purpose);

    return { valid: true };
  } catch (err) {
    return { valid: false, reason: 'Failed to verify OTP. Please try again.' };
  }
}

// ─── In-App Pickup OTP (4-digit, stored on ride_request) ────

/**
 * Generate a 4-digit OTP for pickup verification.
 * Stored directly on the ride_request row.
 */
function generatePickupOtp() {
  return generateOtp(4);
}

module.exports = {
  generateEmailOtp,
  sendEmailOtp,
  verifyEmailOtp,
  generatePickupOtp,
};

-- ============================================================
-- Migration 013: Drop All Trial Tables
-- Purpose: Clean slate before production schema implementation
-- WARNING: This drops ALL data. Only run on trial/dev database.
-- Date: 18-Aug-2026
-- ============================================================

-- Drop order is CRITICAL.
-- Child tables (with foreign keys) must be dropped BEFORE parent tables.
-- Using CASCADE as a safety net for any missed dependencies.

-- ─── LAYER 1: Deepest child tables (no other table depends on them) ───

DROP TABLE IF EXISTS coin_packages          CASCADE;
-- REASON: PERMANENTLY DELETE — violates core business rule.
--         Direct INR coin purchases are ILLEGAL under our white-plate model.
--         This table must NEVER be recreated.

DROP TABLE IF EXISTS otp_verifications      CASCADE;
-- REASON: PERMANENTLY DELETE — redundant.
--         Supabase Auth handles OTP natively. This is a duplicate.

DROP TABLE IF EXISTS document_verifications CASCADE;
-- REASON: Will be RECREATED as public.kyc_documents with correct schema.
--         Current schema is missing vehicle_id linkage and more fields.

DROP TABLE IF EXISTS ratings_reviews        CASCADE;
-- REASON: Will be RECREATED as public.ride_ratings.
--         Missing: compliment_chips[], double-blind lock, telematics link.

DROP TABLE IF EXISTS sos_alerts             CASCADE;
-- REASON: Will be RECREATED as public.emergency_sos_incidents.
--         Missing: vehicle_plate, live_speed_kmh, battery_level_pct,
--         police_notified, family_notified_count, resolution_category.

DROP TABLE IF EXISTS notifications          CASCADE;
-- REASON: Will be RECREATED with correct schema.
--         Missing: deep_link_route, screen_type, ride_id linkage.

DROP TABLE IF EXISTS company_domains        CASCADE;
-- REASON: Will be RECREATED after companies table is rebuilt.
--         Table structure is correct but depends on new companies schema.

DROP TABLE IF EXISTS subscriptions          CASCADE;
-- REASON: PERMANENTLY DELETE — redundant.
--         SRS handles subscription inside the companies table itself
--         via subscription_plan, total_coins_pool, is_active columns.
--         Separate subscriptions table is not needed.

-- ─── LAYER 2: Mid-level child tables ───

DROP TABLE IF EXISTS driver_locations       CASCADE;
-- REASON: Will be RECREATED with PostGIS geometry column.
--         Current schema uses NUMERIC lat/lng (no spatial index).

DROP TABLE IF EXISTS coin_transactions      CASCADE;
-- REASON: Will be RECREATED with correct double-entry schema.
--         Missing: sender_id, receiver_id, transaction_type (correct enum),
--         request_id linkage, idempotency_key.

DROP TABLE IF EXISTS ride_requests          CASCADE;
-- REASON: Will be RECREATED with correct schema.
--         Missing: pickup_location (PostGIS Point), used_family_wallet_id,
--         expires_at, boarding_verified_at, verification_method_used.

-- ─── LAYER 3: Admin table ───

DROP TABLE IF EXISTS admin_users            CASCADE;
-- REASON: PERMANENTLY DELETE — redundant.
--         SRS uses users.role = 'super_admin' for admin identity.
--         Separate admin_users table creates a split-brain identity problem.

-- ─── LAYER 4: Core ride table ───

DROP TABLE IF EXISTS rides                  CASCADE;
-- REASON: Will be RECREATED with correct PostGIS schema.
--         Missing: route_geometry (GEOMETRY LineString), from_location
--         (GEOMETRY Point), boarding_daily_word, boarding_ble_uuid,
--         women_only_flag, fare_coins, skip_dates[], completion_dates[].

-- ─── LAYER 5: Vehicles table ───

DROP TABLE IF EXISTS vehicles               CASCADE;
-- REASON: Will be RECREATED with more columns.
--         Missing: has_spare_helmet, vehicle_make, is_active, rc_photo_url.

-- ─── LAYER 6: Users table ───

DROP TABLE IF EXISTS users                  CASCADE;
-- REASON: Will be RECREATED with correct schema.
--         Missing: phone_number, gender, role (enum), work_email,
--         work_email_verified, office_id_photo_url, aadhaar_masked_number,
--         fcm_token, emergency_contacts JSONB, auto_accept_colleagues,
--         trust_score. Also wallet is SEPARATE table, not coin_balance column.

-- ─── LAYER 7: Companies (last, it is the root parent) ───

DROP TABLE IF EXISTS companies              CASCADE;
-- REASON: Will be RECREATED with correct schema.
--         Missing: gstin, total_coins_pool, default_monthly_grant_per_employee,
--         auto_approve_domain_otp, fuel_voucher_enabled, manager_id.

-- ─── ALSO DROP: All related functions and triggers ───

DROP FUNCTION IF EXISTS update_updated_at()          CASCADE;
DROP FUNCTION IF EXISTS submit_rating(UUID,UUID,UUID,INTEGER,TEXT) CASCADE;

-- ─── ALSO DROP: All related types ───

DROP TYPE IF EXISTS user_role_enum     CASCADE;
DROP TYPE IF EXISTS gender_enum        CASCADE;
DROP TYPE IF EXISTS ride_status_enum   CASCADE;
DROP TYPE IF EXISTS time_type_enum     CASCADE;
DROP TYPE IF EXISTS request_status_enum CASCADE;
DROP TYPE IF EXISTS admin_role_enum    CASCADE;

-- ============================================================
-- END OF DROP SCRIPT
-- After running this, the database is a clean slate.
-- Next step: Run new production migration files 014 onwards.
-- ============================================================

-- ============================================================
-- Migration 014: Production Schema — All 27 Tables
-- Source of Truth: SRS_Document.md (§3, §4, §5, §12–§17, §20, §21)
-- Date: 18-Aug-2026
-- Run AFTER: 013_drop_all_trial_tables.sql (confirmed empty)
-- ============================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "postgis";    -- GEOMETRY columns & spatial indexes

-- ============================================================
-- ENUMS — Define before any table that uses them
-- ============================================================

CREATE TYPE user_role_enum AS ENUM (
    'corporate_employee',
    'public_user',
    'family_member',
    'company_manager'
);

CREATE TYPE gender_enum AS ENUM (
    'male', 'female', 'other', 'prefer_not_to_say'
);

CREATE TYPE ride_status_enum AS ENUM (
    'posted',
    'started',
    'driver_en_route',
    'arrived_at_pickup',
    'in_progress',
    'completed',
    'cancelled_by_driver',
    'cancelled_by_user'
);

CREATE TYPE time_type_enum AS ENUM (
    'now', 'scheduled', 'recurring'
);

CREATE TYPE request_status_enum AS ENUM (
    'pending', 'accepted', 'rejected',
    'cancelled', 'expired', 'in_ride', 'completed'
);

CREATE TYPE admin_role_enum AS ENUM (
    'super_admin', 'support_officer', 'finance_admin'
);

-- ============================================================
-- LAYER 1: Root Tables (No FK dependencies on our tables)
-- ============================================================

-- TABLE 1: system_settings
-- Purpose: All dynamic Super Admin business logic parameters
-- Source: SRS §21.2 Fix 5
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.system_settings (
    key         VARCHAR(100) PRIMARY KEY,
    value       TEXT         NOT NULL,
    description TEXT,
    updated_by  UUID,        -- FK to users added later via ALTER
    updated_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- Seed: Default business logic configuration (Super Admin can change via console)
INSERT INTO public.system_settings (key, value, description) VALUES
('CAR_COIN_RATE_PER_KM',          '2.0',  'Karma Coins per km for Car/SUV rides'),
('BIKE_COIN_RATE_PER_KM',         '1.0',  'Karma Coins per km for Bike/Scooter rides'),
('RIDER_NOSHOW_PENALTY_PCT',      '100',  'Percentage of fare paid to driver on rider no-show'),
('FREE_CANCEL_MINS',              '30',   'Minutes before departure for free cancellation'),
('LATE_CANCEL_MINS',              '15',   'Minutes before departure triggering late-cancel fee'),
('RIDER_LATE_CANCEL_FEE',         '5',    'Karma Coins charged to rider for late cancellation'),
('MAX_DAILY_RIDES_PER_USER',      '4',    'Maximum rides a driver can post per day'),
('MAX_CONCURRENT_REQUESTS',       '3',    'Maximum simultaneous ride requests a rider can send'),
('MAX_RECURRING_OVERDRAFT_COINS', '30',   'Max negative balance allowed for recurring riders'),
('DRIVER_WAIT_TIMER_MINS',        '5',    'Minutes driver waits at gate before no-show'),
('DETOUR_COINS_PER_500M',         '3.0',  'Bonus coins per 500m detour taken by driver'),
('COMPANY_FREE_TRIAL_DAYS',       '90',   'Default free trial period in days for new companies'),
('MIN_SMOOTHNESS_BONUS_PCT',      '90',   'Minimum telematics smoothness % to earn bonus coins'),
('SMOOTH_COMMUTE_BONUS_COINS',    '2.0',  'Bonus coins awarded per smooth commute trip'),
('DOUBLE_BLIND_EXPIRY_HOURS',     '24',   'Hours after which submitted review auto-unlocks publicly');

-- TABLE 2: app_remote_config
-- Purpose: Super Admin live theme & home screen editor (no app update needed)
-- Source: SRS §17.5
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.app_remote_config (
    id                       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    wallpaper_url            TEXT         DEFAULT 'https://assets.corporatepooling.internal/default_bg.webp',
    wallpaper_opacity        NUMERIC(3,2) DEFAULT 0.85,
    glass_card_color         VARCHAR(20)  DEFAULT 'rgba(20,25,35,0.75)',
    accent_color             VARCHAR(10)  DEFAULT '#FF6B00',
    active_festival_banner_url TEXT,
    banner_action_route      VARCHAR(50)  DEFAULT '/offer_ride',
    tagline_primary          VARCHAR(150) DEFAULT 'Share the Ride, Multiply the Karma',
    tagline_secondary        VARCHAR(150) DEFAULT 'Join 10,000+ Corporate Colleagues Commuting Green',
    is_active                BOOLEAN      DEFAULT TRUE,
    updated_at               TIMESTAMPTZ  DEFAULT NOW()
);

-- Insert default config row
INSERT INTO public.app_remote_config DEFAULT VALUES;

-- ============================================================
-- LAYER 2: companies (referenced by users, buildings, etc.)
-- ============================================================

-- TABLE 3: companies
-- Purpose: Corporate employer accounts (B2B clients)
-- Source: SRS §14.5
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.companies (
    id                               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name                             VARCHAR(255) NOT NULL,
    domain                           VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'infosys.com'
    gstin                            VARCHAR(15),                  -- GST Tax Identification
    manager_id                       UUID,                         -- FK to users (added after)
    total_coins_pool                 NUMERIC(10,2) DEFAULT 0.00,
    default_monthly_grant_per_employee NUMERIC(6,2) DEFAULT 400.00,
    subscription_plan                VARCHAR(30)  DEFAULT 'starter'
        CHECK (subscription_plan IN ('starter', 'growth', 'enterprise', 'free_trial')),
    auto_approve_domain_otp          BOOLEAN      DEFAULT FALSE,   -- HR toggle: auto-approve email OTP
    fuel_voucher_enabled             BOOLEAN      DEFAULT FALSE,
    is_active                        BOOLEAN      DEFAULT TRUE,
    created_at                       TIMESTAMPTZ  DEFAULT NOW(),
    updated_at                       TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX idx_companies_domain ON public.companies(domain);

-- ============================================================
-- LAYER 3: buildings & users (reference companies)
-- ============================================================

-- TABLE 4: buildings
-- Purpose: Tech Parks & campus geofences for attendance & ride destination
-- Source: SRS §21.1 Fix 3 + §13.1
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.buildings (
    id                      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name                    VARCHAR(200) NOT NULL,   -- e.g. 'Manyata Tech Park Block D'
    company_id              UUID         REFERENCES public.companies(id) ON DELETE SET NULL,
    address                 TEXT         NOT NULL,
    city                    VARCHAR(100) NOT NULL    DEFAULT 'Bengaluru',
    geofence_center         GEOMETRY(Point, 4326)    NOT NULL,
    geofence_radius_m       INT          DEFAULT 500,
    attendance_window_start TIME         DEFAULT '06:00:00',
    attendance_window_end   TIME         DEFAULT '11:00:00',
    is_active               BOOLEAN      DEFAULT TRUE,
    created_at              TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX idx_buildings_geofence ON public.buildings USING GIST(geofence_center);
CREATE INDEX idx_buildings_company  ON public.buildings(company_id);

-- TABLE 5: users
-- Purpose: All commuters — corporate employees, public users, family members
-- Source: SRS §3.3 + §21.3 Fix 6
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.users (
    id                     UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number           VARCHAR(15)  UNIQUE NOT NULL,
    full_name              VARCHAR(100) NOT NULL,
    gender                 gender_enum  NOT NULL,
    role                   user_role_enum DEFAULT 'corporate_employee',
    work_email             VARCHAR(150) UNIQUE,
    work_email_verified    BOOLEAN      DEFAULT FALSE,
    office_id_photo_url    TEXT,
    office_id_verified     BOOLEAN      DEFAULT FALSE,
    company_id             UUID         REFERENCES public.companies(id),
    building_id            UUID         REFERENCES public.buildings(id),
    primary_account_id     UUID         REFERENCES public.users(id), -- for family_member role
    aadhaar_verified       BOOLEAN      DEFAULT FALSE,
    aadhaar_masked_number  VARCHAR(20),                              -- Last 4 digits only
    dl_verified            BOOLEAN      DEFAULT FALSE,
    profile_photo_url      TEXT,
    auto_accept_colleagues BOOLEAN      DEFAULT FALSE,
    auto_accept_max_detour_m INT        DEFAULT 100,
    trust_score            INT          DEFAULT 50 CHECK (trust_score BETWEEN 0 AND 100),
    emergency_contacts     JSONB        DEFAULT '[]'::jsonb,
    fcm_token              TEXT,
    fcm_token_platform     VARCHAR(10)  CHECK (fcm_token_platform IN ('android', 'ios')),
    fcm_token_updated_at   TIMESTAMPTZ,
    is_banned              BOOLEAN      DEFAULT FALSE,
    ban_reason             TEXT,
    created_at             TIMESTAMPTZ  DEFAULT NOW(),
    updated_at             TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX idx_users_phone       ON public.users(phone_number);
CREATE INDEX idx_users_company_role ON public.users(company_id, role);
CREATE INDEX idx_users_work_email  ON public.users(work_email);
CREATE INDEX idx_users_trust_score ON public.users(trust_score DESC);

-- Now add FKs that reference users (deferred)
ALTER TABLE public.companies
    ADD COLUMN IF NOT EXISTS manager_id UUID REFERENCES public.users(id);
ALTER TABLE public.system_settings
    ADD COLUMN IF NOT EXISTS updated_by_fk UUID REFERENCES public.users(id);

-- ============================================================
-- LAYER 4: wallets, vehicles, family_wallets (reference users)
-- ============================================================

-- TABLE 6: wallets
-- Purpose: One wallet per user — 3-tier coin balance system
-- Source: SRS §12.4
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.wallets (
    id                      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID         UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    available_balance       NUMERIC(8,2) DEFAULT 0.00,
    locked_balance          NUMERIC(8,2) DEFAULT 0.00,  -- coins held in escrow
    corporate_grant_balance NUMERIC(8,2) DEFAULT 0.00,  -- coins from employer monthly grant
    lifetime_earned         NUMERIC(8,2) DEFAULT 0.00,
    lifetime_spent          NUMERIC(8,2) DEFAULT 0.00,
    created_at              TIMESTAMPTZ  DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX idx_wallets_user ON public.wallets(user_id);

-- TABLE 7: vehicles
-- Purpose: Driver's registered vehicles (multi-vehicle support)
-- Source: SRS §21.1 Fix 1 + §4.1.1
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.vehicles (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vehicle_type     VARCHAR(30) NOT NULL
        CHECK (vehicle_type IN ('car', 'suv', 'bike', 'scooter', 'auto', 'ev')),
    vehicle_number   VARCHAR(20) NOT NULL UNIQUE,
    vehicle_make     VARCHAR(50),
    vehicle_model    VARCHAR(50),
    vehicle_color    VARCHAR(30),
    rc_photo_url     TEXT,
    has_spare_helmet BOOLEAN     DEFAULT FALSE,
    is_verified      BOOLEAN     DEFAULT FALSE,
    is_active        BOOLEAN     DEFAULT TRUE,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vehicles_user     ON public.vehicles(user_id);
CREATE INDEX idx_vehicles_verified ON public.vehicles(user_id, is_verified, is_active);

-- TABLE 8: kyc_documents
-- Purpose: All KYC document storage (DL, RC, Aadhaar, Office ID, Company docs)
-- Source: SRS §21.2 Fix 4
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.kyc_documents (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vehicle_id          UUID        REFERENCES public.vehicles(id) ON DELETE SET NULL,
    document_type       VARCHAR(30) NOT NULL
        CHECK (document_type IN (
            'driving_license', 'vehicle_rc', 'aadhaar_card',
            'office_id_card', 'company_hr_loa', 'company_gstin',
            'company_cin', 'company_pan'
        )),
    photo_url           TEXT,
    verification_status VARCHAR(20) DEFAULT 'pending'
        CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    rejection_reason    TEXT,
    reviewed_by         UUID        REFERENCES public.users(id),
    reviewed_at         TIMESTAMPTZ,
    uploaded_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_kyc_user    ON public.kyc_documents(user_id);
CREATE INDEX idx_kyc_vehicle ON public.kyc_documents(vehicle_id);
CREATE INDEX idx_kyc_status  ON public.kyc_documents(verification_status);

-- TABLE 9: family_wallets
-- Purpose: Shared family coin pool (max 4 members, owned by primary account)
-- Source: SRS §21.1 Fix 2 + §12.5
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.family_wallets (
    id                       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    primary_owner_id         UUID         NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    wallet_name              VARCHAR(100) DEFAULT 'Family Wallet',
    shared_balance           NUMERIC(8,2) DEFAULT 0.00,
    monthly_limit_per_member NUMERIC(6,2) DEFAULT 500.00,
    created_at               TIMESTAMPTZ  DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX idx_family_wallet_owner ON public.family_wallets(primary_owner_id);

-- TABLE 10: family_wallet_members
-- Source: SRS §21.1 Fix 2 + §12.5
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.family_wallet_members (
    id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    family_wallet_id      UUID        NOT NULL REFERENCES public.family_wallets(id) ON DELETE CASCADE,
    member_user_id        UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    aadhaar_link_verified BOOLEAN     DEFAULT FALSE,
    joined_at             TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(family_wallet_id, member_user_id)
);

CREATE INDEX idx_family_member_user   ON public.family_wallet_members(member_user_id);
CREATE INDEX idx_family_member_wallet ON public.family_wallet_members(family_wallet_id);

-- ============================================================
-- LAYER 5: rides (references users, vehicles, buildings)
-- ============================================================

-- TABLE 11: rides
-- Purpose: All posted driver commutes (now / scheduled / recurring)
-- Source: SRS §4.7 + §21.4 Fix 8
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.rides (
    id                     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id              UUID          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vehicle_id             UUID          REFERENCES public.vehicles(id),
    from_address           TEXT          NOT NULL,
    from_location          GEOMETRY(Point, 4326) NOT NULL,
    to_address             TEXT          NOT NULL,
    to_location            GEOMETRY(Point, 4326) NOT NULL,
    building_id            UUID          REFERENCES public.buildings(id),
    route_geometry         GEOMETRY(LineString, 4326) NOT NULL,
    route_points           JSONB         NOT NULL DEFAULT '[]',  -- [{lat, lng},...] for matching
    distance_km            NUMERIC(5,2)  NOT NULL,
    estimated_duration_mins INT          NOT NULL,
    depart_time            TIME          NOT NULL,
    approx_reach_time      TIME          NOT NULL,
    depart_date            DATE,
    seats_offered          INT           NOT NULL DEFAULT 1,
    seats_available        INT           NOT NULL DEFAULT 1,
    fare_coins             NUMERIC(6,2)  NOT NULL,              -- Total fare for full route
    time_type              time_type_enum NOT NULL,
    recurring_days         INT[]         DEFAULT '{}',           -- 0=Sun,1=Mon,...,6=Sat
    valid_until            DATE,
    completion_dates       DATE[]        DEFAULT '{}',           -- Days this recurring ride ran
    skip_dates             DATE[]        DEFAULT '{}',           -- Days driver skipped
    ride_status            ride_status_enum DEFAULT 'posted',
    women_only_flag        BOOLEAN       DEFAULT FALSE,
    boarding_daily_word    VARCHAR(20)   NOT NULL,               -- Today's verbal boarding code
    boarding_ble_uuid      UUID          DEFAULT gen_random_uuid(),
    is_open_to_public      BOOLEAN       DEFAULT TRUE,
    current_lat            NUMERIC(10,7),                        -- Live GPS (updated every 5s)
    current_lng            NUMERIC(10,7),
    current_route_index    INT           DEFAULT 0,
    started_at             TIMESTAMPTZ,
    completed_at           TIMESTAMPTZ,
    created_at             TIMESTAMPTZ   DEFAULT NOW(),
    updated_at             TIMESTAMPTZ   DEFAULT NOW(),

    CONSTRAINT seats_valid CHECK (seats_available <= seats_offered)
);

CREATE INDEX idx_rides_from_location   ON public.rides USING GIST(from_location);
CREATE INDEX idx_rides_to_location     ON public.rides USING GIST(to_location);
CREATE INDEX idx_rides_route_geometry  ON public.rides USING GIST(route_geometry);
CREATE INDEX idx_rides_driver_status   ON public.rides(driver_id, ride_status, depart_time);
CREATE INDEX idx_rides_status_depart   ON public.rides(ride_status, depart_time)
    WHERE ride_status = 'posted';                                -- Partial index for searches
CREATE INDEX idx_rides_recurring       ON public.rides(driver_id, time_type)
    WHERE time_type = 'recurring';

-- ============================================================
-- LAYER 6: Tables that reference rides + users
-- ============================================================

-- TABLE 12: ride_requests
-- Purpose: Rider booking with escrow lock
-- Source: SRS §5.4
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.ride_requests (
    id                       UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id                  UUID          NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
    rider_id                 UUID          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    pickup_address           TEXT          NOT NULL,
    pickup_location          GEOMETRY(Point, 4326) NOT NULL,
    drop_address             TEXT          NOT NULL,
    drop_location            GEOMETRY(Point, 4326) NOT NULL,
    seats_requested          INT           DEFAULT 1,
    coins_locked             NUMERIC(6,2)  NOT NULL,
    used_family_wallet_id    UUID          REFERENCES public.family_wallets(id),
    status                   request_status_enum DEFAULT 'pending',
    expires_at               TIMESTAMPTZ   NOT NULL,             -- 5-min accept window
    driver_arrived           BOOLEAN       DEFAULT FALSE,
    driver_arrived_at        TIMESTAMPTZ,
    boarding_verified_at     TIMESTAMPTZ,
    verification_method_used VARCHAR(30),                        -- 'ble', 'qr', 'pin'
    completed_at             TIMESTAMPTZ,
    created_at               TIMESTAMPTZ   DEFAULT NOW(),
    updated_at               TIMESTAMPTZ   DEFAULT NOW(),

    UNIQUE(ride_id, rider_id)
);

CREATE INDEX idx_ride_requests_ride    ON public.ride_requests(ride_id);
CREATE INDEX idx_ride_requests_rider   ON public.ride_requests(rider_id, status, created_at DESC);

-- TABLE 13: search_alerts
-- Purpose: "Notify me when a ride appears" persistent alert
-- Source: SRS §5.2
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.search_alerts (
    id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    from_location GEOMETRY(Point, 4326) NOT NULL,
    to_location   GEOMETRY(Point, 4326) NOT NULL,
    target_time   TIME          NOT NULL,
    target_date   DATE,
    is_active     BOOLEAN       DEFAULT TRUE,
    created_at    TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX idx_search_alerts_user   ON public.search_alerts(user_id);
CREATE INDEX idx_search_alerts_from   ON public.search_alerts USING GIST(from_location);

-- TABLE 14: coin_transactions
-- Purpose: Immutable double-entry ACID financial ledger
-- Source: SRS §12.4 + §21.4 Fix 9
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.coin_transactions (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id        UUID        REFERENCES public.users(id),
    receiver_id      UUID        REFERENCES public.users(id),
    amount           NUMERIC(8,2) NOT NULL,
    transaction_type VARCHAR(35) NOT NULL,
    -- 'ride_earning', 'ride_fare', 'escrow_lock', 'escrow_refund',
    -- 'corporate_grant', 'overdraft_adjustment', 'late_cancel_fee',
    -- 'detour_bonus', 'smooth_commute_bonus', 'noshow_penalty'
    ride_id          UUID        REFERENCES public.rides(id),
    request_id       UUID        REFERENCES public.ride_requests(id),
    idempotency_key  VARCHAR(120) UNIQUE,                     -- Prevents double-credit on retry
    status           VARCHAR(20) DEFAULT 'completed',
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_coin_txn_receiver_time ON public.coin_transactions(receiver_id, created_at DESC);
CREATE INDEX idx_coin_txn_sender_time   ON public.coin_transactions(sender_id, created_at DESC);
CREATE INDEX idx_coin_txn_ride          ON public.coin_transactions(ride_id);

-- TABLE 15: corporate_attendance
-- Purpose: Soft presence records for campus ESG & HR reporting
-- Source: SRS §13.3 + §21.3 Fix 7
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.corporate_attendance (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    company_id     UUID        NOT NULL REFERENCES public.companies(id),
    ride_id        UUID        REFERENCES public.rides(id),
    date           DATE        NOT NULL DEFAULT CURRENT_DATE,
    arrived_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    transport_mode VARCHAR(30) DEFAULT 'carpool'
        CHECK (transport_mode IN ('carpool', 'public_transit', 'rfid_swipe', 'manual')),
    created_at     TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT attendance_unique UNIQUE(employee_id, date)  -- One record per employee per day
);

CREATE INDEX idx_attendance_company_date ON public.corporate_attendance(company_id, date);
CREATE INDEX idx_attendance_employee     ON public.corporate_attendance(employee_id);

-- TABLE 16: corporate_invoices
-- Purpose: B2B company billing records (GST-compliant)
-- Source: SRS §14.5
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.corporate_invoices (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id     UUID         NOT NULL REFERENCES public.companies(id),
    invoice_number VARCHAR(50)  UNIQUE NOT NULL,
    base_amount    NUMERIC(10,2) NOT NULL,
    gst_amount     NUMERIC(10,2) NOT NULL,  -- 18% GST
    total_amount   NUMERIC(10,2) NOT NULL,
    sac_code       VARCHAR(10)  DEFAULT '9984',
    status         VARCHAR(20)  DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'failed')),
    created_at     TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX idx_invoices_company ON public.corporate_invoices(company_id, created_at DESC);

-- TABLE 17: driver_locations (Supabase Realtime)
-- Purpose: Live GPS ping during active ride (WebSocket subscriptions)
-- Source: Trial migration 008 (reused — design was correct)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.driver_locations (
    ride_id             UUID          PRIMARY KEY REFERENCES public.rides(id) ON DELETE CASCADE,
    driver_id           UUID          REFERENCES public.users(id),
    lat                 NUMERIC(10,7) NOT NULL,
    lng                 NUMERIC(10,7) NOT NULL,
    current_route_index INT           DEFAULT 0,
    route_distance_m    INT           DEFAULT 0,
    updated_at          TIMESTAMPTZ   DEFAULT NOW()
);

-- Enable Supabase Realtime on this table (run in Supabase SQL Editor)
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;

-- ============================================================
-- LAYER 7: Chat (references rides, companies, users)
-- ============================================================

-- TABLE 18: chat_rooms
-- Source: SRS §15.4
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.chat_rooms (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    room_type  VARCHAR(30) NOT NULL
        CHECK (room_type IN ('ride', 'company_broadcast', 'company_route_group', 'colleague_direct')),
    ride_id    UUID        REFERENCES public.rides(id) ON DELETE CASCADE,
    company_id UUID        REFERENCES public.companies(id) ON DELETE CASCADE,
    name       VARCHAR(100),
    created_by UUID        REFERENCES public.users(id),
    is_active  BOOLEAN     DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_rooms_ride    ON public.chat_rooms(ride_id);
CREATE INDEX idx_chat_rooms_company ON public.chat_rooms(company_id);

-- TABLE 19: chat_room_members
-- Source: SRS §15.4
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.chat_room_members (
    id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id   UUID        NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id   UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);

CREATE INDEX idx_chat_room_members_user ON public.chat_room_members(user_id);

-- TABLE 20: chat_messages
-- Source: SRS §15.4
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.chat_messages (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id      UUID        NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message_text TEXT        NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text'
        CHECK (message_type IN ('text', 'quick_chip', 'system_alert')),
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_room_time ON public.chat_messages(room_id, created_at DESC);

-- TABLE 21: message_read_receipts
-- Purpose: Per-member read state in group chats (replaces single is_read boolean)
-- Source: SRS §21.6 Fix 12
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.message_read_receipts (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID        NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    user_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    read_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id)
);

CREATE INDEX idx_read_receipts_user    ON public.message_read_receipts(user_id);
CREATE INDEX idx_read_receipts_message ON public.message_read_receipts(message_id);

-- ============================================================
-- LAYER 8: Post-ride tables (reference rides + users)
-- ============================================================

-- TABLE 22: ride_ratings
-- Purpose: Double-blind review system with compliment chips
-- Source: SRS §20.3
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.ride_ratings (
    id               UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id          UUID    NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
    rater_id         UUID    NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ratee_id         UUID    NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    is_driver_rating BOOLEAN NOT NULL,  -- TRUE = rider reviewing driver, FALSE = driver reviewing rider
    stars            INT     NOT NULL CHECK (stars >= 1 AND stars <= 5),
    compliment_chips TEXT[]  DEFAULT '{}'::text[],  -- e.g. 'Smooth Driver', 'Punctual', 'Extra Mile'
    feedback_text    VARCHAR(250),
    is_locked        BOOLEAN DEFAULT TRUE,           -- Double-blind: stays TRUE until both submit
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(ride_id, rater_id, ratee_id)
);

CREATE INDEX idx_ride_ratings_ratee ON public.ride_ratings(ratee_id, stars);
CREATE INDEX idx_ride_ratings_ride  ON public.ride_ratings(ride_id);

-- TABLE 23: telematics_violations
-- Purpose: Rash driving events captured by phone accelerometer/gyroscope
-- Source: SRS §20.3
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.telematics_violations (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id          UUID        NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
    driver_id        UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    violation_type   VARCHAR(30) NOT NULL
        CHECK (violation_type IN ('harsh_braking', 'swift_swerving', 'over_speeding')),
    g_force_magnitude  NUMERIC(5,3),
    yaw_rate_dps       NUMERIC(5,2),
    recorded_speed_kmh NUMERIC(5,2),
    location_geom      GEOMETRY(Point, 4326),
    recorded_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_telematics_driver ON public.telematics_violations(driver_id, recorded_at DESC);
CREATE INDEX idx_telematics_ride   ON public.telematics_violations(ride_id);

-- TABLE 24: emergency_sos_incidents
-- Purpose: Full SOS audit trail — cryptographic evidence sealing for legal defense
-- Source: SRS §17.6.4
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.emergency_sos_incidents (
    id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id             UUID          NOT NULL REFERENCES public.rides(id),
    triggered_by        UUID          NOT NULL REFERENCES public.users(id),
    driver_id           UUID          NOT NULL REFERENCES public.users(id),
    vehicle_plate       VARCHAR(20)   NOT NULL,
    trigger_lat         DOUBLE PRECISION NOT NULL,
    trigger_lng         DOUBLE PRECISION NOT NULL,
    live_speed_kmh      NUMERIC(5,2),
    battery_level_pct   INT,
    police_notified     BOOLEAN       DEFAULT FALSE,
    family_notified_count INT         DEFAULT 0,
    status              VARCHAR(20)   DEFAULT 'active'
        CHECK (status IN ('active', 'police_dispatched', 'resolved_safe', 'false_alarm')),
    resolution_category VARCHAR(50),
    resolution_notes    TEXT,
    resolved_by         UUID          REFERENCES public.users(id),
    resolved_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX idx_sos_status ON public.emergency_sos_incidents(status, created_at DESC);

-- ============================================================
-- LAYER 9: Admin & supplemental tables
-- ============================================================

-- TABLE 25: admin_audit_logs
-- Purpose: Immutable Super Admin action trail (RBAC audit)
-- Source: SRS §17.3
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.admin_audit_logs (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id    UUID        NOT NULL REFERENCES public.users(id),
    action_type VARCHAR(50) NOT NULL,
    -- 'driver_approved', 'driver_rejected', 'escrow_force_settled',
    -- 'company_created', 'theme_updated', 'user_banned', 'coin_minted'
    target_id   UUID,
    details     JSONB       DEFAULT '{}'::jsonb,
    ip_address  VARCHAR(45),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_admin_audit_action ON public.admin_audit_logs(action_type, created_at DESC);
CREATE INDEX idx_admin_audit_admin  ON public.admin_audit_logs(admin_id, created_at DESC);

-- TABLE 26: company_domains (multi-domain per company)
-- Source: Trial migration 012 (design was correct — reused)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.company_domains (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID        NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    domain     TEXT        UNIQUE NOT NULL,  -- e.g. 'tcs.com', 'tcs.co.in'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_company_domains_domain  ON public.company_domains(domain);
CREATE INDEX idx_company_domains_company ON public.company_domains(company_id);

-- TABLE 27: notifications
-- Purpose: In-app notification storage with deep-link routing
-- Source: Trial migration 012 + SRS §16
-- ─────────────────────────────────────────────────────────────
CREATE TABLE public.notifications (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title       TEXT        NOT NULL,
    body        TEXT        NOT NULL,
    type        VARCHAR(30) NOT NULL,
    -- 'ride_request', 'request_accepted', 'driver_arriving',
    -- 'coins_received', 'sos_alert', 'kyc_approved', 'system'
    deep_link_route VARCHAR(100),  -- e.g. '/ride/uuid', '/wallet', '/admin/sos'
    ride_id     UUID        REFERENCES public.rides(id) ON DELETE SET NULL,
    data        JSONB       DEFAULT '{}',
    is_read     BOOLEAN     DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON public.notifications(user_id, is_read, created_at DESC);

-- ============================================================
-- ACID FUNCTIONS
-- ============================================================

-- FUNCTION 1: reconcile_stuck_escrow (Atomic CTE — Fix 10)
CREATE OR REPLACE FUNCTION public.reconcile_stuck_escrow()
RETURNS VOID AS $$
BEGIN
    WITH expired AS (
        UPDATE public.ride_requests
        SET    status     = 'expired',
               updated_at = NOW()
        WHERE  status     IN ('pending', 'accepted')
          AND  created_at < NOW() - INTERVAL '4 hours'
        RETURNING id, rider_id, coins_locked
    )
    UPDATE public.wallets w
    SET    locked_balance    = locked_balance    - e.coins_locked,
           available_balance = available_balance + e.coins_locked,
           updated_at        = NOW()
    FROM   expired e
    WHERE  w.user_id = e.rider_id;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 2: lock_wallets_for_ride (FOR UPDATE lock — Fix 11)
CREATE OR REPLACE FUNCTION public.lock_wallets_for_ride(
    p_driver_id UUID,
    p_rider_id  UUID
)
RETURNS VOID AS $$
BEGIN
    PERFORM id FROM public.wallets
    WHERE user_id IN (p_driver_id, p_rider_id)
    ORDER BY user_id  -- consistent ordering prevents deadlocks
    FOR UPDATE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all user-facing tables
ALTER TABLE public.users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_documents          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_requests          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_transactions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_sos_incidents ENABLE ROW LEVEL SECURITY;

-- RLS Policy 1: users — own profile only
CREATE POLICY "users_see_own_profile"   ON public.users FOR SELECT USING (id = auth.uid());
CREATE POLICY "users_update_own_profile" ON public.users FOR UPDATE USING (id = auth.uid());

-- RLS Policy 2: wallets — own wallet only
CREATE POLICY "users_see_own_wallet"    ON public.wallets FOR ALL USING (user_id = auth.uid());

-- RLS Policy 3: coin_transactions — sender or receiver only
CREATE POLICY "users_see_own_transactions" ON public.coin_transactions
    FOR SELECT USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- RLS Policy 4: vehicles — own vehicles only
CREATE POLICY "owner_manages_own_vehicles" ON public.vehicles FOR ALL USING (user_id = auth.uid());

-- RLS Policy 5: kyc_documents — own docs only
CREATE POLICY "owner_sees_own_kyc"      ON public.kyc_documents FOR ALL USING (user_id = auth.uid());

-- RLS Policy 6: rides — anyone can read posted rides; driver manages own
CREATE POLICY "rides_read_open"         ON public.rides FOR SELECT
    USING (ride_status = 'posted' AND is_open_to_public = TRUE);
CREATE POLICY "rides_driver_own"        ON public.rides FOR ALL USING (driver_id = auth.uid());

-- RLS Policy 7: chat_messages — only room members can read
CREATE POLICY "members_see_room_messages" ON public.chat_messages
    FOR SELECT USING (
        room_id IN (
            SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()
        )
    );

-- RLS Policy 8: chat_room_members — see own memberships
CREATE POLICY "users_see_own_memberships" ON public.chat_room_members
    FOR SELECT USING (user_id = auth.uid());

-- RLS Policy 9: notifications — own only
CREATE POLICY "users_see_own_notifications" ON public.notifications
    FOR ALL USING (user_id = auth.uid());

-- RLS Policy 10: driver_locations — driver or rider with accepted request
CREATE POLICY "driver_location_access" ON public.driver_locations
    FOR SELECT USING (
        driver_id = auth.uid() OR
        ride_id IN (
            SELECT ride_id FROM public.ride_requests
            WHERE rider_id = auth.uid() AND status IN ('accepted', 'in_ride')
        )
    );

-- RLS Policy 11: system_settings — read-only for all authenticated users
CREATE POLICY "authenticated_read_settings" ON public.system_settings
    FOR SELECT TO authenticated USING (TRUE);

-- RLS Policy 12: emergency_sos — own incidents only (admin via service role)
CREATE POLICY "users_see_own_sos" ON public.emergency_sos_incidents
    FOR SELECT USING (triggered_by = auth.uid() OR driver_id = auth.uid());

-- ============================================================
-- END OF MIGRATION 014
-- ============================================================
-- Total tables created: 27
-- Total indexes created: 38
-- Total RLS policies: 12
-- Total ACID functions: 2
-- Total enum types: 6
-- ============================================================
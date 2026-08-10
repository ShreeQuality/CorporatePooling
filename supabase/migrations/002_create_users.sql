-- ============================================================
-- Migration 002: users
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id                    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name             TEXT NOT NULL,
  email                 TEXT UNIQUE NOT NULL,
  phone                 TEXT,
  photo_url             TEXT,
  user_type             TEXT CHECK(user_type IN ('corporate','public')) NOT NULL DEFAULT 'public',
  company_id            UUID REFERENCES companies(id) ON DELETE SET NULL,
  is_email_verified     BOOLEAN DEFAULT FALSE,
  is_document_verified  BOOLEAN DEFAULT FALSE,  -- Aadhaar + photo approved (public users)
  is_driver_verified    BOOLEAN DEFAULT FALSE,  -- Driving licence approved
  aadhaar_url           TEXT,
  driving_licence_url   TEXT,
  coin_balance          INTEGER DEFAULT 0 CHECK(coin_balance >= 0),
  total_coins_earned    INTEGER DEFAULT 0,
  total_rides_given     INTEGER DEFAULT 0,
  total_rides_taken     INTEGER DEFAULT 0,
  karma_score           NUMERIC(3,2) DEFAULT 5.00 CHECK(karma_score BETWEEN 0 AND 5),
  is_active             BOOLEAN DEFAULT TRUE,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_company_id ON users(company_id);
CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type);

DROP TRIGGER IF EXISTS users_updated_at ON users;
CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─── OTP Verifications ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS otp_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       TEXT NOT NULL,
  otp         TEXT NOT NULL,
  purpose     TEXT NOT NULL,   -- 'registration', 'login', 'reset'
  expires_at  TIMESTAMPTZ NOT NULL,
  used        BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(email, purpose)
);

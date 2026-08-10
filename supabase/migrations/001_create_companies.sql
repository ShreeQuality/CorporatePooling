-- ============================================================
-- Migration 001: companies
-- ============================================================

CREATE TABLE IF NOT EXISTS companies (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT NOT NULL,
  email_domain        TEXT UNIQUE,           -- e.g. 'tcs.com' (nullable for future)
  subscription_status TEXT CHECK(subscription_status IN ('trial','active','expired')) DEFAULT 'trial',
  trial_started_at    TIMESTAMPTZ DEFAULT NOW(),
  trial_ends_at       TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '90 days'),
  plan                TEXT DEFAULT 'free_trial',
  max_employees       INTEGER DEFAULT 100,
  is_active           BOOLEAN DEFAULT TRUE,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS companies_updated_at ON companies;
CREATE TRIGGER companies_updated_at
  BEFORE UPDATE ON companies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

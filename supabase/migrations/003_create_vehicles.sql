-- ============================================================
-- Migration 003: vehicles
-- ============================================================

CREATE TABLE IF NOT EXISTS vehicles (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type                TEXT NOT NULL,    -- 'Bike','Scooter','Auto','Car','Sedan','SUV'
  registration_number TEXT NOT NULL,
  model               TEXT,
  color               TEXT,
  capacity            INTEGER NOT NULL DEFAULT 2,
  is_verified         BOOLEAN DEFAULT FALSE,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON vehicles(user_id);

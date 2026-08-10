-- ============================================================
-- Migration 004: rides
-- ============================================================

CREATE TABLE IF NOT EXISTS rides (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id               UUID NOT NULL REFERENCES users(id),
  vehicle_id              UUID REFERENCES vehicles(id),
  from_address            TEXT NOT NULL,
  from_lat                NUMERIC(10,7) NOT NULL,
  from_lng                NUMERIC(10,7) NOT NULL,
  to_address              TEXT NOT NULL,
  to_lat                  NUMERIC(10,7) NOT NULL,
  to_lng                  NUMERIC(10,7) NOT NULL,
  route_points            JSONB NOT NULL DEFAULT '[]',    -- [{lat, lng}, ...] from Google Directions
  total_seats             INTEGER NOT NULL CHECK(total_seats > 0),
  available_seats         INTEGER NOT NULL CHECK(available_seats >= 0),
  coin_per_seat           INTEGER NOT NULL CHECK(coin_per_seat >= 0),
  time_type               TEXT CHECK(time_type IN ('now','scheduled','recurring')) NOT NULL DEFAULT 'now',
  depart_time             TEXT,            -- '8:00 AM' string (for display)
  depart_timestamp        TIMESTAMPTZ,     -- exact departure datetime
  recurring_days          TEXT[],          -- ['mon','tue','wed','thu','fri']
  valid_until             TIMESTAMPTZ,     -- for recurring rides
  ride_status             TEXT CHECK(ride_status IN (
                            'posted','started','in_progress','waiting_otp',
                            'awaiting_rider_confirm','awaiting_driver_confirm',
                            'completed','cancelled'
                          )) DEFAULT 'posted',
  -- Live GPS (updated every 5s when ride is active)
  current_lat             NUMERIC(10,7),
  current_lng             NUMERIC(10,7),
  current_route_index     INTEGER DEFAULT 0,
  -- Stats
  distance_km             NUMERIC(8,2),
  estimated_duration_mins INTEGER,
  actual_duration_mins    INTEGER,
  -- Timestamps
  started_at              TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  is_open_to_public       BOOLEAN DEFAULT TRUE,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT seats_valid CHECK(available_seats <= total_seats)
);

CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(ride_status);
CREATE INDEX IF NOT EXISTS idx_rides_depart_timestamp ON rides(depart_timestamp);
CREATE INDEX IF NOT EXISTS idx_rides_from_location ON rides(from_lat, from_lng);

DROP TRIGGER IF EXISTS rides_updated_at ON rides;
CREATE TRIGGER rides_updated_at
  BEFORE UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

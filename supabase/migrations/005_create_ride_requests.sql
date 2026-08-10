-- ============================================================
-- Migration 005: ride_requests
-- ============================================================

CREATE TABLE IF NOT EXISTS ride_requests (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id                 UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  rider_id                UUID NOT NULL REFERENCES users(id),
  pickup_address          TEXT NOT NULL,
  pickup_lat              NUMERIC(10,7) NOT NULL,
  pickup_lng              NUMERIC(10,7) NOT NULL,
  drop_address            TEXT NOT NULL,
  drop_lat                NUMERIC(10,7) NOT NULL,
  drop_lng                NUMERIC(10,7) NOT NULL,
  pickup_route_index      INTEGER,         -- index in ride.route_points where pickup falls
  drop_route_index        INTEGER,
  pickup_distance_m       INTEGER,         -- meters from pickup to nearest route point
  status                  TEXT CHECK(status IN (
                            'pending','accepted','rejected','cancelled','completed'
                          )) DEFAULT 'pending',
  coins_locked            INTEGER DEFAULT 0 CHECK(coins_locked >= 0),
  otp                     TEXT NOT NULL,   -- 4-digit pickup OTP
  otp_verified            BOOLEAN DEFAULT FALSE,
  -- Mutual arrival confirmation (mirrors KarmaRide pattern)
  awaiting_confirm        BOOLEAN DEFAULT FALSE,   -- driver signaled arrival
  rider_marked_arrival    BOOLEAN DEFAULT FALSE,   -- rider signaled arrival
  driver_marked_arrival_at TIMESTAMPTZ,
  rider_marked_arrival_at  TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ride_id, rider_id)
);

CREATE INDEX IF NOT EXISTS idx_ride_requests_ride_id ON ride_requests(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_rider_id ON ride_requests(rider_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_status ON ride_requests(status);

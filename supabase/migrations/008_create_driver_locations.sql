-- ============================================================
-- Migration 008: driver_locations (Supabase Realtime)
-- Same pattern as KarmaRide Firebase RTDB /ride_locations/{rideId}
-- Flutter app subscribes via WebSocket — updates every 5 seconds
-- ============================================================

CREATE TABLE IF NOT EXISTS driver_locations (
  ride_id             UUID PRIMARY KEY REFERENCES rides(id) ON DELETE CASCADE,
  driver_id           UUID REFERENCES users(id),
  lat                 NUMERIC(10,7) NOT NULL,
  lng                 NUMERIC(10,7) NOT NULL,
  current_route_index INTEGER DEFAULT 0,
  route_distance_m    INTEGER DEFAULT 0,
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Supabase Realtime on this table
-- Run this in Supabase SQL Editor after creating the table:
ALTER PUBLICATION supabase_realtime ADD TABLE driver_locations;

-- Flutter SDK usage:
-- supabase.channel('driver-$rideId')
--   .onPostgresChanges(event: PostgresChangeEvent.update, table: 'driver_locations',
--     filter: PostgresChangeFilter(type: FilterType.eq, column: 'ride_id', value: rideId),
--     callback: (payload) { ... update map marker ... })
--   .subscribe();

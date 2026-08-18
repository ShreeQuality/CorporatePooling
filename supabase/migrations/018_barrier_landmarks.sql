-- ============================================================
-- Migration 018: Barrier Landmarks & Smart Pickup Assistance
-- Source of Truth: SRS_Document.md (§5.1.1 Physical Barrier Handling)
-- Date: 18-Aug-2026
-- Run AFTER: 017_pg_cron_schedules.sql
-- ============================================================

-- 1. Extend buildings table to identify barrier landmarks
ALTER TABLE public.buildings
    ADD COLUMN IF NOT EXISTS is_barrier_location BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS barrier_type VARCHAR(30)
        CHECK (barrier_type IN ('railway', 'highway', 'river', 'compound_wall', 'toll_gate', NULL)),
    ADD COLUMN IF NOT EXISTS suggested_pickup_note TEXT;

-- 2. Partial index for lightning-fast barrier proximity lookups
CREATE INDEX IF NOT EXISTS idx_buildings_barrier
    ON public.buildings USING GIST(geofence_center)
    WHERE is_barrier_location = TRUE;

-- 3. Seed: High-Traffic Barrier & Transit Pickup Spots (Bengaluru, Pune, Hyderabad)
INSERT INTO public.buildings (
    name, address, city, geofence_center, geofence_radius_m,
    is_barrier_location, barrier_type, suggested_pickup_note
) VALUES
-- Bengaluru Hubs
(
    'Hebbal Railway Station - NH44 Gate',
    'Hebbal Flyover Junction, Outer Ring Road, Bengaluru',
    'Bengaluru',
    ST_GeomFromText('POINT(77.5937 13.0456)', 4326),
    400,
    TRUE,
    'railway',
    'Walk to NH-44 Service Road Bus Bay (avoid railway track crossing)'
),
(
    'Whitefield Railway Station - Main Road Exit',
    'Kadugodi Main Road, Whitefield, Bengaluru',
    'Bengaluru',
    ST_GeomFromText('POINT(77.7480 12.9698)', 4326),
    350,
    TRUE,
    'railway',
    'Walk to Whitefield Main Road Auto Stand (road-accessible side)'
),
(
    'KR Puram Railway Station - ORR Foot Overbridge',
    'Outer Ring Road, Tin Factory Junction, Bengaluru',
    'Bengaluru',
    ST_GeomFromText('POINT(77.6766 12.9961)', 4326),
    400,
    TRUE,
    'railway',
    'Use Foot Overbridge to Outer Ring Road Service Lane Gate'
),
(
    'Electronic City Toll Gate - Elevated Expressway Entry',
    'Hosur Road, Silk Board to E-City Junction, Bengaluru',
    'Bengaluru',
    ST_GeomFromText('POINT(77.6322 12.8452)', 4326),
    300,
    TRUE,
    'toll_gate',
    'Pick up at Service Road Entry before Elevated Flyover ramp'
),
-- Pune Hubs
(
    'Hinjewadi Phase 1 Main Circle - Wakad Bridge',
    'Hinjewadi IT Park Main Entry, Pune',
    'Pune',
    ST_GeomFromText('POINT(73.7431 18.5912)', 4326),
    350,
    TRUE,
    'highway',
    'Board at Service Road Drop Bay before Highway Underpass'
),
-- Hyderabad Hubs
(
    'Hitec City MMTS Railway Station - Cyber Towers Exit',
    'Hitec City Road, Madhapur, Hyderabad',
    'Hyderabad',
    ST_GeomFromText('POINT(78.3772 17.4435)', 4326),
    400,
    TRUE,
    'railway',
    'Exit via Platform 1 toward Cyber Towers Road for vehicle pickup'
)
ON CONFLICT DO NOTHING;

-- 4. RPC Helper: Find nearest barrier landmark suggestions for rider
CREATE OR REPLACE FUNCTION public.get_suggested_barrier_pickup(
    p_rider_lat DOUBLE PRECISION,
    p_rider_lng DOUBLE PRECISION,
    p_max_radius_m INT DEFAULT 500
)
RETURNS TABLE (
    landmark_id UUID,
    landmark_name VARCHAR(200),
    barrier_type VARCHAR(30),
    suggested_pickup_note TEXT,
    distance_meters DOUBLE PRECISION,
    pickup_lat DOUBLE PRECISION,
    pickup_lng DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id AS landmark_id,
        b.name AS landmark_name,
        b.barrier_type,
        b.suggested_pickup_note,
        ST_Distance(
            b.geofence_center::geography,
            ST_SetSRID(ST_MakePoint(p_rider_lng, p_rider_lat), 4326)::geography
        ) AS distance_meters,
        ST_Y(b.geofence_center::geometry) AS pickup_lat,
        ST_X(b.geofence_center::geometry) AS pickup_lng
    FROM public.buildings b
    WHERE b.is_barrier_location = TRUE
      AND b.is_active = TRUE
      AND ST_DWithin(
          b.geofence_center::geography,
          ST_SetSRID(ST_MakePoint(p_rider_lng, p_rider_lat), 4326)::geography,
          p_max_radius_m
      )
    ORDER BY distance_meters ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- END OF MIGRATION 018
-- ============================================================

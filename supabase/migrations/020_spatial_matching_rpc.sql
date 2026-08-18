-- ============================================================
-- Migration 020: Tier 1 PostGIS Spatial Candidate Matcher RPC
-- Source of Truth: SRS §6.1, §6.3 (2-Tier Funnel Architecture)
-- Date: 18-Aug-2026
-- Run AFTER: 019_peer_transfer_rpc.sql
-- ============================================================

-- Function: find_candidate_rides_spatial
-- Purpose: Tier 1 Database Pre-Filter.
--          Utilizes PostGIS GiST spatial index (idx_rides_from_location) to filter
--          99% of irrelevant rides within p_max_radius_m of the rider's pickup origin in < 5ms.
CREATE OR REPLACE FUNCTION public.find_candidate_rides_spatial(
    p_rider_id          UUID,
    p_pickup_lat        DOUBLE PRECISION,
    p_pickup_lng        DOUBLE PRECISION,
    p_drop_lat          DOUBLE PRECISION,
    p_drop_lng          DOUBLE PRECISION,
    p_seats_requested   INT DEFAULT 1,
    p_max_radius_m      INT DEFAULT 1500,
    p_time_type         VARCHAR(20) DEFAULT NULL,
    p_target_date       DATE DEFAULT NULL
)
RETURNS TABLE (
    ride_id                 UUID,
    driver_id               UUID,
    driver_name             VARCHAR(100),
    driver_phone            VARCHAR(15),
    driver_gender           gender_enum,
    driver_role             user_role_enum,
    driver_trust_score      INT,
    driver_company_id       UUID,
    driver_building_id      UUID,
    driver_company_name     VARCHAR(255),
    driver_photo_url        TEXT,
    vehicle_id              UUID,
    vehicle_type            VARCHAR(30),
    vehicle_model           VARCHAR(50),
    vehicle_number          VARCHAR(20),
    vehicle_color           VARCHAR(30),
    has_spare_helmet        BOOLEAN,
    from_address            TEXT,
    to_address              TEXT,
    seats_offered           INT,
    seats_available         INT,
    fare_coins              NUMERIC(6,2),
    time_type               time_type_enum,
    depart_date             DATE,
    depart_time             TIME,
    approx_reach_time       TIME,
    recurring_days          INT[],
    skip_dates              DATE[],
    route_points            JSONB,
    distance_km             NUMERIC(5,2),
    estimated_duration_mins INT,
    ride_status             ride_status_enum,
    women_only_flag         BOOLEAN,
    is_open_to_public       BOOLEAN,
    current_lat             NUMERIC(10,7),
    current_lng             NUMERIC(10,7),
    current_route_index     INT,
    pickup_dist_meters      DOUBLE PRECISION,
    drop_dist_meters        DOUBLE PRECISION
) AS $$
DECLARE
    v_rider_pickup GEOGRAPHY := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
    v_rider_drop   GEOGRAPHY := ST_SetSRID(ST_MakePoint(p_drop_lng, p_drop_lat), 4326)::geography;
    -- EXTRACT(DOW) matches 0=Sun, 1=Mon, ..., 6=Sat in public.rides.recurring_days
    v_target_day_dow INT := EXTRACT(DOW FROM COALESCE(p_target_date, CURRENT_DATE))::INT;
BEGIN
    RETURN QUERY
    SELECT 
        r.id AS ride_id,
        r.driver_id,
        u.full_name AS driver_name,
        u.phone_number AS driver_phone,
        u.gender AS driver_gender,
        u.role AS driver_role,
        u.trust_score AS driver_trust_score,
        u.company_id AS driver_company_id,
        u.building_id AS driver_building_id,
        c.name AS driver_company_name,
        u.profile_photo_url AS driver_photo_url,
        r.vehicle_id,
        v.vehicle_type,
        v.vehicle_model,
        v.vehicle_number,
        v.vehicle_color,
        COALESCE(v.has_spare_helmet, FALSE) AS has_spare_helmet,
        r.from_address,
        r.to_address,
        r.seats_offered,
        r.seats_available,
        r.fare_coins,
        r.time_type,
        r.depart_date,
        r.depart_time,
        r.approx_reach_time,
        r.recurring_days,
        r.skip_dates,
        r.route_points,
        r.distance_km,
        r.estimated_duration_mins,
        r.ride_status,
        r.women_only_flag,
        r.is_open_to_public,
        r.current_lat,
        r.current_lng,
        r.current_route_index,
        ST_Distance(r.from_location::geography, v_rider_pickup) AS pickup_dist_meters,
        ST_Distance(r.to_location::geography, v_rider_drop) AS drop_dist_meters
    FROM public.rides r
    JOIN public.users u ON r.driver_id = u.id
    LEFT JOIN public.vehicles v ON r.vehicle_id = v.id
    LEFT JOIN public.companies c ON u.company_id = c.id
    WHERE (p_rider_id IS NULL OR r.driver_id <> p_rider_id)
      AND r.seats_available >= COALESCE(p_seats_requested, 1)
      AND r.ride_status IN ('posted', 'started')
      -- PostGIS Spatial Radius Filter on Origin (Uses GiST index idx_rides_from_location)
      AND ST_DWithin(r.from_location::geography, v_rider_pickup, p_max_radius_m)
      -- Time type specific filter if requested
      AND (p_time_type IS NULL OR r.time_type::TEXT = p_time_type)
      -- Day / Date Compatibility
      AND (
          (r.time_type = 'recurring' 
           AND v_target_day_dow = ANY(r.recurring_days) 
           AND NOT (COALESCE(p_target_date, CURRENT_DATE) = ANY(r.skip_dates))
           AND (r.valid_until IS NULL OR r.valid_until >= COALESCE(p_target_date, CURRENT_DATE)))
          OR 
          (r.time_type = 'scheduled' 
           AND (p_target_date IS NULL OR r.depart_date = p_target_date))
          OR
          (r.time_type = 'now')
      )
    ORDER BY pickup_dist_meters ASC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution to authenticated users and backend service role
GRANT EXECUTE ON FUNCTION public.find_candidate_rides_spatial(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT, INT, VARCHAR, DATE)
  TO authenticated, service_role, anon;

COMMENT ON FUNCTION public.find_candidate_rides_spatial IS
  'Tier 1 Spatial Pre-Filter: Prunes 95-99% non-relevant rides in <5ms using PostGIS GiST index. SRS §6.1, §6.3';

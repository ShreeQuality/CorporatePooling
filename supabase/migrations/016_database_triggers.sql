-- ============================================================
-- Migration 016: Automated Database Triggers
-- Source of Truth: SRS_Document.md (§3, §5.2, §16, §17.6)
-- Date: 18-Aug-2026
-- Run AFTER: 015_stored_procedures.sql
-- ============================================================

-- ============================================================
-- 1. AUTOMATIC UPDATED_AT TIMESTAMP TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to all mutable tables
DROP TRIGGER IF EXISTS trg_users_updated_at ON public.users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_rides_updated_at ON public.rides;
CREATE TRIGGER trg_rides_updated_at
    BEFORE UPDATE ON public.rides
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_ride_requests_updated_at ON public.ride_requests;
CREATE TRIGGER trg_ride_requests_updated_at
    BEFORE UPDATE ON public.ride_requests
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_wallets_updated_at ON public.wallets;
CREATE TRIGGER trg_wallets_updated_at
    BEFORE UPDATE ON public.wallets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_companies_updated_at ON public.companies;
CREATE TRIGGER trg_companies_updated_at
    BEFORE UPDATE ON public.companies
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_family_wallets_updated_at ON public.family_wallets;
CREATE TRIGGER trg_family_wallets_updated_at
    BEFORE UPDATE ON public.family_wallets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_app_remote_config_updated_at ON public.app_remote_config;
CREATE TRIGGER trg_app_remote_config_updated_at
    BEFORE UPDATE ON public.app_remote_config
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_system_settings_updated_at ON public.system_settings;
CREATE TRIGGER trg_system_settings_updated_at
    BEFORE UPDATE ON public.system_settings
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================================
-- 2. AUTO-PROVISION WALLET ON USER CREATION (SRS §3, §12)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user_wallet()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.wallets (
        user_id, available_balance, locked_balance, corporate_grant_balance,
        lifetime_earned, lifetime_spent
    )
    VALUES (
        NEW.id, 0.00, 0.00, 0.00,
        0.00, 0.00
    )
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_user_created_provision_wallet ON public.users;
CREATE TRIGGER trg_on_user_created_provision_wallet
    AFTER INSERT ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_wallet();


-- ============================================================
-- 3. SEARCH ALERT MATCHER TRIGGER ON NEW RIDE POST (SRS §5.2)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_ride_search_alerts()
RETURNS TRIGGER AS $$
BEGIN
    -- Match any active search alert within 2000 meters of the new ride origin
    INSERT INTO public.notifications (user_id, title, body, type, ride_id)
    SELECT 
        sa.user_id,
        'Matching Commute Found! 🔔',
        'A driver just posted a ride matching your route for ' || TO_CHAR(NEW.depart_time, 'HH12:MI AM') || '. Tap to book!',
        'ride_request',
        NEW.id
    FROM public.search_alerts sa
    WHERE sa.is_active = TRUE
      AND ST_DWithin(sa.from_location::geography, NEW.from_location::geography, 2000)
      AND (sa.target_date IS NULL OR sa.target_date = NEW.depart_date);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_ride_posted_match_search_alerts ON public.rides;
CREATE TRIGGER trg_on_ride_posted_match_search_alerts
    AFTER INSERT ON public.rides
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_ride_search_alerts();


-- ============================================================
-- 4. SOS EMERGENCY BROADCAST TRIGGER (SRS §17.6)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_sos_broadcast()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Queue alert for Driver
    INSERT INTO public.notifications (user_id, title, body, type, ride_id, data)
    VALUES (
        NEW.driver_id,
        '🚨 EMERGENCY SOS TRIGGERED',
        'SOS alert triggered on vehicle ' || NEW.vehicle_plate || '. Emergency protocol engaged.',
        'sos_alert',
        NEW.ride_id,
        jsonb_build_object('incident_id', NEW.id, 'speed_kmh', NEW.live_speed_kmh, 'lat', NEW.trigger_lat, 'lng', NEW.trigger_lng)
    );

    -- 2. Queue alert for Commuter (distress acknowledgment)
    INSERT INTO public.notifications (user_id, title, body, type, ride_id, data)
    VALUES (
        NEW.triggered_by,
        '🛡️ Emergency Help Dispatched',
        'SOS received. Your live GPS tracking link has been broadcast to your family and emergency services.',
        'sos_alert',
        NEW.ride_id,
        jsonb_build_object('incident_id', NEW.id)
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_sos_created_broadcast ON public.emergency_sos_incidents;
CREATE TRIGGER trg_on_sos_created_broadcast
    AFTER INSERT ON public.emergency_sos_incidents
    FOR EACH ROW EXECUTE FUNCTION public.handle_sos_broadcast();

-- ============================================================
-- END OF MIGRATION 016
-- ============================================================

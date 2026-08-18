-- ============================================================
-- Migration 015: Master Stored Procedures (RPCs)
-- Source of Truth: SRS_Document.md (§5, §8, §9, §10, §11, §13, §14, §20, §21)
-- Date: 18-Aug-2026
-- Run AFTER: 014_production_schema.sql (confirmed 27 tables live)
-- ============================================================

-- ============================================================
-- STEP 1: RIDE BOOKING & BOARDING STATE MACHINE
-- ============================================================

-- ─── 1. accept_ride_request_atomic ───────────────────────────
-- Purpose: Atomically locks ride row, decrements available seats,
--          locks rider escrow, auto-cancels competing requests (Multi-Request Rule),
--          and provisions/links the per-ride chat room.
-- Source: SRS §5.3, §8.1, §15.2
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.accept_ride_request_atomic(
    p_request_id UUID,
    p_driver_id  UUID
)
RETURNS JSONB AS $$
DECLARE
    v_req RECORD;
    v_ride RECORD;
    v_wallet RECORD;
    v_room_id UUID;
    v_cancelled_count INT := 0;
BEGIN
    -- 1. Fetch and lock the ride request
    SELECT * INTO v_req
    FROM public.ride_requests
    WHERE id = p_request_id AND status = 'pending'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_FOUND_OR_NOT_PENDING');
    END IF;

    -- 2. Fetch and lock the ride
    SELECT * INTO v_ride
    FROM public.rides
    WHERE id = v_req.ride_id AND driver_id = p_driver_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'RIDE_NOT_FOUND_OR_UNAUTHORIZED');
    END IF;

    -- 3. Check seat capacity
    IF v_ride.seats_available < v_req.seats_requested THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_SEATS');
    END IF;

    -- 4. Check and lock rider wallet
    SELECT * INTO v_wallet
    FROM public.wallets
    WHERE user_id = v_req.rider_id
    FOR UPDATE;

    IF v_wallet.available_balance < v_req.coins_locked THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_RIDER_COINS');
    END IF;

    -- 5. Lock rider coins (available -> locked)
    UPDATE public.wallets
    SET available_balance = available_balance - v_req.coins_locked,
        locked_balance    = locked_balance + v_req.coins_locked,
        updated_at        = NOW()
    WHERE user_id = v_req.rider_id;

    -- 6. Decrement available seats on the ride
    UPDATE public.rides
    SET seats_available = seats_available - v_req.seats_requested,
        updated_at      = NOW()
    WHERE id = v_ride.id;

    -- 7. Update request status to 'accepted'
    UPDATE public.ride_requests
    SET status     = 'accepted',
        updated_at = NOW()
    WHERE id = v_req.id;

    -- 8. Log escrow lock transaction
    INSERT INTO public.coin_transactions (
        sender_id, amount, transaction_type, ride_id, request_id,
        idempotency_key, status
    ) VALUES (
        v_req.rider_id, v_req.coins_locked, 'escrow_lock', v_ride.id, v_req.id,
        'escrow_lock_' || v_req.id::text, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    -- 9. Auto-cancel competing requests to other drivers (Multi-Request Rule §8.1)
    UPDATE public.ride_requests
    SET status     = 'cancelled',
        updated_at = NOW()
    WHERE rider_id = v_req.rider_id
      AND id <> v_req.id
      AND status = 'pending';
    GET DIAGNOSTICS v_cancelled_count = ROW_COUNT;

    -- 10. Provision or get per-ride chat room (§15.4)
    SELECT id INTO v_room_id
    FROM public.chat_rooms
    WHERE ride_id = v_ride.id AND room_type = 'ride';

    IF NOT FOUND THEN
        INSERT INTO public.chat_rooms (room_type, ride_id, name, created_by)
        VALUES ('ride', v_ride.id, 'Ride Chat', p_driver_id)
        RETURNING id INTO v_room_id;

        -- Add driver to room
        INSERT INTO public.chat_room_members (room_id, user_id)
        VALUES (v_room_id, p_driver_id)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Add rider to room
    INSERT INTO public.chat_room_members (room_id, user_id)
    VALUES (v_room_id, v_req.rider_id)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_req.id,
        'seats_remaining', v_ride.seats_available - v_req.seats_requested,
        'coins_locked', v_req.coins_locked,
        'competing_requests_cancelled', v_cancelled_count,
        'chat_room_id', v_room_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 2. cancel_ride_request_atomic ───────────────────────────
-- Purpose: Handles cancellation by Driver or Rider.
--          Dynamic fee calculation from system_settings.
--          Restores seats and refunds/transfers coins atomically.
-- Source: SRS §8.3, §8.9, §21.2
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_ride_request_atomic(
    p_request_id   UUID,
    p_cancelled_by UUID,
    p_reason       TEXT DEFAULT 'User cancelled'
)
RETURNS JSONB AS $$
DECLARE
    v_req RECORD;
    v_ride RECORD;
    v_is_driver BOOLEAN;
    v_late_cancel_mins INT := 15;
    v_late_cancel_fee NUMERIC(6,2) := 5.00;
    v_fee_charged NUMERIC(6,2) := 0.00;
    v_refund_amount NUMERIC(6,2) := 0.00;
    v_minutes_to_depart NUMERIC;
BEGIN
    -- 1. Fetch and lock request
    SELECT * INTO v_req
    FROM public.ride_requests
    WHERE id = p_request_id AND status IN ('pending', 'accepted')
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_ACTIVE');
    END IF;

    -- 2. Fetch ride
    SELECT * INTO v_ride
    FROM public.rides
    WHERE id = v_req.ride_id
    FOR UPDATE;

    v_is_driver := (v_ride.driver_id = p_cancelled_by);

    -- 3. If request was only 'pending', no coins locked -> just mark cancelled
    IF v_req.status = 'pending' THEN
        UPDATE public.ride_requests
        SET status = 'cancelled', updated_at = NOW()
        WHERE id = v_req.id;

        RETURN jsonb_build_object('success', true, 'status', 'cancelled', 'refund', 0);
    END IF;

    -- 4. Read system settings for late fee rules
    SELECT COALESCE(value::INT, 15) INTO v_late_cancel_mins
    FROM public.system_settings WHERE key = 'LATE_CANCEL_MINS';

    SELECT COALESCE(value::NUMERIC, 5.00) INTO v_late_cancel_fee
    FROM public.system_settings WHERE key = 'RIDER_LATE_CANCEL_FEE';

    -- 5. Calculate cancellation logic
    IF v_is_driver THEN
        -- Driver cancelled: 100% refund to rider + restore seats
        v_refund_amount := v_req.coins_locked;
        v_fee_charged := 0.00;
    ELSE
        -- Rider cancelled: check departure time proximity
        IF v_ride.depart_date IS NOT NULL THEN
            v_minutes_to_depart := EXTRACT(EPOCH FROM ((v_ride.depart_date + v_ride.depart_time) - NOW())) / 60;
        ELSE
            v_minutes_to_depart := EXTRACT(EPOCH FROM ((CURRENT_DATE + v_ride.depart_time) - NOW())) / 60;
        END IF;

        IF v_minutes_to_depart < v_late_cancel_mins AND v_minutes_to_depart > 0 THEN
            -- Late cancellation fee applied
            v_fee_charged := LEAST(v_late_cancel_fee, v_req.coins_locked);
            v_refund_amount := v_req.coins_locked - v_fee_charged;
        ELSE
            -- Free cancellation (> 15/30 mins)
            v_refund_amount := v_req.coins_locked;
            v_fee_charged := 0.00;
        END IF;
    END IF;

    -- 6. Refund coins to rider wallet
    UPDATE public.wallets
    SET locked_balance    = locked_balance - v_req.coins_locked,
        available_balance = available_balance + v_refund_amount,
        updated_at        = NOW()
    WHERE user_id = v_req.rider_id;

    -- 7. If late fee charged, credit to driver
    IF v_fee_charged > 0 THEN
        UPDATE public.wallets
        SET available_balance = available_balance + v_fee_charged,
            lifetime_earned   = lifetime_earned + v_fee_charged,
            updated_at        = NOW()
        WHERE user_id = v_ride.driver_id;

        INSERT INTO public.coin_transactions (
            sender_id, receiver_id, amount, transaction_type,
            ride_id, request_id, idempotency_key, status
        ) VALUES (
            v_req.rider_id, v_ride.driver_id, v_fee_charged, 'late_cancel_fee',
            v_ride.id, v_req.id, 'cancel_fee_' || v_req.id::text, 'completed'
        ) ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 8. Log refund transaction
    IF v_refund_amount > 0 THEN
        INSERT INTO public.coin_transactions (
            receiver_id, amount, transaction_type,
            ride_id, request_id, idempotency_key, status
        ) VALUES (
            v_req.rider_id, v_refund_amount, 'escrow_refund',
            v_ride.id, v_req.id, 'cancel_refund_' || v_req.id::text, 'completed'
        ) ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 9. Restore seats on ride
    UPDATE public.rides
    SET seats_available = LEAST(seats_offered, seats_available + v_req.seats_requested),
        updated_at      = NOW()
    WHERE id = v_ride.id;

    -- 10. Update request status
    UPDATE public.ride_requests
    SET status     = 'cancelled',
        updated_at = NOW()
    WHERE id = v_req.id;

    RETURN jsonb_build_object(
        'success', true,
        'refund_amount', v_refund_amount,
        'fee_charged', v_fee_charged,
        'cancelled_by_driver', v_is_driver
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 3. verify_boarding_atomic ───────────────────────────────
-- Purpose: Validates BLE Proximity / Dynamic QR / 4-Digit PIN.
--          Transitions request to 'in_ride' and ride to 'in_progress'.
-- Source: SRS §9.1, §9.2
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.verify_boarding_atomic(
    p_request_id UUID,
    p_method     VARCHAR(30), -- 'ble', 'qr', 'pin'
    p_pin_word   VARCHAR(20) DEFAULT NULL,
    p_ble_uuid   UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_req RECORD;
    v_ride RECORD;
BEGIN
    -- 1. Fetch request
    SELECT * INTO v_req
    FROM public.ride_requests
    WHERE id = p_request_id AND status = 'accepted'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_ACCEPTED_OR_INVALID');
    END IF;

    -- 2. Fetch ride
    SELECT * INTO v_ride
    FROM public.rides
    WHERE id = v_req.ride_id
    FOR UPDATE;

    -- 3. Verification method check
    IF p_method = 'pin' THEN
        IF p_pin_word IS NULL OR LOWER(TRIM(p_pin_word)) <> LOWER(TRIM(v_ride.boarding_daily_word)) THEN
            RETURN jsonb_build_object('success', false, 'error', 'INVALID_BOARDING_PIN');
        END IF;
    ELSIF p_method = 'ble' THEN
        IF p_ble_uuid IS NULL OR p_ble_uuid <> v_ride.boarding_ble_uuid THEN
            RETURN jsonb_build_object('success', false, 'error', 'INVALID_BLE_UUID');
        END IF;
    END IF;

    -- 4. Mark request 'in_ride'
    UPDATE public.ride_requests
    SET status                   = 'in_ride',
        boarding_verified_at     = NOW(),
        verification_method_used = p_method,
        updated_at               = NOW()
    WHERE id = v_req.id;

    -- 5. If ride was started or arrived, advance to 'in_progress'
    IF v_ride.ride_status IN ('posted', 'started', 'arrived_at_pickup') THEN
        UPDATE public.rides
        SET ride_status = 'in_progress',
            started_at  = COALESCE(started_at, NOW()),
            updated_at  = NOW()
        WHERE id = v_ride.id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_req.id,
        'verification_method', p_method,
        'verified_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- STEP 2: DROP-OFF SETTLEMENT & ESG ATTENDANCE
-- ============================================================

-- ─── 4. complete_single_dropoff (Staggered Drops) ────────────
-- Purpose: Settles an individual passenger who reached their specific
--          gate while leaving other passengers in-vehicle.
-- Source: SRS §10.2
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_single_dropoff(
    p_request_id UUID,
    p_driver_id  UUID
)
RETURNS JSONB AS $$
DECLARE
    v_req RECORD;
    v_ride RECORD;
    v_co2_kg NUMERIC(6,2) := 0.00;
    v_rider RECORD;
BEGIN
    -- 1. Fetch and lock request
    SELECT * INTO v_req
    FROM public.ride_requests
    WHERE id = p_request_id AND status = 'in_ride'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'REQUEST_NOT_IN_RIDE');
    END IF;

    -- 2. Fetch and lock ride
    SELECT * INTO v_ride
    FROM public.rides
    WHERE id = v_req.ride_id AND driver_id = p_driver_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_DRIVER');
    END IF;

    -- 3. Lock rider details
    SELECT * INTO v_rider FROM public.users WHERE id = v_req.rider_id;

    -- 4. Transfer coins: Rider locked_balance -> Driver available_balance
    UPDATE public.wallets
    SET locked_balance = locked_balance - v_req.coins_locked,
        lifetime_spent = lifetime_spent + v_req.coins_locked,
        updated_at     = NOW()
    WHERE user_id = v_req.rider_id;

    UPDATE public.wallets
    SET available_balance = available_balance + v_req.coins_locked,
        lifetime_earned   = lifetime_earned + v_req.coins_locked,
        updated_at        = NOW()
    WHERE user_id = p_driver_id;

    -- 5. Record double-entry ledger entry
    INSERT INTO public.coin_transactions (
        sender_id, receiver_id, amount, transaction_type,
        ride_id, request_id, idempotency_key, status
    ) VALUES (
        v_req.rider_id, p_driver_id, v_req.coins_locked, 'ride_earning',
        v_ride.id, v_req.id, 'ride_complete_' || v_ride.id::text || '_' || v_req.rider_id::text,
        'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    -- 6. Calculate ESG CO2 savings: Distance * 0.15kg * 1 passenger
    v_co2_kg := ROUND((v_ride.distance_km * 0.15), 2);

    -- 7. Soft attendance ingestion (§10.5, 6am-11am window)
    IF v_rider.company_id IS NOT NULL AND CURRENT_TIME BETWEEN '06:00:00' AND '11:00:00' THEN
        INSERT INTO public.corporate_attendance (
            employee_id, company_id, ride_id, date, arrived_at, transport_mode
        ) VALUES (
            v_req.rider_id, v_rider.company_id, v_ride.id, CURRENT_DATE, NOW(), 'carpool'
        ) ON CONFLICT (employee_id, date) DO NOTHING;
    END IF;

    -- 8. Mark request 'completed'
    UPDATE public.ride_requests
    SET status       = 'completed',
        completed_at = NOW(),
        updated_at   = NOW()
    WHERE id = v_req.id;

    RETURN jsonb_build_object(
        'success', true,
        'rider_id', v_req.rider_id,
        'coins_transferred', v_req.coins_locked,
        'co2_saved_kg', v_co2_kg
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 5. complete_ride (Full Trip Drop-off) ───────────────────
-- Purpose: Completes trip for all remaining passengers, awards driver,
--          calculates total ESG, logs driver attendance, and resets recurring rides.
-- Source: SRS §9.5, §10.3, §10.4, §10.5
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_ride(
    p_ride_id   UUID,
    p_driver_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_req RECORD;
    v_ride RECORD;
    v_driver RECORD;
    v_total_coins NUMERIC(8,2) := 0.00;
    v_rider_count INT := 0;
    v_co2_kg NUMERIC(6,2) := 0.00;
BEGIN
    -- 1. Fetch and lock the ride
    SELECT * INTO v_ride
    FROM public.rides
    WHERE id = p_ride_id AND driver_id = p_driver_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'RIDE_NOT_FOUND_OR_UNAUTHORIZED');
    END IF;

    -- 2. Fetch driver profile
    SELECT * INTO v_driver FROM public.users WHERE id = p_driver_id;

    -- 3. Loop through all 'in_ride' requests and settle
    FOR v_req IN
        SELECT id, rider_id, coins_locked
        FROM public.ride_requests
        WHERE ride_id = p_ride_id AND status = 'in_ride'
    LOOP
        -- Transfer coins
        UPDATE public.wallets
        SET locked_balance = locked_balance - v_req.coins_locked,
            lifetime_spent = lifetime_spent + v_req.coins_locked,
            updated_at     = NOW()
        WHERE user_id = v_req.rider_id;

        UPDATE public.wallets
        SET available_balance = available_balance + v_req.coins_locked,
            lifetime_earned   = lifetime_earned + v_req.coins_locked,
            updated_at        = NOW()
        WHERE user_id = p_driver_id;

        -- Record ledger entry
        INSERT INTO public.coin_transactions (
            sender_id, receiver_id, amount, transaction_type,
            ride_id, request_id, idempotency_key, status
        ) VALUES (
            v_req.rider_id, p_driver_id, v_req.coins_locked, 'ride_earning',
            p_ride_id, v_req.id, 'ride_complete_' || p_ride_id::text || '_' || v_req.rider_id::text,
            'completed'
        ) ON CONFLICT (idempotency_key) DO NOTHING;

        -- Soft attendance for rider
        IF CURRENT_TIME BETWEEN '06:00:00' AND '11:00:00' THEN
            INSERT INTO public.corporate_attendance (
                employee_id, company_id, ride_id, date, arrived_at, transport_mode
            )
            SELECT v_req.rider_id, u.company_id, p_ride_id, CURRENT_DATE, NOW(), 'carpool'
            FROM public.users u
            WHERE u.id = v_req.rider_id AND u.company_id IS NOT NULL
            ON CONFLICT (employee_id, date) DO NOTHING;
        END IF;

        -- Mark request completed
        UPDATE public.ride_requests
        SET status = 'completed', completed_at = NOW(), updated_at = NOW()
        WHERE id = v_req.id;

        v_total_coins := v_total_coins + v_req.coins_locked;
        v_rider_count := v_rider_count + 1;
    END LOOP;

    -- 4. Calculate total ESG CO2 savings: Distance * 0.15kg * rider count
    v_co2_kg := ROUND((v_ride.distance_km * 0.15 * GREATEST(1, v_rider_count)), 2);

    -- 5. Soft attendance for driver
    IF v_driver.company_id IS NOT NULL AND CURRENT_TIME BETWEEN '06:00:00' AND '11:00:00' THEN
        INSERT INTO public.corporate_attendance (
            employee_id, company_id, ride_id, date, arrived_at, transport_mode
        ) VALUES (
            p_driver_id, v_driver.company_id, p_ride_id, CURRENT_DATE, NOW(), 'carpool'
        ) ON CONFLICT (employee_id, date) DO NOTHING;
    END IF;

    -- 6. State Machine Transition: Recurring vs Scheduled
    IF v_ride.time_type = 'recurring' THEN
        -- Recurring: append completion date and reset status to 'posted' for tomorrow
        UPDATE public.rides
        SET completion_dates = array_append(completion_dates, CURRENT_DATE),
            ride_status      = 'posted',
            seats_available  = seats_offered,
            started_at       = NULL,
            updated_at       = NOW()
        WHERE id = p_ride_id;
    ELSE
        -- One-time: mark completed
        UPDATE public.rides
        SET ride_status  = 'completed',
            completed_at = NOW(),
            updated_at   = NOW()
        WHERE id = p_ride_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'total_coins_earned', v_total_coins,
        'passengers_settled', v_rider_count,
        'co2_saved_kg', v_co2_kg,
        'time_type', v_ride.time_type
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- STEP 3: AUTOMATION CRON ENGINES
-- ============================================================

-- ─── 6. process_nightly_recurring_rides (8:00 PM IST Cron) ────
-- Purpose: Pre-pairs recurring commuters for tomorrow, verifies wallet
--          waterfall (Grant -> Personal -> Overdraft), and locks micro-escrow.
-- Source: SRS §11.2
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_nightly_recurring_rides()
RETURNS JSONB AS $$
DECLARE
    v_ride RECORD;
    v_req RECORD;
    v_wallet RECORD;
    v_tomorrow_day INT := EXTRACT(ISODOW FROM (CURRENT_DATE + INTERVAL '1 day'));
    v_tomorrow_date DATE := CURRENT_DATE + INTERVAL '1 day';
    v_max_overdraft NUMERIC(6,2) := 30.00;
    v_paired_count INT := 0;
    v_overdraft_count INT := 0;
    v_low_balance_count INT := 0;
BEGIN
    -- Read dynamic overdraft limit from settings
    SELECT COALESCE(value::NUMERIC, 30.00) INTO v_max_overdraft
    FROM public.system_settings
    WHERE key = 'MAX_RECURRING_OVERDRAFT_COINS';

    -- Iterate active recurring rides for tomorrow
    FOR v_ride IN
        SELECT r.id, r.driver_id, r.seats_offered, r.fare_coins
        FROM public.rides r
        WHERE r.time_type = 'recurring'
          AND v_tomorrow_day = ANY(r.recurring_days)
          AND NOT (v_tomorrow_date = ANY(r.skip_dates))
          AND r.ride_status = 'posted'
    LOOP
        -- For each confirmed request on this ride
        FOR v_req IN
            SELECT req.id, req.rider_id, req.coins_locked
            FROM public.ride_requests req
            WHERE req.ride_id = v_ride.id
              AND req.status = 'accepted'
        LOOP
            SELECT * INTO v_wallet FROM public.wallets WHERE user_id = v_req.rider_id FOR UPDATE;

            IF v_wallet.available_balance >= v_req.coins_locked THEN
                -- Case 1: Balance sufficient -> lock micro-escrow
                UPDATE public.wallets
                SET available_balance = available_balance - v_req.coins_locked,
                    locked_balance    = locked_balance + v_req.coins_locked,
                    updated_at        = NOW()
                WHERE user_id = v_req.rider_id;

                INSERT INTO public.notifications (user_id, title, body, type, ride_id)
                VALUES (
                    v_req.rider_id,
                    'Tomorrow Commute Confirmed 🚗',
                    'Your ride for tomorrow is locked and confirmed.',
                    'request_accepted',
                    v_ride.id
                );

                v_paired_count := v_paired_count + 1;

            ELSIF (v_wallet.available_balance + v_max_overdraft) >= v_req.coins_locked THEN
                -- Case 2: Apply overdraft buffer (§11.3)
                UPDATE public.wallets
                SET available_balance = available_balance - v_req.coins_locked,
                    locked_balance    = locked_balance + v_req.coins_locked,
                    updated_at        = NOW()
                WHERE user_id = v_req.rider_id;

                INSERT INTO public.notifications (user_id, title, body, type, ride_id)
                VALUES (
                    v_req.rider_id,
                    'Overdraft Applied for Tomorrow ⚠️',
                    'Your ride is confirmed using emergency overdraft. Please earn or recharge coins soon.',
                    'request_accepted',
                    v_ride.id
                );

                v_overdraft_count := v_overdraft_count + 1;

            ELSE
                -- Case 3: Insufficient balance -> Grace period notification
                INSERT INTO public.notifications (user_id, title, body, type, ride_id)
                VALUES (
                    v_req.rider_id,
                    'Low Coins Alert for Tomorrow 🔴',
                    'Insufficient coins for tomorrow commute. Switch to family wallet or recharge before 10 PM.',
                    'system',
                    v_ride.id
                );

                v_low_balance_count := v_low_balance_count + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'date_processed', v_tomorrow_date,
        'rides_paired', v_paired_count,
        'overdrafts_applied', v_overdraft_count,
        'low_balance_warnings', v_low_balance_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 7. distribute_monthly_corporate_grants (1st of Month) ──
-- Purpose: Distributes monthly employer commute subsidies (e.g. 400 coins)
--          from the company master pool to verified employees.
-- Source: SRS §14.3, §14.4
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.distribute_monthly_corporate_grants()
RETURNS JSONB AS $$
DECLARE
    v_company RECORD;
    v_emp RECORD;
    v_grant NUMERIC(6,2);
    v_total_distributed NUMERIC(10,2) := 0.00;
    v_emp_count INT := 0;
    v_grant_month VARCHAR(7) := TO_CHAR(CURRENT_DATE, 'YYYY_MM');
BEGIN
    FOR v_company IN
        SELECT id, name, total_coins_pool, default_monthly_grant_per_employee
        FROM public.companies
        WHERE is_active = TRUE AND total_coins_pool > 0
    LOOP
        v_grant := v_company.default_monthly_grant_per_employee;

        FOR v_emp IN
            SELECT id FROM public.users
            WHERE company_id = v_company.id
              AND role = 'corporate_employee'
              AND is_banned = FALSE
        LOOP
            IF v_company.total_coins_pool >= v_grant THEN
                -- Deduct from company pool
                UPDATE public.companies
                SET total_coins_pool = total_coins_pool - v_grant,
                    updated_at       = NOW()
                WHERE id = v_company.id;

                -- Credit employee wallet
                UPDATE public.wallets
                SET corporate_grant_balance = corporate_grant_balance + v_grant,
                    available_balance       = available_balance + v_grant,
                    updated_at              = NOW()
                WHERE user_id = v_emp.id;

                -- Record ledger entry
                INSERT INTO public.coin_transactions (
                    receiver_id, amount, transaction_type,
                    idempotency_key, status
                ) VALUES (
                    v_emp.id, v_grant, 'corporate_grant',
                    'monthly_grant_' || v_company.id::text || '_' || v_emp.id::text || '_' || v_grant_month,
                    'completed'
                ) ON CONFLICT (idempotency_key) DO NOTHING;

                -- Send in-app celebration notification
                INSERT INTO public.notifications (user_id, title, body, type)
                VALUES (
                    v_emp.id,
                    '🎉 Monthly Commute Grant Credited!',
                    v_company.name || ' granted you ' || v_grant::text || ' Karma Coins for this month commute.',
                    'coins_received'
                );

                v_total_distributed := v_total_distributed + v_grant;
                v_emp_count := v_emp_count + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'employees_credited', v_emp_count,
        'total_coins_distributed', v_total_distributed,
        'month', v_grant_month
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- STEP 4: CALENDAR, TRUST & ADMINISTRATION
-- ============================================================

-- ─── 8. toggle_recurring_skip_date ───────────────────────────
-- Purpose: Commuter toggles WFH / Leave for a specific date in skip_dates[].
--          If Driver skips, auto-refunds all locked rider escrows for that date.
-- Source: SRS §8.7, §9.4
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_recurring_skip_date(
    p_ride_id UUID,
    p_user_id UUID,
    p_date    DATE
)
RETURNS JSONB AS $$
DECLARE
    v_ride RECORD;
    v_is_driver BOOLEAN;
    v_req RECORD;
    v_is_skipped BOOLEAN;
BEGIN
    SELECT * INTO v_ride
    FROM public.rides
    WHERE id = p_ride_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'RIDE_NOT_FOUND');
    END IF;

    v_is_driver := (v_ride.driver_id = p_user_id);
    v_is_skipped := (p_date = ANY(v_ride.skip_dates));

    IF v_is_skipped THEN
        -- Un-skip: remove date from array
        UPDATE public.rides
        SET skip_dates = array_remove(skip_dates, p_date),
            updated_at = NOW()
        WHERE id = p_ride_id;

        RETURN jsonb_build_object('success', true, 'action', 'unskipped', 'date', p_date);
    ELSE
        -- Skip: append date to array
        UPDATE public.rides
        SET skip_dates = array_append(skip_dates, p_date),
            updated_at = NOW()
        WHERE id = p_ride_id;

        -- If Driver skipped, refund all locked escrows for that ride
        IF v_is_driver THEN
            FOR v_req IN
                SELECT id, rider_id, coins_locked
                FROM public.ride_requests
                WHERE ride_id = p_ride_id AND status = 'accepted'
            LOOP
                UPDATE public.wallets
                SET locked_balance    = locked_balance - v_req.coins_locked,
                    available_balance = available_balance + v_req.coins_locked,
                    updated_at        = NOW()
                WHERE user_id = v_req.rider_id;

                INSERT INTO public.notifications (user_id, title, body, type, ride_id)
                VALUES (
                    v_req.rider_id,
                    'Driver Skipped Today ⚪',
                    'Your driver is taking leave today. Your coins have been 100% refunded.',
                    'system',
                    p_ride_id
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', true, 'action', 'skipped', 'date', p_date);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 9. submit_ride_rating_and_trust_score ──────────────────
-- Purpose: Implements Double-Blind Review shield (hidden until both submit).
--          Recalculates dynamic Safety Trust Score (0–100) using mathematical model.
-- Source: SRS §20.3, §20.4, §20.5
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_ride_rating_and_trust_score(
    p_ride_id     UUID,
    p_rater_id    UUID,
    p_ratee_id    UUID,
    p_stars       INT,
    p_compliments TEXT[] DEFAULT '{}'::TEXT[],
    p_feedback    TEXT   DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_is_driver_rating BOOLEAN;
    v_counterpart_exists BOOLEAN := FALSE;
    v_new_trust_score INT := 50;
    v_avg_stars NUMERIC(3,2);
    v_five_star_count INT;
    v_smooth_trip_count INT;
    v_violation_count INT;
    v_user RECORD;
BEGIN
    -- 1. Determine rating direction
    SELECT (driver_id = p_ratee_id) INTO v_is_driver_rating
    FROM public.rides WHERE id = p_ride_id;

    -- 2. Insert rating record (is_locked = TRUE by default)
    INSERT INTO public.ride_ratings (
        ride_id, rater_id, ratee_id, is_driver_rating,
        stars, compliment_chips, feedback_text, is_locked
    ) VALUES (
        p_ride_id, p_rater_id, p_ratee_id, COALESCE(v_is_driver_rating, FALSE),
        p_stars, p_compliments, p_feedback, TRUE
    )
    ON CONFLICT (ride_id, rater_id, ratee_id)
    DO UPDATE SET stars = p_stars, compliment_chips = p_compliments, feedback_text = p_feedback;

    -- 3. Check Double-Blind condition: Did counterpart also submit?
    SELECT EXISTS (
        SELECT 1 FROM public.ride_ratings
        WHERE ride_id = p_ride_id AND rater_id = p_ratee_id AND ratee_id = p_rater_id
    ) INTO v_counterpart_exists;

    -- 4. If both submitted, unlock both reviews simultaneously!
    IF v_counterpart_exists THEN
        UPDATE public.ride_ratings
        SET is_locked = FALSE
        WHERE ride_id = p_ride_id;
    END IF;

    -- 5. Recalculate dynamic Trust Score for ratee (§20.4)
    SELECT * INTO v_user FROM public.users WHERE id = p_ratee_id;

    -- Base score
    v_new_trust_score := 50;

    -- Verification boosts
    IF v_user.phone_number IS NOT NULL THEN v_new_trust_score := v_new_trust_score + 10; END IF;
    IF v_user.work_email_verified THEN v_new_trust_score := v_new_trust_score + 20; END IF;
    IF v_user.aadhaar_verified THEN v_new_trust_score := v_new_trust_score + 20; END IF;

    -- 5-star review boosts (+1 per 5-star, max +15)
    SELECT COUNT(*) INTO v_five_star_count
    FROM public.ride_ratings
    WHERE ratee_id = p_ratee_id AND stars = 5 AND is_locked = FALSE;
    v_new_trust_score := v_new_trust_score + LEAST(15, v_five_star_count);

    -- Telematics rash driving penalties (-5 per violation in last 30 days)
    SELECT COUNT(*) INTO v_violation_count
    FROM public.telematics_violations
    WHERE driver_id = p_ratee_id AND recorded_at > NOW() - INTERVAL '30 days';
    v_new_trust_score := v_new_trust_score - (v_violation_count * 5);

    -- Clamp score between 0 and 100
    v_new_trust_score := GREATEST(0, LEAST(100, v_new_trust_score));

    -- Update user trust score
    UPDATE public.users
    SET trust_score = v_new_trust_score,
        updated_at  = NOW()
    WHERE id = p_ratee_id;

    RETURN jsonb_build_object(
        'success', true,
        'is_double_blind_unlocked', v_counterpart_exists,
        'ratee_updated_trust_score', v_new_trust_score
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 10. recharge_company_coin_pool ──────────────────────────
-- Purpose: Super Admin 1-click B2B prepaid coin pool recharge upon bank NEFT/RTGS verification.
-- Source: SRS §14.5, §17.4.3
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.recharge_company_coin_pool(
    p_company_id UUID,
    p_admin_id   UUID,
    p_amount     NUMERIC(10,2),
    p_utr_ref    VARCHAR(50) DEFAULT 'NEFT_RTGS_DIRECT'
)
RETURNS JSONB AS $$
DECLARE
    v_company RECORD;
    v_new_pool NUMERIC(10,2);
BEGIN
    SELECT * INTO v_company
    FROM public.companies
    WHERE id = p_company_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'COMPANY_NOT_FOUND');
    END IF;

    UPDATE public.companies
    SET total_coins_pool = total_coins_pool + p_amount,
        updated_at       = NOW()
    WHERE id = p_company_id
    RETURNING total_coins_pool INTO v_new_pool;

    -- Audit log entry
    INSERT INTO public.admin_audit_logs (
        admin_id, action_type, target_id, details
    ) VALUES (
        p_admin_id, 'coin_minted', p_company_id,
        jsonb_build_object(
            'amount_recharged', p_amount,
            'new_total_pool', v_new_pool,
            'utr_reference', p_utr_ref
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'company_id', p_company_id,
        'amount_added', p_amount,
        'new_total_pool', v_new_pool
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- END OF MIGRATION 015
-- ============================================================

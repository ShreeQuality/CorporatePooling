-- ============================================================
-- Migration 011: Stored Procedures (RPCs)
-- All atomic operations — no race conditions, no double-spend
-- ============================================================

-- ─── accept_ride_request ─────────────────────────────────────
-- Atomically: lock coins from rider + update request status + decrement seat

CREATE OR REPLACE FUNCTION accept_ride_request(
  p_request_id UUID,
  p_ride_id    UUID,
  p_rider_id   UUID,
  p_coins      INTEGER
) RETURNS JSON AS $$
DECLARE
  v_rider_balance INTEGER;
BEGIN
  -- Lock coins from rider
  UPDATE users
  SET coin_balance = coin_balance - p_coins
  WHERE id = p_rider_id AND coin_balance >= p_coins
  RETURNING coin_balance INTO v_rider_balance;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INSUFFICIENT_COINS');
  END IF;

  -- Update request to accepted with locked coins
  UPDATE ride_requests
  SET status = 'accepted', coins_locked = p_coins
  WHERE id = p_request_id AND status = 'pending';

  IF NOT FOUND THEN
    -- Rollback coin deduction
    UPDATE users SET coin_balance = coin_balance + p_coins WHERE id = p_rider_id;
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_PENDING');
  END IF;

  -- Decrement available_seats on ride
  UPDATE rides
  SET available_seats = available_seats - 1
  WHERE id = p_ride_id AND available_seats > 0;

  -- Log the lock as a 'debit' transaction
  INSERT INTO coin_transactions(user_id, ride_id, type, amount, balance_after, description)
  VALUES (p_rider_id, p_ride_id, 'debit', p_coins, v_rider_balance, 'Coins locked for ride');

  RETURN json_build_object('success', true, 'coins_locked', p_coins);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── complete_ride_for_rider ──────────────────────────────────
-- Atomically: deduct locked coins from rider → credit driver → log both

CREATE OR REPLACE FUNCTION complete_ride_for_rider(
  p_ride_id  UUID,
  p_rider_id UUID
) RETURNS JSON AS $$
DECLARE
  v_request        ride_requests%ROWTYPE;
  v_driver_id      UUID;
  v_driver_balance INTEGER;
  v_rider_balance  INTEGER;
BEGIN
  -- Get and lock the request row
  SELECT * INTO v_request
  FROM ride_requests
  WHERE ride_id = p_ride_id AND rider_id = p_rider_id AND status = 'accepted'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  -- Idempotency: already completed?
  IF v_request.status = 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_COMPLETED');
  END IF;

  -- Get driver
  SELECT driver_id INTO v_driver_id FROM rides WHERE id = p_ride_id;

  -- Credit driver (coins earned)
  UPDATE users
  SET coin_balance       = coin_balance + v_request.coins_locked,
      total_coins_earned = total_coins_earned + v_request.coins_locked,
      total_rides_given  = total_rides_given + 1
  WHERE id = v_driver_id
  RETURNING coin_balance INTO v_driver_balance;

  -- Update rider stats (coins already deducted at accept time)
  UPDATE users
  SET total_rides_taken = total_rides_taken + 1
  WHERE id = p_rider_id
  RETURNING coin_balance INTO v_rider_balance;

  -- Mark request completed
  UPDATE ride_requests
  SET status = 'completed', completed_at = NOW(), coins_locked = 0
  WHERE id = v_request.id;

  -- Restore available seat (in case another rider can join — not needed for completed but clean)
  -- UPDATE rides SET available_seats = available_seats + 1 WHERE id = p_ride_id;

  -- Log transactions
  INSERT INTO coin_transactions(user_id, ride_id, type, amount, balance_after, description)
  VALUES
    (p_rider_id,   p_ride_id, 'spend', v_request.coins_locked, v_rider_balance,  'Ride payment to driver'),
    (v_driver_id,  p_ride_id, 'earn',  v_request.coins_locked, v_driver_balance, 'Ride earnings from rider');

  RETURN json_build_object('success', true, 'coins_transferred', v_request.coins_locked);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── refund_coins ─────────────────────────────────────────────
-- Refund locked coins when driver cancels or ride is cancelled

CREATE OR REPLACE FUNCTION refund_coins(
  p_rider_id  UUID,
  p_ride_id   UUID,
  p_amount    INTEGER
) RETURNS VOID AS $$
DECLARE
  v_new_balance INTEGER;
BEGIN
  UPDATE users
  SET coin_balance = coin_balance + p_amount
  WHERE id = p_rider_id
  RETURNING coin_balance INTO v_new_balance;

  INSERT INTO coin_transactions(user_id, ride_id, type, amount, balance_after, description)
  VALUES (p_rider_id, p_ride_id, 'refund', p_amount, v_new_balance, 'Ride cancelled — coins refunded');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── credit_coins ─────────────────────────────────────────────
-- Admin credit coins to a user (bonus, compensation, etc.)

CREATE OR REPLACE FUNCTION credit_coins(
  p_user_id     UUID,
  p_amount      INTEGER,
  p_description TEXT DEFAULT 'Admin credit'
) RETURNS VOID AS $$
DECLARE
  v_new_balance INTEGER;
BEGIN
  UPDATE users
  SET coin_balance = coin_balance + p_amount,
      total_coins_earned = total_coins_earned + p_amount
  WHERE id = p_user_id
  RETURNING coin_balance INTO v_new_balance;

  INSERT INTO coin_transactions(user_id, type, amount, balance_after, description)
  VALUES (p_user_id, 'credit', p_amount, v_new_balance, p_description);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

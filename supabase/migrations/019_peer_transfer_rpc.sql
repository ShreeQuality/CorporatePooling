-- ============================================================
-- Migration 019: Atomic Peer Coin Transfer RPC
-- Fixes Issue 1: transferCoins non-atomic double UPDATE race condition
-- Fixes Issue 4: Seeds MIN/MAX peer transfer limits into system_settings
-- Source: SRS §12.7 (Colleague Coin Gift Transfer)
-- ============================================================

-- ─── Issue 4: Seed missing system_settings keys ──────────────────────────────
INSERT INTO public.system_settings (key, value, description) VALUES
  ('MIN_PEER_TRANSFER_COINS', '5',  'Minimum Karma Coins allowed for a colleague gift transfer'),
  ('MAX_PEER_TRANSFER_COINS', '50', 'Maximum Karma Coins allowed per colleague gift transfer (anti-abuse cap)')
ON CONFLICT (key) DO NOTHING;

-- ─── Issue 1: Atomic peer-to-peer coin transfer stored procedure ──────────────
-- All steps (debit + credit + ledger) run in ONE PostgreSQL transaction.
-- If anything fails mid-way the whole block rolls back — no lost coins.
-- Idempotency key prevents double-spend on network retry.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.transfer_peer_coins(
  p_sender_id       UUID,
  p_receiver_id     UUID,
  p_amount          NUMERIC,
  p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_balance  NUMERIC;
  v_existing_tx_id  UUID;
  v_tx_id           UUID;
BEGIN
  -- 1. Idempotency guard: if this transfer was already committed, return early.
  SELECT id INTO v_existing_tx_id
    FROM public.coin_transactions
   WHERE idempotency_key = p_idempotency_key
   LIMIT 1;

  IF v_existing_tx_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status',         'already_completed',
      'transaction_id', v_existing_tx_id
    );
  END IF;

  -- 2. Lock sender wallet row (SELECT FOR UPDATE prevents concurrent race).
  SELECT available_balance INTO v_sender_balance
    FROM public.wallets
   WHERE user_id = p_sender_id
   FOR UPDATE;

  IF v_sender_balance IS NULL THEN
    RAISE EXCEPTION 'SENDER_WALLET_NOT_FOUND';
  END IF;

  IF v_sender_balance < p_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: sender has % coins, needs %',
      v_sender_balance, p_amount;
  END IF;

  -- 3. Debit sender.
  UPDATE public.wallets
     SET available_balance = available_balance - p_amount,
         lifetime_spent    = COALESCE(lifetime_spent, 0) + p_amount,
         updated_at        = NOW()
   WHERE user_id = p_sender_id;

  -- 4. Credit receiver.
  UPDATE public.wallets
     SET available_balance = available_balance + p_amount,
         lifetime_earned   = COALESCE(lifetime_earned, 0) + p_amount,
         updated_at        = NOW()
   WHERE user_id = p_receiver_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'RECEIVER_WALLET_NOT_FOUND';
  END IF;

  -- 5. Write double-entry ledger record.
  INSERT INTO public.coin_transactions (
    sender_id, receiver_id, amount,
    transaction_type, idempotency_key, status
  ) VALUES (
    p_sender_id, p_receiver_id, p_amount,
    'peer_transfer', p_idempotency_key, 'completed'
  ) RETURNING id INTO v_tx_id;

  -- 6. Return success.
  RETURN jsonb_build_object(
    'status',         'completed',
    'transaction_id', v_tx_id,
    'sender_id',      p_sender_id,
    'receiver_id',    p_receiver_id,
    'amount',         p_amount
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE; -- PostgreSQL auto-rolls back on any exception.
END;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_peer_coins(UUID, UUID, NUMERIC, TEXT)
  TO service_role;

COMMENT ON FUNCTION public.transfer_peer_coins IS
  'ACID peer coin gift: locks both wallet rows, debits sender, credits receiver, '
  'writes ledger entry in one PostgreSQL transaction. Idempotency-safe. SRS §12.7';

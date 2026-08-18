// ============================================================
// Wallet Service — Corporate Pooling Backend
// Pure Mathematical Fare Engine, Settings Cache, Waterfall Solvency & Double-Entry Ledger
// Source of Truth: SRS §4.9, §5.3, §11.2, §12.5, §12.7, §14
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');

// ─── Default Business Rate Fallbacks ───────────────────────────
const DEFAULTS = {
  CAR_COIN_RATE_PER_KM: 2.0,
  BIKE_COIN_RATE_PER_KM: 1.0,
  CAR_MIN_FARE_COINS: 5.0,
  BIKE_MIN_FARE_COINS: 3.0,
  DETOUR_COINS_PER_500M: 3.0,
  MAX_RECURRING_OVERDRAFT_COINS: 30.0,
  MIN_PEER_TRANSFER_COINS: 5.0,
  MAX_PEER_TRANSFER_COINS: 50.0,
};

// In-memory cache storage
let _settingsCache = { ...DEFAULTS };
let _lastFetchedAt = null;
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

// ============================================================
// SUBTASK 2.1: IN-MEMORY SYSTEM SETTINGS CACHE & RATE LOADER
// ============================================================

/**
 * Loads rates from public.system_settings into memory.
 * Gracefully falls back to defaults if database is unreachable.
 */
async function initSettingsCache() {
  try {
    const { data, error } = await supabaseAdmin
      .from('system_settings')
      .select('key, value');

    if (error) {
      console.warn('[WalletService] Failed to load system_settings from DB, using defaults:', error.message);
      return _settingsCache;
    }

    if (data && Array.isArray(data)) {
      const freshCache = { ...DEFAULTS };
      for (const row of data) {
        const numVal = parseFloat(row.value);
        if (!isNaN(numVal)) {
          freshCache[row.key] = numVal;
        } else {
          freshCache[row.key] = row.value;
        }
      }
      _settingsCache = freshCache;
      _lastFetchedAt = Date.now();
      console.log('[WalletService] System settings cache initialized successfully with', data.length, 'keys.');
    }
  } catch (err) {
    console.error('[WalletService] Error initializing system_settings cache:', err.message);
  }
  return _settingsCache;
}

/**
 * Synchronous getter for cached system settings.
 * Auto-triggers background refresh if TTL has expired.
 */
function getSettingsCache() {
  if (!_lastFetchedAt || Date.now() - _lastFetchedAt > CACHE_TTL_MS) {
    // Fire-and-forget async refresh
    initSettingsCache().catch((e) => console.error('[WalletService] Background cache refresh error:', e.message));
  }
  return _settingsCache;
}

/**
 * Explicit manual cache refresh (e.g. called after Super Admin modifies rates).
 */
async function refreshSettingsCache() {
  return await initSettingsCache();
}

// Auto-initialize cache upon module load
initSettingsCache().catch(() => {});

// ============================================================
// SUBTASK 2.2: PURE MATHEMATICAL FARE & DETOUR CALCULATION ENGINE
// Source: SRS §4.9, §5.3 (Multi-Seat & Detour Math)
// ============================================================

/**
 * Calculates transparent ride fare breakdown with floor rate and detour bonus.
 * 
 * @param {number} distanceKm - One-way trip distance in kilometers
 * @param {string} vehicleType - 'car', 'suv', 'bike', 'scooter', 'ev'
 * @param {number} detourMeters - Extra driver pickup/drop detour in meters (default 0)
 * @param {number} seatsRequested - Number of seats booked by rider (default 1)
 * @returns {object} Detailed transparent breakdown for UI & booking
 */
function calculateFare(distanceKm, vehicleType = 'car', detourMeters = 0, seatsRequested = 1) {
  const cache = getSettingsCache();
  const normType = (vehicleType || 'car').toLowerCase();
  const isBike = normType === 'bike' || normType === 'scooter' || normType === 'motorcycle';
  const seats = Math.max(1, parseInt(seatsRequested, 10) || 1);

  // 1. Rate per kilometer
  const ratePerKm = isBike
    ? (cache.BIKE_COIN_RATE_PER_KM || DEFAULTS.BIKE_COIN_RATE_PER_KM)
    : (cache.CAR_COIN_RATE_PER_KM || DEFAULTS.CAR_COIN_RATE_PER_KM);

  // 2. Minimum floor fare per seat
  const minFarePerSeat = isBike
    ? (cache.BIKE_MIN_FARE_COINS || DEFAULTS.BIKE_MIN_FARE_COINS)
    : (cache.CAR_MIN_FARE_COINS || DEFAULTS.CAR_MIN_FARE_COINS);

  // 3. Raw distance math with ceiling rounding
  const rawDistanceFare = Math.ceil(Math.max(0, distanceKm) * ratePerKm);
  const baseFarePerSeat = Math.max(minFarePerSeat, rawDistanceFare);

  // 4. Multi-Seat total rider fare
  const totalRiderFare = baseFarePerSeat * seats;

  // 5. Detour compensation math (+3 Coins per 500m past 500m threshold)
  let detourUnits = 0;
  let detourCompensation = 0.0;
  const detourRate = cache.DETOUR_COINS_PER_500M || DEFAULTS.DETOUR_COINS_PER_500M;

  if (detourMeters > 500) {
    detourUnits = Math.ceil(detourMeters / 500);
    detourCompensation = detourUnits * detourRate;
  }

  // 6. Driver total earning
  const driverTotalEarnings = totalRiderFare + detourCompensation;

  return {
    distance_km: Number(distanceKm.toFixed(2)),
    vehicle_type: normType,
    rate_per_km: ratePerKm,
    min_fare_per_seat: minFarePerSeat,
    base_fare_per_seat: baseFarePerSeat,
    seats_requested: seats,
    total_rider_fare: totalRiderFare,
    detour_meters: Math.round(detourMeters),
    detour_units_500m: detourUnits,
    detour_compensation_coins: detourCompensation,
    driver_total_earnings: driverTotalEarnings,
    trust_score_bonus: detourCompensation > 0 ? 5 : 0,
    badge_awarded: detourCompensation > 0 ? 'Extra Mile Champion' : null,
  };
}

// ============================================================
// SUBTASK 2.3: 3-TIER WALLET WATERFALL & OVERDRAFT CHECKER
// Source: SRS §11.2, §12.3
// ============================================================

/**
 * Fetches user wallet balance + role profile.
 */
async function getWallet(userId) {
  const { data: wallet, error: walletErr } = await supabaseAdmin
    .from('wallets')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (walletErr) throw new Error(`Wallet not found for user ${userId}: ${walletErr.message}`);

  const { data: user } = await supabaseAdmin
    .from('users')
    .select('id, full_name, role, trust_score, work_email, work_email_verified')
    .eq('id', userId)
    .single();

  return {
    wallet,
    user: user || {},
  };
}

/**
 * Checks if a user has sufficient balance to book a ride using the 3-Tier Waterfall:
 *   Tier 1: Corporate Grant Balance
 *   Tier 2: Personal Available Balance
 *   Tier 3: 30-Coin Overdraft Cushion (Recurring Commutes Only)
 */
async function checkSufficiency(userId, requiredCoins, isRecurring = false) {
  const { wallet, user } = await getWallet(userId);
  const cache = getSettingsCache();
  const maxOverdraft = cache.MAX_RECURRING_OVERDRAFT_COINS || DEFAULTS.MAX_RECURRING_OVERDRAFT_COINS;

  const grantBalance = Number(wallet.corporate_grant_balance || 0);
  const availableBalance = Number(wallet.available_balance || 0);
  const lockedBalance = Number(wallet.locked_balance || 0);
  const totalSpendable = availableBalance; // available_balance includes grant + personal

  const trustScore = Number(user.trust_score || 50);
  const isEligibleForOverdraft = isRecurring && trustScore >= 50;
  const effectiveCapacity = isEligibleForOverdraft ? totalSpendable + maxOverdraft : totalSpendable;

  const sufficient = effectiveCapacity >= requiredCoins;
  const shortfall = sufficient ? 0 : Number((requiredCoins - effectiveCapacity).toFixed(2));
  const overdraftApplied = (sufficient && totalSpendable < requiredCoins)
    ? Number((requiredCoins - totalSpendable).toFixed(2))
    : 0;

  return {
    sufficient,
    required_coins: requiredCoins,
    available_balance: availableBalance,
    grant_balance: grantBalance,
    locked_balance: lockedBalance,
    is_recurring: isRecurring,
    overdraft_eligible: isEligibleForOverdraft,
    max_overdraft_allowed: isEligibleForOverdraft ? maxOverdraft : 0,
    overdraft_applied: overdraftApplied,
    shortfall,
    message: sufficient
      ? (overdraftApplied > 0 ? `Approved with ${overdraftApplied} Coins recurring overdraft cushion.` : 'Wallet balance sufficient.')
      : `Insufficient coins. Shortfall of ${shortfall} Coins.`,
  };
}

// ============================================================
// SUBTASK 2.4: DOUBLE-ENTRY LEDGER HISTORY & PAGINATION
// Source: SRS §12.5
// ============================================================

/**
 * Queries double-entry coin transactions with dynamic credit/debit tagging.
 */
async function getTransactions(userId, options = {}) {
  const { limit = 20, offset = 0, type = null } = options;

  let query = supabaseAdmin
    .from('coin_transactions')
    .select(`
      id,
      sender_id,
      receiver_id,
      amount,
      transaction_type,
      ride_id,
      request_id,
      created_at,
      status,
      sender:sender_id(full_name),
      receiver:receiver_id(full_name)
    `)
    .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
    .order('created_at', { ascending: false })
    .range(Number(offset), Number(offset) + Number(limit) - 1);

  if (type) {
    query = query.eq('transaction_type', type);
  }

  const { data, error, count } = await query;
  if (error) throw error;

  // Format double-entry ledger direction and UI color tokens
  const formatted = (data || []).map((tx) => {
    const isReceiver = tx.receiver_id === userId;
    const direction = isReceiver ? 'credit' : 'debit';
    const sign = isReceiver ? '+' : '-';
    const color = isReceiver ? 'green' : 'red';

    let displayTitle = 'Coin Transaction';
    switch (tx.transaction_type) {
      case 'ride_earning':
      case 'single_dropoff_fare':
        displayTitle = isReceiver ? 'Ride Earnings Received 🚗' : 'Ride Fare Paid 🚗';
        break;
      case 'corporate_grant':
        displayTitle = 'Monthly Employer Commute Grant 🎁';
        break;
      case 'escrow_lock':
        displayTitle = 'Ride Booking Escrow Hold 🔒';
        break;
      case 'escrow_refund':
        displayTitle = 'Escrow Refund Credited ↩️';
        break;
      case 'late_cancel_fee':
        displayTitle = isReceiver ? 'Late Cancellation Fee Received ⏱️' : 'Late Cancellation Fee Paid ⏱️';
        break;
      case 'peer_transfer':
        displayTitle = isReceiver ? `Gift from ${tx.sender?.full_name || 'Colleague'} 💝` : `Gift to ${tx.receiver?.full_name || 'Colleague'} 💝`;
        break;
      default:
        displayTitle = tx.transaction_type.replace(/_/g, ' ').toUpperCase();
    }

    return {
      id: tx.id,
      amount: tx.amount,
      direction,
      sign,
      color,
      display_title: displayTitle,
      transaction_type: tx.transaction_type,
      ride_id: tx.ride_id,
      request_id: tx.request_id,
      created_at: tx.created_at,
      status: tx.status,
    };
  });

  return {
    transactions: formatted,
    total_count: count || formatted.length,
    offset: Number(offset),
    limit: Number(limit),
  };
}

// ============================================================
// ADDITIONAL FEATURES: PEER TRANSFER & SUMMARY WIDGET
// Source: SRS §12.7, Flutter Dashboard Header
// ============================================================

/**
 * 1-Tap Colleague Coin Gift Transfer (peer_transfer).
 */
async function transferCoins(senderId, recipientIdentifier, amount, note = '') {
  const cache = getSettingsCache();
  const minTransfer = cache.MIN_PEER_TRANSFER_COINS || DEFAULTS.MIN_PEER_TRANSFER_COINS;
  const maxTransfer = cache.MAX_PEER_TRANSFER_COINS || DEFAULTS.MAX_PEER_TRANSFER_COINS;

  const numAmount = parseFloat(amount);
  if (isNaN(numAmount) || numAmount < minTransfer || numAmount > maxTransfer) {
    throw new Error(`Transfer amount must be between ${minTransfer} and ${maxTransfer} Coins.`);
  }

  // 1. Check sender balance
  const { wallet: senderWallet, user: senderUser } = await getWallet(senderId);
  if (senderWallet.available_balance < numAmount) {
    throw new Error(`Insufficient available balance. You have ${senderWallet.available_balance} Coins.`);
  }

  // 2. Locate verified colleague recipient by email or phone
  const cleanIdentifier = recipientIdentifier.trim().toLowerCase();
  const { data: recipient, error: recipErr } = await supabaseAdmin
    .from('users')
    .select('id, full_name, work_email, phone_number, company_id')
    .or(`work_email.eq.${cleanIdentifier},phone_number.eq.${cleanIdentifier}`)
    .single();

  if (recipErr || !recipient) {
    throw new Error(`Recipient colleague not found for '${recipientIdentifier}'.`);
  }

  if (recipient.id === senderId) {
    throw new Error('You cannot transfer coins to yourself.');
  }

  // 3. Single ACID RPC call — debit + credit + ledger in one PostgreSQL transaction.
  // Replaces the two separate UPDATE calls that had a crash/race-condition risk.
  // Stored procedure: 019_peer_transfer_rpc.sql → transfer_peer_coins()
  const idempotencyKey = `peer_transfer_${senderId}_${recipient.id}_${Date.now()}`;
  const { data: rpcResult, error: rpcErr } = await supabaseAdmin.rpc('transfer_peer_coins', {
    p_sender_id:       senderId,
    p_receiver_id:     recipient.id,
    p_amount:          numAmount,
    p_idempotency_key: idempotencyKey,
  });

  if (rpcErr) throw new Error(`Peer transfer failed: ${rpcErr.message}`);

  // Re-fetch sender's new balance for the response payload.
  const { data: updatedSenderWallet } = await supabaseAdmin
    .from('wallets')
    .select('available_balance')
    .eq('user_id', senderId)
    .single();

  // 4. Send celebratory in-app notification to recipient.
  await supabaseAdmin.from('notifications').insert({
    user_id: recipient.id,
    title: '💝 Colleague Coin Gift Received!',
    body: `${senderUser.full_name || 'A colleague'} sent you ${numAmount} Karma Coins! "${note || 'Thank you for carpooling!'}"`,
    type: 'coins_received',
  });

  return {
    success: true,
    amount_transferred: numAmount,
    recipient_name: recipient.full_name,
    recipient_email: recipient.work_email,
    new_sender_balance: Number((updatedSenderWallet?.available_balance || 0).toFixed(2)),
    transaction_id: rpcResult?.transaction_id || null,
  };
}

/**
 * Lightweight summary for Flutter dashboard widget banner.
 */
async function getWalletSummary(userId) {
  const { wallet, user } = await getWallet(userId);

  // Fetch carpool ride count from corporate_attendance for CO2 savings estimate.
  // Table: corporate_attendance (014_production_schema.sql, TABLE 15)
  // Note: There is no esg_carbon_logs table — CO2 is derived from carpool attendance records.
  // Estimate: Each carpool saves approx 2.1 kg CO2 vs solo car commute (IPCC average).
  // Fetch carpool attendance count to compute lifetime CO2 saved
  // Formula: average commute 12.5km * 0.15kg = ~1.88 kg CO2 saved per carpool trip
  const { count: carpoolTrips } = await supabaseAdmin
    .from('corporate_attendance')
    .select('*', { count: 'exact', head: true })
    .eq('employee_id', userId)
    .eq('transport_mode', 'carpool');

  const totalCo2Kg = (carpoolTrips || 0) * 1.88;

  return {
    user_id: userId,
    full_name: user.full_name,
    available_coins: Number(wallet.available_balance || 0),
    corporate_grant_remaining: Number(wallet.corporate_grant_balance || 0),
    locked_escrow: Number(wallet.locked_balance || 0),
    lifetime_earned: Number(wallet.lifetime_earned || 0),
    trust_score: Number(user.trust_score || 50),
    co2_saved_kg: Number(totalCo2Kg.toFixed(2)),
  };
}

module.exports = {
  // Subtask 2.1
  initSettingsCache,
  getSettingsCache,
  refreshSettingsCache,
  // Subtask 2.2
  calculateFare,
  // Subtask 2.3
  getWallet,
  checkSufficiency,
  // Subtask 2.4
  getTransactions,
  // Subtask 2.5 (Additional)
  transferCoins,
  getWalletSummary,
};

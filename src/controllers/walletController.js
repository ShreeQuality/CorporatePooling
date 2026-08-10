// ============================================================
// Wallet Controller — Corporate Pooling App
// Coin balance, transaction history, admin coin credit
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { ok, badRequest, serverError } = require('../utils/response');

/**
 * GET /wallet
 * Returns coin balance + summary stats
 */
async function getWallet(req, res) {
  try {
    const { data, error } = await supabaseAdmin
      .from('users')
      .select('coin_balance, total_coins_earned, total_rides_given, total_rides_taken, karma_score')
      .eq('id', req.user.id)
      .single();

    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

/**
 * GET /wallet/transactions
 * Paginated coin transaction history
 */
async function getTransactions(req, res) {
  try {
    const { limit = 30, offset = 0, type } = req.query;

    let query = supabaseAdmin
      .from('coin_transactions')
      .select('id, type, amount, balance_after, description, ride_id, created_at')
      .eq('user_id', req.user.id)
      .order('created_at', { ascending: false })
      .range(parseInt(offset), parseInt(offset) + parseInt(limit) - 1);

    if (type) query = query.eq('type', type);

    const { data, error } = await query;
    if (error) return serverError(res, error);
    return ok(res, data);
  } catch (err) {
    return serverError(res, err);
  }
}

/**
 * POST /wallet/credit  (Admin only — grant coins to user)
 * Body: { user_id, amount, reason }
 */
async function creditCoins(req, res) {
  try {
    const { user_id, amount, reason } = req.body;
    if (!user_id || !amount || amount <= 0) return badRequest(res, 'user_id and positive amount required');

    const { error } = await supabaseAdmin.rpc('credit_coins', {
      p_user_id: user_id,
      p_amount: parseInt(amount),
      p_description: reason || 'Admin credit',
    });

    if (error) return serverError(res, error, 'Failed to credit coins');
    return ok(res, null, `${amount} coins credited to user`);
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = { getWallet, getTransactions, creditCoins };

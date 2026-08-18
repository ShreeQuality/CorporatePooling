// ============================================================
// Wallet Controller — Corporate Pooling Backend
// REST API handlers for 3-Tier Wallet, Fare Quote, Double-Entry Ledger & Colleague Gifts
// Source of Truth: SRS §4.9, §5.3, §11.2, §12.5, §12.7, §14
// ============================================================

'use strict';

const walletService = require('../services/walletService');
const { ok, badRequest, serverError } = require('../utils/response');

/**
 * GET /api/v1/wallet
 * Returns full 3-tier balances (Grant, Available, Locked), role & profile info.
 */
async function getWalletDetails(req, res) {
  try {
    const userId = req.user.id;
    const walletData = await walletService.getWallet(userId);
    return ok(res, walletData, 'Wallet profile retrieved successfully');
  } catch (err) {
    return serverError(res, err, 'Failed to fetch wallet details');
  }
}

/**
 * GET /api/v1/wallet/summary
 * Lightweight summary for Flutter dashboard widget banner.
 */
async function getSummary(req, res) {
  try {
    const userId = req.user.id;
    const summary = await walletService.getWalletSummary(userId);
    return ok(res, summary, 'Wallet summary banner data retrieved');
  } catch (err) {
    return serverError(res, err, 'Failed to fetch wallet summary');
  }
}

/**
 * GET /api/v1/wallet/transactions
 * Paginated double-entry ledger history with dynamic credit/debit tagging.
 */
async function getTransactions(req, res) {
  try {
    const userId = req.user.id;
    const { limit = 20, offset = 0, type } = req.query;

    const result = await walletService.getTransactions(userId, {
      limit: parseInt(limit, 10),
      offset: parseInt(offset, 10),
      type: type || null,
    });

    return ok(res, result, 'Transaction history retrieved');
  } catch (err) {
    return serverError(res, err, 'Failed to fetch transaction history');
  }
}

/**
 * POST /api/v1/wallet/fare-estimate
 * Pure mathematical fare estimate for ride search cards & booking sheets.
 * Body: { distance_km, vehicle_type, detour_meters, seats_requested }
 */
async function getFareEstimate(req, res) {
  try {
    const { distance_km, vehicle_type = 'car', detour_meters = 0, seats_requested = 1 } = req.body;

    if (distance_km === undefined || distance_km === null || isNaN(parseFloat(distance_km))) {
      return badRequest(res, 'Valid distance_km (number) is required for fare calculation.');
    }

    const estimate = walletService.calculateFare(
      parseFloat(distance_km),
      vehicle_type,
      parseFloat(detour_meters) || 0,
      parseInt(seats_requested, 10) || 1
    );

    return ok(res, estimate, 'Fare estimate calculated successfully');
  } catch (err) {
    return serverError(res, err, 'Failed to calculate fare estimate');
  }
}

/**
 * GET /api/v1/wallet/check-balance
 * Pre-flight booking sufficiency check enforcing 3-Tier Waterfall & Overdraft logic.
 * Query: ?required_coins=25&is_recurring=false
 */
async function checkBalance(req, res) {
  try {
    const userId = req.user.id;
    const { required_coins, is_recurring } = req.query;

    if (!required_coins || isNaN(parseFloat(required_coins))) {
      return badRequest(res, 'Valid required_coins query parameter is required.');
    }

    const isRecurringBool = is_recurring === 'true' || is_recurring === true || is_recurring === '1';
    const result = await walletService.checkSufficiency(
      userId,
      parseFloat(required_coins),
      isRecurringBool
    );

    return ok(res, result, result.message);
  } catch (err) {
    return serverError(res, err, 'Failed to perform balance sufficiency check');
  }
}

/**
 * POST /api/v1/wallet/transfer
 * 1-Tap Colleague Coin Gift transfer (peer_transfer) with thank-you note.
 * Body: { recipient: "colleague@company.com" or "+919876543210", amount: 15, note: "Thanks for the ride!" }
 */
async function transferCoins(req, res) {
  try {
    const senderId = req.user.id;
    const { recipient, amount, note } = req.body;

    if (!recipient || !recipient.trim()) {
      return badRequest(res, 'Recipient email or phone number is required.');
    }

    if (!amount || isNaN(parseFloat(amount))) {
      return badRequest(res, 'Valid coin amount is required.');
    }

    const result = await walletService.transferCoins(
      senderId,
      recipient,
      parseFloat(amount),
      note || ''
    );

    return ok(res, result, `Successfully sent ${amount} Karma Coins to colleague.`);
  } catch (err) {
    return badRequest(res, err.message);
  }
}

module.exports = {
  getWalletDetails,
  getSummary,
  getTransactions,
  getFareEstimate,
  checkBalance,
  transferCoins,
};

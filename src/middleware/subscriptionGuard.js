// ============================================================
// Subscription Guard Middleware
// Checks if the user's company still has an active subscription
// Corporate users get 90-day free trial, then need paid plan
// Public users are always allowed (no company subscription needed)
// ============================================================

'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { paymentRequired, serverError } = require('../utils/response');

/**
 * For corporate users: check if their company subscription is still active.
 * Public users (no company_id) pass through freely.
 * Attach req.company to the request on success.
 */
async function checkSubscription(req, res, next) {
  try {
    // Public users have no company — no subscription check needed
    if (!req.user?.company_id) return next();

    const { data: company, error } = await supabaseAdmin
      .from('companies')
      .select('id, name, subscription_status, trial_ends_at, is_active')
      .eq('id', req.user.company_id)
      .single();

    if (error || !company) {
      // Can't verify subscription — fail open (allow, log warning)
      console.warn(`[subscriptionGuard] Could not fetch company ${req.user.company_id}:`, error?.message);
      return next();
    }

    if (!company.is_active) {
      return paymentRequired(res, 'Your company account has been deactivated. Contact support.');
    }

    // Trial check
    if (company.subscription_status === 'trial') {
      const trialEnd = new Date(company.trial_ends_at);
      if (trialEnd < new Date()) {
        return paymentRequired(
          res,
          `Your company's 90-day free trial has expired. Please upgrade to continue.`
        );
      }
    }

    // Expired subscription
    if (company.subscription_status === 'expired') {
      return paymentRequired(res, 'Your company subscription has expired. Please renew to continue.');
    }

    req.company = company;
    next();
  } catch (err) {
    return serverError(res, err, 'Subscription check failed');
  }
}

module.exports = { checkSubscription };

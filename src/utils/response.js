// ============================================================
// Standard API Response Helpers
// Always return consistent JSON shape:
// { success, data, message, error }
// ============================================================

'use strict';

/**
 * 200 OK
 */
function ok(res, data, message = 'Success') {
  return res.status(200).json({ success: true, message, data });
}

/**
 * 201 Created
 */
function created(res, data, message = 'Created successfully') {
  return res.status(201).json({ success: true, message, data });
}

/**
 * 400 Bad Request
 */
function badRequest(res, message = 'Bad request', errors = null) {
  return res.status(400).json({ success: false, message, errors });
}

/**
 * 401 Unauthorized
 */
function unauthorized(res, message = 'Unauthorized') {
  return res.status(401).json({ success: false, message });
}

/**
 * 402 Payment Required (subscription expired)
 */
function paymentRequired(res, message = 'Subscription expired') {
  return res.status(402).json({ success: false, message, code: 'SUBSCRIPTION_EXPIRED' });
}

/**
 * 403 Forbidden
 */
function forbidden(res, message = 'Forbidden') {
  return res.status(403).json({ success: false, message });
}

/**
 * 404 Not Found
 */
function notFound(res, message = 'Not found') {
  return res.status(404).json({ success: false, message });
}

/**
 * 409 Conflict
 */
function conflict(res, message = 'Conflict') {
  return res.status(409).json({ success: false, message });
}

/**
 * 422 Unprocessable Entity (validation)
 */
function validationError(res, message, errors = null) {
  return res.status(422).json({ success: false, message, errors });
}

/**
 * 500 Internal Server Error
 */
function serverError(res, err, message = 'Internal server error') {
  console.error('[ServerError]', err);
  return res.status(500).json({
    success: false,
    message,
    ...(process.env.NODE_ENV === 'development' && { debug: err?.message }),
  });
}

module.exports = { ok, created, badRequest, unauthorized, paymentRequired, forbidden, notFound, conflict, validationError, serverError };

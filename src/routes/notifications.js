// ============================================================
// Notification Routes — /api/v1/notifications/*
// Source of Truth: SRS §16 (Notification Pipeline)
// ============================================================
// POST   /fcm-token            → Subtask 5.6: Register / refresh FCM device token
// GET    /my-notifications     → Paginated in-app inbox (bell icon feed)
// PATCH  /:id/read             → Mark a single notification as read
// POST   /mark-all-read        → Mark entire inbox as read
// GET    /unread-count         → Badge count for Flutter app bar
// ============================================================

'use strict';

const router = require('express').Router();
const { requireAuth } = require('../middleware/auth');
const { supabaseAdmin } = require('../config/supabase');

// ─── Validation helpers ──────────────────────────────────────

const ALLOWED_PLATFORMS = ['android', 'ios', 'web'];

function ok(res, data, statusCode = 200) {
  return res.status(statusCode).json({ success: true, ...data });
}
function fail(res, message, statusCode = 400) {
  return res.status(statusCode).json({ success: false, message });
}

// ============================================================
// SUBTASK 5.6 — POST /fcm-token
// Register or refresh the caller's FCM device push token.
// Called by Flutter on: app launch, token refresh, login.
// Body: { fcm_token: string, platform: "android" | "ios" | "web" }
// ============================================================

router.post('/fcm-token', requireAuth, async (req, res) => {
  try {
    const { fcm_token, platform } = req.body;
    const userId = req.user.id;

    // ─── Input validation ───────────────────────────────────
    if (!fcm_token || typeof fcm_token !== 'string' || fcm_token.trim().length < 10) {
      return fail(res, 'fcm_token is required and must be a valid token string.');
    }
    if (!platform || !ALLOWED_PLATFORMS.includes(platform)) {
      return fail(res, `platform is required. Must be one of: ${ALLOWED_PLATFORMS.join(', ')}.`);
    }

    // ─── Upsert into users table ────────────────────────────
    const { error } = await supabaseAdmin
      .from('users')
      .update({
        fcm_token: fcm_token.trim(),
        fcm_token_platform: platform,
        fcm_token_updated_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) {
      console.error('[NotificationRoute] FCM token update error:', error.message);
      return fail(res, 'Failed to save FCM token. Please try again.', 500);
    }

    console.log(`[NotificationRoute] FCM token registered for user ${userId} (${platform})`);
    return ok(res, {
      message: 'FCM token registered successfully.',
      platform,
      updated_at: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[NotificationRoute] POST /fcm-token error:', err.message);
    return fail(res, 'Internal server error', 500);
  }
});

// ============================================================
// GET /my-notifications
// Returns paginated list of caller's notifications (bell feed).
// Query params:
//   ?page=1         (default: 1)
//   ?limit=20       (default: 20, max: 50)
//   ?unread_only=true
// ============================================================

router.get('/my-notifications', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const unreadOnly = req.query.unread_only === 'true';
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('notifications')
      .select('id, title, body, type, deep_link_route, ride_id, data, is_read, created_at', { count: 'exact' })
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (unreadOnly) {
      query = query.eq('is_read', false);
    }

    const { data: notifications, error, count } = await query;

    if (error) {
      console.error('[NotificationRoute] Inbox fetch error:', error.message);
      return fail(res, 'Failed to fetch notifications.', 500);
    }

    return ok(res, {
      notifications: notifications || [],
      pagination: {
        page,
        limit,
        total: count || 0,
        total_pages: Math.ceil((count || 0) / limit),
        has_next: offset + limit < (count || 0),
      },
    });
  } catch (err) {
    console.error('[NotificationRoute] GET /my-notifications error:', err.message);
    return fail(res, 'Internal server error', 500);
  }
});

// ============================================================
// PATCH /:id/read
// Mark a single notification as read.
// Only the owner can mark their own notification.
// ============================================================

router.patch('/:id/read', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // UUID format validation
    const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!UUID_REGEX.test(id)) {
      return fail(res, 'Invalid notification ID format.');
    }

    const { data, error } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id)
      .eq('user_id', userId)   // ownership enforced at query level (belt + RLS)
      .select('id, is_read')
      .single();

    if (error || !data) {
      return fail(res, 'Notification not found or not owned by you.', 404);
    }

    return ok(res, { message: 'Notification marked as read.', notification: data });
  } catch (err) {
    console.error('[NotificationRoute] PATCH /:id/read error:', err.message);
    return fail(res, 'Internal server error', 500);
  }
});

// ============================================================
// POST /mark-all-read
// Mark the caller's entire unread inbox as read at once.
// ============================================================

router.post('/mark-all-read', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;

    const { error, count } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', userId)
      .eq('is_read', false);

    if (error) {
      console.error('[NotificationRoute] mark-all-read error:', error.message);
      return fail(res, 'Failed to mark notifications as read.', 500);
    }

    return ok(res, {
      message: 'All notifications marked as read.',
      updated_count: count || 0,
    });
  } catch (err) {
    console.error('[NotificationRoute] POST /mark-all-read error:', err.message);
    return fail(res, 'Internal server error', 500);
  }
});

// ============================================================
// GET /unread-count
// Lightweight badge count — called by Flutter AppBar on focus.
// Returns a single number, not the full list.
// ============================================================

router.get('/unread-count', requireAuth, async (req, res) => {
  try {
    const userId = req.user.id;

    const { count, error } = await supabaseAdmin
      .from('notifications')
      .select('*', { count: 'exact', head: true })  // head:true = count-only, no rows returned
      .eq('user_id', userId)
      .eq('is_read', false);

    if (error) {
      console.error('[NotificationRoute] unread-count error:', error.message);
      return fail(res, 'Failed to fetch unread count.', 500);
    }

    return ok(res, { unread_count: count || 0 });
  } catch (err) {
    console.error('[NotificationRoute] GET /unread-count error:', err.message);
    return fail(res, 'Internal server error', 500);
  }
});

module.exports = router;

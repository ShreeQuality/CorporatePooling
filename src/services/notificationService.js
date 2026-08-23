// ============================================================
// Notification Service — Corporate Pooling App
// Source of Truth: SRS §16 (Notification Pipeline) & §17.6 (Emergency SOS)
// ============================================================
// SUBTASK 5.1 — Firebase Admin SDK with Zero-Crash Mock Mode
// SUBTASK 5.2 — Priority Channel Routing & Sound Chimes
// SUBTASK 5.3 — Deep-Link Payload Generator
// SUBTASK 5.4 — Multicast Bulk Dispatcher (500-batch chunks)
// SUBTASK 5.5 — Emergency SOS Broadcaster (Push + Twilio SMS)
// ============================================================

'use strict';

const path = require('path');
const { supabaseAdmin } = require('../config/supabase');
require('dotenv').config();

// ─── Subtask 5.1: Firebase Admin SDK Init ────────────────────
// Zero-Crash philosophy: if credentials are missing (dev / CI env),
// service runs in MOCK MODE — logs payloads + writes to Supabase
// notifications table — without crashing the server.

let firebaseApp = null;
let fcmClient = null;   // firebase-admin messaging instance
let MOCK_MODE = false;

(function initFirebase() {
  try {
    const admin = require('firebase-admin');

    // Already initialized guard (hot-reload safe)
    if (admin.apps && admin.apps.length > 0) {
      firebaseApp = admin.apps[0];
      fcmClient = admin.messaging(firebaseApp);
      console.log('[NotificationService] Firebase Admin already initialized ✓');
      return;
    }

    const credPath = path.resolve(
      __dirname, '..', 'config', 'firebase-service-account.json'
    );

    // Attempt to load service account credentials
    const serviceAccount = require(credPath);

    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    fcmClient = admin.messaging(firebaseApp);
    console.log('[NotificationService] Firebase Admin SDK initialized ✓ (Live FCM Mode)');
  } catch (err) {
    // Missing or invalid credentials → run in Zero-Crash Mock Mode
    MOCK_MODE = true;
    console.warn(
      '[NotificationService] ⚠️  Firebase credentials not found — running in MOCK MODE.',
      '\n  To enable live FCM: add src/config/firebase-service-account.json',
      '\n  Error:', err.message
    );
  }
})();

// ─── Subtask 5.2: Priority Channel Map (SRS §16.2) ───────────
// Maps notification type → Android channel + sound + priority

const CHANNEL_MAP = {
  // Life-safety: bypasses silent mode on Android
  sos_emergency:     { channel: 'sos_emergency',   sound: 'siren.mp3',      priority: 'high',   androidPriority: 'max'    },
  // Ride lifecycle events: time-sensitive
  ride_request:      { channel: 'ride_alerts',     sound: 'chime_high.mp3', priority: 'high',   androidPriority: 'high'   },
  request_accepted:  { channel: 'ride_alerts',     sound: 'chime_high.mp3', priority: 'high',   androidPriority: 'high'   },
  driver_arrived:    { channel: 'ride_alerts',     sound: 'chime_high.mp3', priority: 'high',   androidPriority: 'high'   },
  ride_completed:    { channel: 'ride_alerts',     sound: 'chime_high.mp3', priority: 'normal', androidPriority: 'normal' },
  ride_cancelled:    { channel: 'ride_alerts',     sound: 'chime_high.mp3', priority: 'high',   androidPriority: 'high'   },
  search_alert_match:{ channel: 'ride_alerts',     sound: 'chime_high.mp3', priority: 'high',   androidPriority: 'high'   },
  // Coin economy events
  coins_received:    { channel: 'coin_alerts',     sound: 'coin_drop.mp3',  priority: 'normal', androidPriority: 'normal' },
  grant_airdrop:     { channel: 'coin_alerts',     sound: 'coin_drop.mp3',  priority: 'normal', androidPriority: 'normal' },
  // Generic / KYC / Admin
  kyc_approved:      { channel: 'general',         sound: 'default',        priority: 'normal', androidPriority: 'normal' },
  kyc_rejected:      { channel: 'general',         sound: 'default',        priority: 'normal', androidPriority: 'normal' },
  system:            { channel: 'general',         sound: 'default',        priority: 'low',    androidPriority: 'low'    },
};

function getChannel(notificationType) {
  return CHANNEL_MAP[notificationType] || CHANNEL_MAP.system;
}

// ─── Subtask 5.3: Deep-Link Payload Generator (SRS §16.3) ────
// Flutter reads `deep_link` from the data payload on tap.

const DEEP_LINK_TEMPLATES = {
  ride_request:       (d) => `/driver/requests/${d.request_id}`,
  request_accepted:   (d) => `/rider/live/${d.ride_id}`,
  driver_arrived:     (d) => `/rider/boarding/${d.ride_id}`,
  ride_completed:     (d) => `/rating/${d.ride_id}`,
  ride_cancelled:     (d) => `/rides`,
  coins_received:     ()  => `/wallet`,
  grant_airdrop:      ()  => `/wallet`,
  search_alert_match: (d) => `/rider/book/${d.ride_id}`,
  sos_emergency:      (d) => `/admin/sos/${d.incident_id}`,
  kyc_approved:       ()  => `/profile/kyc`,
  kyc_rejected:       ()  => `/profile/kyc`,
  system:             ()  => `/home`,
};

function buildDeepLink(notificationType, data = {}) {
  const generator = DEEP_LINK_TEMPLATES[notificationType];
  return generator ? generator(data) : '/home';
}

// ─── Internal: Persist to Supabase notifications inbox ───────
// Always written regardless of FCM success, so the in-app bell
// never misses a notification even if the device is offline.

async function _writeToInbox(userId, title, body, notificationType, deepLinkRoute, rideId = null, extraData = {}) {
  const { error } = await supabaseAdmin.from('notifications').insert({
    user_id: userId,
    title,
    body,
    type: notificationType,
    deep_link_route: deepLinkRoute,
    ride_id: rideId || null,
    data: extraData,
    is_read: false,
  });

  if (error) {
    console.warn('[NotificationService] Failed to write to notifications inbox:', error.message);
  }
}

// ─── Internal: Build FCM Message ─────────────────────────────

function _buildFcmMessage(fcmToken, title, body, notificationType, deepLink, extraData = {}) {
  const ch = getChannel(notificationType);

  return {
    token: fcmToken,
    notification: { title, body },
    data: {
      type: notificationType,
      deep_link: deepLink,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      ...Object.fromEntries(
        Object.entries(extraData).map(([k, v]) => [k, String(v)])
      ),
    },
    android: {
      priority: ch.androidPriority,
      notification: {
        channel_id: ch.channel,
        sound: ch.sound !== 'default' ? ch.sound : undefined,
        notification_priority: `PRIORITY_${ch.androidPriority.toUpperCase()}`,
      },
    },
    apns: {
      headers: {
        'apns-priority': ch.priority === 'high' ? '10' : '5',
        'apns-push-type': ch.priority === 'high' ? 'alert' : 'background',
      },
      payload: {
        aps: {
          sound: ch.sound !== 'default' ? ch.sound : 'default',
          'interruption-level': ch.androidPriority === 'max' ? 'critical' : 'active',
        },
      },
    },
  };
}

// ─────────────────────────────────────────────────────────────
// PRIMARY FUNCTION: sendPushNotification
// Use this for all 1-to-1 notification sends.
// ─────────────────────────────────────────────────────────────

/**
 * Send a push notification to a single user.
 *
 * @param {string} userId - UUID of recipient from public.users
 * @param {string} title  - Notification title
 * @param {string} body   - Notification body text
 * @param {string} notificationType - Maps to CHANNEL_MAP & DEEP_LINK_TEMPLATES key
 * @param {object} data   - Extra data (ride_id, request_id, incident_id, etc.)
 * @returns {Promise<{ success: boolean, mode: string, messageId?: string }>}
 */
async function sendPushNotification(userId, title, body, notificationType = 'system', data = {}) {
  const deepLink = buildDeepLink(notificationType, data);

  // 1. Always persist to in-app notification inbox (offline-safe)
  await _writeToInbox(userId, title, body, notificationType, deepLink, data.ride_id, data);

  // 2. Look up the user's FCM token
  const { data: user, error: userErr } = await supabaseAdmin
    .from('users')
    .select('fcm_token, fcm_token_platform, full_name')
    .eq('id', userId)
    .single();

  if (userErr || !user?.fcm_token) {
    // No FCM token registered (user never opened app after install, or logged out)
    console.log(`[NotificationService] No FCM token for user ${userId} — inbox-only delivery.`);
    return { success: true, mode: 'inbox_only', reason: 'no_fcm_token' };
  }

  // 3. Mock Mode — log and return without hitting FCM
  if (MOCK_MODE) {
    console.log(`[NotificationService] 📲 MOCK PUSH → ${user.full_name || userId}`);
    console.log(`  Type: ${notificationType} | Title: ${title}`);
    console.log(`  DeepLink: ${deepLink} | Channel: ${getChannel(notificationType).channel}`);
    return { success: true, mode: 'mock', deep_link: deepLink };
  }

  // 4. Live FCM v1 send
  try {
    const message = _buildFcmMessage(user.fcm_token, title, body, notificationType, deepLink, data);
    const messageId = await fcmClient.send(message);
    return { success: true, mode: 'live_fcm', messageId };
  } catch (fcmErr) {
    console.error('[NotificationService] FCM send error:', fcmErr.message);
    // Inbox already written — partial success
    return { success: false, mode: 'live_fcm', error: fcmErr.message };
  }
}

// ─── Subtask 5.4: Multicast Bulk Dispatcher ──────────────────
// For pg_cron triggers: grant airdrops, nightly commute broadcasts.
// Google FCM allows max 500 tokens per multicast call.

/**
 * Send the same notification to a large list of users.
 * Automatically chunks into FCM-compliant 500-recipient batches.
 *
 * @param {string[]} userIds - Array of user UUIDs
 * @param {string} title
 * @param {string} body
 * @param {string} notificationType
 * @param {object} data
 * @returns {Promise<{ total: number, sent: number, failed: number }>}
 */
async function sendBulkPushNotifications(userIds, title, body, notificationType = 'system', data = {}) {
  if (!userIds || userIds.length === 0) return { total: 0, sent: 0, failed: 0 };

  const deepLink = buildDeepLink(notificationType, data);
  const ch = getChannel(notificationType);

  // 1. Batch-write to inbox for all users (single insert)
  const inboxRows = userIds.map((uid) => ({
    user_id: uid,
    title,
    body,
    type: notificationType,
    deep_link_route: deepLink,
    ride_id: data.ride_id || null,
    data,
    is_read: false,
  }));

  const { error: inboxErr } = await supabaseAdmin
    .from('notifications')
    .insert(inboxRows);

  if (inboxErr) {
    console.warn('[NotificationService] Bulk inbox write error:', inboxErr.message);
  }

  // 2. Fetch FCM tokens for all recipients in one query
  const { data: users } = await supabaseAdmin
    .from('users')
    .select('id, fcm_token')
    .in('id', userIds)
    .not('fcm_token', 'is', null);

  const tokens = (users || []).map((u) => u.fcm_token).filter(Boolean);
  if (tokens.length === 0 || MOCK_MODE) {
    console.log(`[NotificationService] Bulk MOCK/inbox-only: ${userIds.length} users, ${tokens.length} FCM tokens.`);
    return { total: userIds.length, sent: tokens.length, failed: 0 };
  }

  // 3. Chunk into 500-token batches (Google FCM hard limit)
  const BATCH_SIZE = 500;
  let totalSent = 0;
  let totalFailed = 0;

  for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
    const batch = tokens.slice(i, i + BATCH_SIZE);
    try {
      const multicastMsg = {
        tokens: batch,
        notification: { title, body },
        data: {
          type: notificationType,
          deep_link: deepLink,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        },
        android: {
          priority: ch.androidPriority,
          notification: { channel_id: ch.channel },
        },
      };

      const response = await fcmClient.sendEachForMulticast(multicastMsg);
      totalSent += response.successCount;
      totalFailed += response.failureCount;

      // Clean up stale tokens that returned UNREGISTERED
      if (response.failureCount > 0) {
        const staleTokens = [];
        response.responses.forEach((r, idx) => {
          if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
            staleTokens.push(batch[idx]);
          }
        });
        if (staleTokens.length > 0) {
          await supabaseAdmin
            .from('users')
            .update({ fcm_token: null, fcm_token_updated_at: new Date().toISOString() })
            .in('fcm_token', staleTokens);
        }
      }
    } catch (batchErr) {
      console.error(`[NotificationService] Batch ${i}–${i + BATCH_SIZE} error:`, batchErr.message);
      totalFailed += batch.length;
    }
  }

  console.log(`[NotificationService] Bulk dispatch complete: ${totalSent} sent, ${totalFailed} failed.`);
  return { total: userIds.length, sent: totalSent, failed: totalFailed };
}

// ─── Subtask 5.5: Emergency SOS Broadcaster (SRS §17.6) ──────
// Called when a rider taps the SOS button during an active ride.
// 1. MAX-priority push to driver + all Super Admins.
// 2. Reads emergency_contacts JSONB from public.users.
// 3. Sends Twilio SMS to each contact with GPS tracking link.
// 4. Updates public.emergency_sos_incidents.family_notified_count.

/**
 * Broadcast emergency SOS — full multi-channel dispatch.
 *
 * @param {string} incidentId - UUID of row in public.emergency_sos_incidents
 * @returns {Promise<{ push_sent: number, sms_sent: number, sms_failed: number }>}
 */
async function broadcastEmergencySOS(incidentId) {
  // 1. Fetch the incident details
  const { data: incident, error: incidentErr } = await supabaseAdmin
    .from('emergency_sos_incidents')
    .select('id, ride_id, triggered_by, driver_id, trigger_lat, trigger_lng, vehicle_plate')
    .eq('id', incidentId)
    .single();

  if (incidentErr || !incident) {
    throw new Error(`SOS incident not found: ${incidentId}`);
  }

  const mapsLink = `https://maps.google.com/?q=${incident.trigger_lat},${incident.trigger_lng}`;

  // 2. Fetch rider profile (who triggered SOS) + their emergency contacts
  const { data: rider } = await supabaseAdmin
    .from('users')
    .select('full_name, emergency_contacts')
    .eq('id', incident.triggered_by)
    .single();

  const riderName = rider?.full_name || 'Unknown Rider';
  const emergencyContacts = Array.isArray(rider?.emergency_contacts)
    ? rider.emergency_contacts
    : [];

  // 3. MAX-priority push to driver
  await sendPushNotification(
    incident.driver_id,
    '🚨 EMERGENCY — SOS ALERT!',
    `${riderName} has triggered an SOS. Stay calm. Help is on the way.`,
    'sos_emergency',
    { incident_id: incidentId, ride_id: incident.ride_id }
  );

  // 4. MAX-priority push to all Super Admins
  const { data: admins } = await supabaseAdmin
    .from('users')
    .select('id')
    .eq('role', 'super_admin');

  const adminIds = (admins || []).map((a) => a.id);
  if (adminIds.length > 0) {
    await sendBulkPushNotifications(
      adminIds,
      '🚨 SOS INCIDENT REPORTED',
      `${riderName} triggered an emergency in ride ${incident.ride_id}. Vehicle: ${incident.vehicle_plate}. Location: ${mapsLink}`,
      'sos_emergency',
      { incident_id: incidentId, ride_id: incident.ride_id }
    );
  }

  let smsSent = 0;
  let smsFailed = 0;

  // 5. Twilio SMS to emergency contacts
  if (emergencyContacts.length > 0) {
    let twilioClient = null;
    try {
      const twilio = require('twilio');
      const accountSid = process.env.TWILIO_ACCOUNT_SID;
      const authToken = process.env.TWILIO_AUTH_TOKEN;
      const fromNumber = process.env.TWILIO_PHONE_NUMBER;

      if (accountSid && authToken && fromNumber) {
        twilioClient = twilio(accountSid, authToken);
      } else {
        console.warn('[NotificationService] Twilio credentials missing — SOS SMS in MOCK MODE.');
      }
    } catch (twilioLoadErr) {
      console.warn('[NotificationService] Twilio not loaded:', twilioLoadErr.message);
    }

    for (const contact of emergencyContacts) {
      const phone = contact.phone || contact.phone_number;
      if (!phone) continue;

      const smsBody =
        `🚨 EMERGENCY ALERT: ${riderName} (your ${contact.relation || 'contact'}) ` +
        `has triggered an SOS during a carpool ride.\n` +
        `Live Location: ${mapsLink}\n` +
        `Vehicle: ${incident.vehicle_plate}\n` +
        `Please call them immediately. — Corporate Pooling Safety`;

      if (!twilioClient || MOCK_MODE) {
        console.log(`[NotificationService] MOCK SMS → ${phone}: ${smsBody.substring(0, 80)}...`);
        smsSent++;
        continue;
      }

      try {
        await twilioClient.messages.create({
          body: smsBody,
          from: process.env.TWILIO_PHONE_NUMBER,
          to: phone,
        });
        smsSent++;
      } catch (smsErr) {
        console.error(`[NotificationService] SMS to ${phone} failed:`, smsErr.message);
        smsFailed++;
      }
    }
  }

  // 6. Update incident row with notified count
  await supabaseAdmin
    .from('emergency_sos_incidents')
    .update({
      family_notified_count: smsSent,
      status: 'active',
    })
    .eq('id', incidentId);

  const result = {
    push_sent: 1 + adminIds.length, // driver + admins
    sms_sent: smsSent,
    sms_failed: smsFailed,
    emergency_contacts_count: emergencyContacts.length,
  };

  console.log(`[NotificationService] SOS Broadcast complete for incident ${incidentId}:`, result);
  return result;
}

// ─── Exports ─────────────────────────────────────────────────

module.exports = {
  // Primary send function (1-to-1)
  sendPushNotification,
  // Bulk multicast (for pg_cron grant airdrops / nightly broadcasts)
  sendBulkPushNotifications,
  // Life-safety SOS dispatcher
  broadcastEmergencySOS,
  // Utility helpers (exposed for testing)
  buildDeepLink,
  getChannel,
  isMockMode: () => MOCK_MODE,
};

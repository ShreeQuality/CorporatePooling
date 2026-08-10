// ============================================================
// File Upload Middleware (Multer)
// Handles Aadhaar, Driving Licence, Profile Photo uploads
// Files are stored in memory then uploaded to Supabase Storage
// ============================================================

'use strict';

const multer = require('multer');
const { badRequest } = require('../utils/response');

// Store in memory buffer (we upload to Supabase Storage from buffer)
const storage = multer.memoryStorage();

// Allowed MIME types for documents
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
const MAX_SIZE_BYTES = 5 * 1024 * 1024; // 5MB

const fileFilter = (req, file, cb) => {
  if (ALLOWED_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`File type not allowed. Allowed: JPEG, PNG, WebP, PDF`), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: MAX_SIZE_BYTES },
});

/**
 * Multer error handler — converts multer errors to standard API response
 */
function handleUploadError(err, req, res, next) {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return badRequest(res, 'File too large. Maximum size is 5MB.');
    }
    return badRequest(res, `Upload error: ${err.message}`);
  }
  if (err) {
    return badRequest(res, err.message);
  }
  next();
}

module.exports = { upload, handleUploadError };

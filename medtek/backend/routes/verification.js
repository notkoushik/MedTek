// routes/verification.js
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const auth = require('../middleware/auth');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Configure multer for document uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadsDir = 'uploads/verification-documents';
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'doc-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|pdf/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only images and PDF files are allowed!'));
    }
  }
});

// POST /verification/submit-doctor - Submit doctor verification request
router.post('/submit-doctor', auth, upload.array('documents', 5), async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      medical_license_number,
      license_authority,
      hospital_affiliation,
      notes
    } = req.body;

    // Check if user is a doctor
    const userCheck = await pool.query(
      'SELECT role FROM users WHERE id = $1',
      [userId]
    );

    if (userCheck.rows.length === 0 || userCheck.rows[0].role !== 'doctor') {
      return res.status(403).json({ error: 'Only doctors can submit verification' });
    }

    // Check if already verified
    const existingVerification = await pool.query(
      'SELECT verified FROM users WHERE id = $1',
      [userId]
    );

    if (existingVerification.rows[0].verified) {
      return res.status(400).json({ error: 'Doctor already verified' });
    }

    // Store uploaded documents
    const documents = req.files ? req.files.map(file => ({
      filename: file.filename,
      originalname: file.originalname,
      path: file.path,
      mimetype: file.mimetype,
      size: file.size
    })) : [];

    // Create verification request
    const result = await pool.query(
      `INSERT INTO verification_requests 
       (user_id, medical_license_number, license_authority, hospital_affiliation, documents, notes, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')
       RETURNING *`,
      [userId, medical_license_number, license_authority, hospital_affiliation, JSON.stringify(documents), notes]
    );

    // Update user verification status
    await pool.query(
      `UPDATE users SET verification_status = 'under_review' WHERE id = $1`,
      [userId]
    );

    res.json({
      success: true,
      message: 'Verification request submitted successfully',
      request: result.rows[0]
    });
  } catch (e) {
    console.error('Submit verification error:', e);
    res.status(500).json({ error: 'Failed to submit verification' });
  }
});

// GET /verification/status - Get verification status
router.get('/status', auth, async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await pool.query(
      `SELECT 
         vr.*,
         u.verified,
         u.verification_status
       FROM verification_requests vr
       LEFT JOIN users u ON vr.user_id = u.id
       WHERE vr.user_id = $1
       ORDER BY vr.submitted_at DESC
       LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.json({
        verified: false,
        verification_status: 'not_submitted',
        request: null
      });
    }

    res.json({
      verified: result.rows[0].verified,
      verification_status: result.rows[0].verification_status,
      request: result.rows[0]
    });
  } catch (e) {
    console.error('Get verification status error:', e);
    res.status(500).json({ error: 'Failed to get verification status' });
  }
});

// GET /verification/pending - Get all pending verifications (Admin only)
router.get('/pending', auth, async (req, res) => {
  try {
    // Check if user is admin
    const userCheck = await pool.query(
      'SELECT role FROM users WHERE id = $1',
      [req.user.id]
    );

    if (userCheck.rows[0].role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const result = await pool.query(
      `SELECT 
         vr.*,
         u.name,
         u.email,
         u.role
       FROM verification_requests vr
       JOIN users u ON vr.user_id = u.id
       WHERE vr.status = 'pending'
       ORDER BY vr.submitted_at ASC`
    );

    res.json({ requests: result.rows });
  } catch (e) {
    console.error('Get pending verifications error:', e);
    res.status(500).json({ error: 'Failed to get pending verifications' });
  }
});

// POST /verification/approve/:requestId - Approve verification (Admin only)
router.post('/approve/:requestId', auth, async (req, res) => {
  try {
    const { requestId } = req.params;
    const adminId = req.user.id;

    // Check if user is admin
    const userCheck = await pool.query(
      'SELECT role FROM users WHERE id = $1',
      [adminId]
    );

    if (userCheck.rows[0].role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    // Get verification request
    const requestResult = await pool.query(
      'SELECT * FROM verification_requests WHERE id = $1',
      [requestId]
    );

    if (requestResult.rows.length === 0) {
      return res.status(404).json({ error: 'Verification request not found' });
    }

    const request = requestResult.rows[0];

    // Update verification request
    await pool.query(
      `UPDATE verification_requests 
       SET status = 'approved', reviewed_at = NOW(), reviewed_by = $1
       WHERE id = $2`,
      [adminId, requestId]
    );

    // Update user as verified
    await pool.query(
      `UPDATE users 
       SET verified = TRUE, 
           verification_status = 'verified',
           medical_license_number = $1,
           license_issuing_authority = $2,
           verified_at = NOW(),
           verified_by = $3
       WHERE id = $4`,
      [request.medical_license_number, request.license_authority, adminId, request.user_id]
    );

    res.json({
      success: true,
      message: 'Doctor verified successfully'
    });
  } catch (e) {
    console.error('Approve verification error:', e);
    res.status(500).json({ error: 'Failed to approve verification' });
  }
});

// POST /verification/reject/:requestId - Reject verification (Admin only)
router.post('/reject/:requestId', auth, async (req, res) => {
  try {
    const { requestId } = req.params;
    const { reason } = req.body;
    const adminId = req.user.id;

    // Check if user is admin
    const userCheck = await pool.query(
      'SELECT role FROM users WHERE id = $1',
      [adminId]
    );

    if (userCheck.rows[0].role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    // Get verification request
    const requestResult = await pool.query(
      'SELECT user_id FROM verification_requests WHERE id = $1',
      [requestId]
    );

    if (requestResult.rows.length === 0) {
      return res.status(404).json({ error: 'Verification request not found' });
    }

    // Update verification request
    await pool.query(
      `UPDATE verification_requests 
       SET status = 'rejected', 
           reviewed_at = NOW(), 
           reviewed_by = $1,
           rejection_reason = $2
       WHERE id = $3`,
      [adminId, reason, requestId]
    );

    // Update user status
    await pool.query(
      `UPDATE users 
       SET verification_status = 'rejected'
       WHERE id = $1`,
      [requestResult.rows[0].user_id]
    );

    res.json({
      success: true,
      message: 'Verification rejected'
    });
  } catch (e) {
    console.error('Reject verification error:', e);
    res.status(500).json({ error: 'Failed to reject verification' });
  }
});

module.exports = router;

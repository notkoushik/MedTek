const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const auth = require('../middleware/auth');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Create uploads directory if it doesn't exist
const uploadsDir = 'uploads/profile-pictures';
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure multer for profile picture uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'profile-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only image files are allowed!'));
    }
  }
});

// ---------- AUTH ROUTES ----------

// GET /users/me
router.get('/me', auth, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, email, role, profile_picture FROM users WHERE id = $1',
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ user: result.rows[0] });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------- PROFILE PICTURE UPLOAD ----------

// POST /users/:id/upload-profile-picture
router.post('/:id/upload-profile-picture', auth, upload.single('profile_picture'), async (req, res) => {
  try {
    const userId = req.params.id;

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const filename = req.file.filename;

    const result = await pool.query(
      'UPDATE users SET profile_picture = $1 WHERE id = $2 RETURNING id, name, email, role, profile_picture',
      [filename, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = result.rows[0];

    res.json({
      success: true,
      profile_picture: filename,
      url: `/uploads/profile-pictures/${filename}`,
      user
    });
  } catch (e) {
    console.error('Upload error:', e);
    res.status(500).json({ error: 'Failed to upload profile picture' });
  }
});

// ---------- USER PROFILE ROUTES ----------

// GET /users/:id
router.get('/:id', async (req, res) => {
  try {
    const userId = req.params.id;

    const result = await pool.query(
      'SELECT id, name, email, role, profile_picture FROM users WHERE id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });
  } catch (e) {
    console.error('GET /users/:id error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /users/:id - Update user profile
router.patch('/:id', auth, async (req, res) => {
  try {
    const userId = req.params.id;
    const { name, profile_picture } = req.body;

    const updates = [];
    const values = [];
    let paramCount = 1;

    if (name !== undefined) {
      updates.push(`name = $${paramCount++}`);
      values.push(name);
    }
    if (profile_picture !== undefined) {
      updates.push(`profile_picture = $${paramCount++}`);
      values.push(profile_picture);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(userId);
    const query = `
      UPDATE users 
      SET ${updates.join(', ')}
      WHERE id = $${paramCount}
      RETURNING id, name, email, role, profile_picture
    `;

    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ success: true, user: result.rows[0] });
  } catch (e) {
    console.error('PATCH /users/:id error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ---------- PATIENT PROFILE ROUTES ----------

// GET /users/:id/profile
router.get('/:id/profile', auth, async (req, res) => {
  try {
    const userId = req.params.id;

    const result = await pool.query(
      `SELECT
         u.id,
         u.name,
         u.email,
         u.role,
         u.profile_picture,
         pp.age,
         pp.reference_notes,
         pp.insurances,
         pd.doctor_id,
         d.name AS doctor_name
       FROM users u
       LEFT JOIN patient_profiles pp ON u.id = pp.user_id
       LEFT JOIN patient_doctors pd ON u.id = pd.patient_id
       LEFT JOIN users d ON pd.doctor_id = d.id
       WHERE u.id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (e) {
    console.error('GET /users/:id/profile error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /users/:id/profile
router.patch('/:id/profile', auth, async (req, res) => {
  try {
    const userId = req.params.id;
    const { age, references, insurances } = req.body;

    await pool.query(
      `INSERT INTO patient_profiles (user_id, age, reference_notes, insurances)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id)
       DO UPDATE SET
         age = EXCLUDED.age,
         reference_notes = EXCLUDED.reference_notes,
         insurances = EXCLUDED.insurances`,
      [userId, age || 0, JSON.stringify(references || []), JSON.stringify(insurances || [])]
    );

    res.json({ success: true, message: 'Profile updated' });
  } catch (e) {
    console.error('PATCH /users/:id/profile error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /users/:patientId/assign-doctor
router.post('/:patientId/assign-doctor', auth, async (req, res) => {
  try {
    const patientId = req.params.patientId;
    const { doctorId } = req.body;

    if (!doctorId) {
      return res.status(400).json({ error: 'Doctor ID required' });
    }

    await pool.query(
      `INSERT INTO patient_doctors (patient_id, doctor_id)
       VALUES ($1, $2)
       ON CONFLICT (patient_id)
       DO UPDATE SET doctor_id = EXCLUDED.doctor_id`,
      [patientId, doctorId]
    );

    res.json({ success: true, message: 'Doctor assigned successfully' });
  } catch (e) {
    console.error('POST /users/:patientId/assign-doctor error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

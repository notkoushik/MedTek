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
         pp.weight,
         pp.height,
         pp.gender,
         pp.blood_group,
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
    const { age, weight, height, gender, blood_group, references, insurances } = req.body;

    await pool.query(
      `INSERT INTO patient_profiles (user_id, age, weight, height, gender, blood_group, reference_notes, insurances)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (user_id)
       DO UPDATE SET
         age = COALESCE(EXCLUDED.age, patient_profiles.age),
         weight = COALESCE(EXCLUDED.weight, patient_profiles.weight),
         height = COALESCE(EXCLUDED.height, patient_profiles.height),
         gender = COALESCE(EXCLUDED.gender, patient_profiles.gender),
         blood_group = COALESCE(EXCLUDED.blood_group, patient_profiles.blood_group),
         reference_notes = COALESCE(EXCLUDED.reference_notes, patient_profiles.reference_notes),
         insurances = COALESCE(EXCLUDED.insurances, patient_profiles.insurances)`,
      [
        userId,
        age || null,
        weight || null,
        height || null,
        gender || null,
        blood_group || null,
        references ? JSON.stringify(references) : null,
        insurances ? JSON.stringify(insurances) : null
      ]
    );

    res.json({ success: true, message: 'Profile updated' });
  } catch (e) {
    console.error('PATCH /users/:id/profile error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /users/assign-hospital
router.post('/assign-hospital', auth, async (req, res) => {
  try {
    const { hospital_id, google_place_id, name, address, city, latitude, longitude } = req.body;

    let targetHospitalId = hospital_id;

    if (!targetHospitalId) {
      if (!name && !google_place_id) {
        return res.status(400).json({ error: 'Hospital ID or details required' });
      }

      // 1. Check existing via Google Place ID
      if (google_place_id) {
        const hRes = await pool.query('SELECT id FROM hospitals WHERE google_place_id = $1', [google_place_id]);
        if (hRes.rows.length > 0) targetHospitalId = hRes.rows[0].id;
      }

      // 2. Create if not found
      if (!targetHospitalId) {
        if (!name || !latitude || !longitude) {
          return res.status(400).json({ error: 'New hospital requires name, lat, lng' });
        }
        // Use ON CONFLICT to handle race conditions or re-insertion safely
        const insertRes = await pool.query(
          `INSERT INTO hospitals (name, address, city, latitude, longitude, google_place_id)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (google_place_id) DO UPDATE SET name = EXCLUDED.name
           RETURNING id`,
          [name, address || '', city || '', latitude, longitude, google_place_id || null]
        );
        targetHospitalId = insertRes.rows[0].id;
      }
    }

    // 3. Update User
    await pool.query(
      'UPDATE users SET assigned_hospital_id = $1 WHERE id = $2',
      [targetHospitalId, req.user.id]
    );

    res.json({ success: true, hospital_id: targetHospitalId });
  } catch (e) {
    console.error('Assign hospital error:', e);
    res.status(500).json({ error: 'Failed to assign hospital' });
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

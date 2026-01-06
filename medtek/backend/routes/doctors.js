// routes/doctors.js
const express = require('express');
const router = express.Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ✅ GET /doctors/my-hospital - MUST be BEFORE /:id routes
router.get('/my-hospital', auth, async (req, res) => {
  try {
    const doctorId = req.user.id;

    const result = await pool.query(
      `SELECT 
        h.id,
        h.name,
        h.address,
        h.city,
        h.latitude,
        h.longitude
       FROM doctors d
       JOIN hospitals h ON d.hospital_id = h.id
       WHERE d.user_id = $1`,
      [doctorId]
    );

    if (result.rows.length === 0) {
      console.log(`⚠️ No hospital found for doctor ${doctorId}`);
      return res.status(404).json({ hospital: null });
    }

    console.log(`✅ Doctor ${doctorId} has hospital: ${result.rows[0].name}`);

    res.json({ 
      success: true,
      hospital: result.rows[0] 
    });
  } catch (e) {
    console.error('GET /doctors/my-hospital error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ✅ GET /doctors/trending - MUST be BEFORE /:id routes
router.get('/trending', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT 
        u.id, u.name, u.email,
        d.specialization,
        d.experience_years,
        h.name as hospital_name,
        CAST(COALESCE(AVG(dr.rating), 0) AS DECIMAL(3,2)) as rating,
        CAST(COUNT(dr.id) AS INTEGER) as review_count,
        d.verified
       FROM users u
       JOIN doctors d ON u.id = d.user_id
       LEFT JOIN hospitals h ON d.hospital_id = h.id
       LEFT JOIN doctor_reviews dr ON u.id = dr.doctor_id
       WHERE u.role = 'doctor'
       GROUP BY u.id, u.name, u.email, d.specialization, d.experience_years, h.name, d.verified
       ORDER BY rating DESC, review_count DESC
       LIMIT 10`
    );

    res.json({ doctors: result.rows });
  } catch (e) {
    console.error('GET /doctors/trending error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ✅ GET /doctors/search - MUST be BEFORE /:id routes
router.get('/search', async (req, res) => {
  try {
    const { query } = req.query;
    
    let result;
    if (query) {
      result = await pool.query(
        `SELECT 
          u.id, u.name, u.email,
          d.specialization,
          d.experience_years,
          h.name as hospital_name,
          CAST(COALESCE(AVG(dr.rating), 0) AS DECIMAL(3,2)) as rating,
          CAST(COUNT(dr.id) AS INTEGER) as review_count
         FROM users u
         JOIN doctors d ON u.id = d.user_id
         LEFT JOIN hospitals h ON d.hospital_id = h.id
         LEFT JOIN doctor_reviews dr ON u.id = dr.doctor_id
         WHERE u.role = 'doctor'
           AND (u.name ILIKE $1 OR d.specialization ILIKE $1 OR h.name ILIKE $1)
         GROUP BY u.id, u.name, u.email, d.specialization, d.experience_years, h.name
         ORDER BY rating DESC, review_count DESC
         LIMIT 20`,
        [`%${query}%`]
      );
    } else {
      result = await pool.query(
        `SELECT 
          u.id, u.name, u.email,
          d.specialization,
          d.experience_years,
          h.name as hospital_name,
          CAST(COALESCE(AVG(dr.rating), 0) AS DECIMAL(3,2)) as rating,
          CAST(COUNT(dr.id) AS INTEGER) as review_count
         FROM users u
         JOIN doctors d ON u.id = d.user_id
         LEFT JOIN hospitals h ON d.hospital_id = h.id
         LEFT JOIN doctor_reviews dr ON u.id = dr.doctor_id
         WHERE u.role = 'doctor'
         GROUP BY u.id, u.name, u.email, d.specialization, d.experience_years, h.name
         ORDER BY rating DESC, review_count DESC
         LIMIT 20`
      );
    }

    res.json({ doctors: result.rows });
  } catch (e) {
    console.error('GET /doctors/search error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ✅ POST /doctors/select-hospital
router.post('/select-hospital', auth, async (req, res) => {
  console.log('✅ POST /doctors/select-hospital called');
  console.log('req.user:', req.user);
  console.log('req.body:', req.body);

  try {
    if (!req.user || !req.user.id) {
      console.error('❌ select-hospital: missing req.user');
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const doctorId = req.user.id;
    const {
      google_place_id,
      name,
      address,
      city,
      latitude,
      longitude,
    } = req.body;

    if (!google_place_id || !name || !latitude || !longitude) {
      console.error('❌ Missing hospital data:', req.body);
      return res.status(400).json({ error: 'Missing hospital data' });
    }

    // Check if hospital exists by google_place_id OR name
    let hospResult = await pool.query(
      'SELECT id FROM hospitals WHERE google_place_id = $1 OR name = $2',
      [google_place_id, name]
    );

    let hospitalId;
    if (hospResult.rows.length > 0) {
      // Hospital exists
      hospitalId = hospResult.rows[0].id;
      console.log(`✅ Hospital exists: ${name} (ID: ${hospitalId})`);
    } else {
      // Create new hospital
      hospResult = await pool.query(
        `INSERT INTO hospitals (google_place_id, name, address, city, latitude, longitude)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id`,
        [google_place_id, name, address || '', city || 'India', latitude, longitude]
      );
      hospitalId = hospResult.rows[0].id;
      console.log(`✅ New hospital created: ${name} (ID: ${hospitalId})`);
    }

    // Link doctor to hospital
    await pool.query(
      `INSERT INTO doctors (user_id, hospital_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE SET hospital_id = EXCLUDED.hospital_id`,
      [doctorId, hospitalId]
    );

    console.log(`✅ Doctor ${doctorId} linked to hospital ${hospitalId}`);

    // ✅ Fetch and return complete hospital data
    const hospitalData = await pool.query(
      `SELECT id, name, address, city, latitude, longitude 
       FROM hospitals 
       WHERE id = $1`,
      [hospitalId]
    );

    console.log('✅ Returning hospital data:', hospitalData.rows[0]);

    return res.json({ 
      success: true, 
      hospitalId,
      hospital: hospitalData.rows[0] // ✅ Return full hospital object
    });
  } catch (err) {
    console.error('❌ select-hospital error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// routes/doctors.js

// ✅ PATCH /doctors/profile - Update doctor profile (ADD THIS)
router.patch('/profile', auth, async (req, res) => {
  console.log('📝 PATCH /doctors/profile');
  console.log('User ID:', req.user.id);
  console.log('Body:', req.body);

  try {
    const userId = req.user.id;
    const { specialization, experience_years, about } = req.body;

    // Update doctors table
    await pool.query(
      `UPDATE doctors 
       SET specialization = COALESCE($1, specialization),
           experience_years = COALESCE($2, experience_years),
           about = COALESCE($3, about)
       WHERE user_id = $4`,
      [specialization, experience_years, about, userId]
    );

    console.log('✅ Doctors table updated');

    // Get complete updated data with hospital
    const result = await pool.query(
      `SELECT 
        u.id,
        u.name,
        u.email,
        u.role,
        u.profile_picture,
        d.specialization,
        d.experience_years,
        d.about,
        d.verified,
        h.id as hospital_id,
        h.name as hospital_name,
        h.address as hospital_address,
        h.city as hospital_city,
        h.latitude,
        h.longitude
       FROM users u
       JOIN doctors d ON u.id = d.user_id
       LEFT JOIN hospitals h ON d.hospital_id = h.id
       WHERE u.id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    const doctor = result.rows[0];

    // Format response
    const response = {
      id: doctor.id,
      name: doctor.name,
      email: doctor.email,
      role: doctor.role,
      profile_picture: doctor.profile_picture,
      profile_picture_url: doctor.profile_picture 
        ? `/uploads/profile-pictures/${doctor.profile_picture}`
        : null,
      specialization: doctor.specialization,
      experience_years: doctor.experience_years,
      about: doctor.about,
      verified: doctor.verified,
      selected_hospital_id: doctor.hospital_id,
      selected_hospital_name: doctor.hospital_name,
      hospital: doctor.hospital_id ? {
        id: doctor.hospital_id,
        name: doctor.hospital_name,
        address: doctor.hospital_address,
        city: doctor.hospital_city,
        latitude: doctor.latitude,
        longitude: doctor.longitude,
      } : null,
    };

    console.log('✅ Returning updated user:', response);

    res.json({ 
      success: true, 
      user: response  // ✅ Return as 'user'
    });
  } catch (e) {
    console.error('❌ PATCH /doctors/profile error:', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ... rest of your routes below


// ✅ GET /doctors/:id/patients - Now safe to use :id
router.get('/:id/patients', async (req, res) => {
  try {
    const { status } = req.query;
    res.json({ items: [] });
  } catch (e) {
    console.error('GET /doctors/:id/patients error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ✅ POST /doctors/:id/reviews
router.post('/:id/reviews', auth, async (req, res) => {
  try {
    const doctorId = req.params.id;
    const patientId = req.user.id;
    const { rating, comment } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }

    await pool.query(
      `INSERT INTO doctor_reviews (doctor_id, patient_id, rating, comment)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (doctor_id, patient_id)
       DO UPDATE SET rating = EXCLUDED.rating, comment = EXCLUDED.comment`,
      [doctorId, patientId, rating, comment || '']
    );

    res.json({ success: true, message: 'Review submitted' });
  } catch (e) {
    console.error('POST /doctors/:id/reviews error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ✅ GET /doctors/:id/reviews
router.get('/:id/reviews', async (req, res) => {
  try {
    const doctorId = req.params.id;
    
    const result = await pool.query(
      `SELECT 
        dr.id,
        dr.rating,
        dr.comment,
        dr.created_at,
        u.name as patient_name
       FROM doctor_reviews dr
       JOIN users u ON dr.patient_id = u.id
       WHERE dr.doctor_id = $1
       ORDER BY dr.created_at DESC`,
      [doctorId]
    );

    res.json({ reviews: result.rows });
  } catch (e) {
    console.error('GET /doctors/:id/reviews error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

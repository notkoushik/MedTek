// routes/auth.js
const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../db'); // ✅ Use your db connection

// ✅ POST /auth/login - Return hospital data for doctors
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    // Get user
    const userResult = await pool.query(
      'SELECT * FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = userResult.rows[0];

    // Verify password
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET || 'dev-secret',
      { expiresIn: '7d' }
    );

    // ✅ Get hospital data if doctor
    let hospitalData = null;
    if (user.role === 'doctor') {
      const hospitalResult = await pool.query(
        `SELECT h.id, h.name, h.address, h.city, h.latitude, h.longitude
         FROM doctors d
         JOIN hospitals h ON d.hospital_id = h.id
         WHERE d.user_id = $1`,
        [user.id]
      );

      if (hospitalResult.rows.length > 0) {
        hospitalData = hospitalResult.rows[0];
        console.log(`✅ Login - Doctor has hospital: ${hospitalData.name}`);
      } else {
        console.log(`⚠️ Login - Doctor has NO hospital selected`);
      }
    }

    // ✅ Build response with hospital
    const userResponse = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      profile_picture: user.profile_picture,
      profile_picture_url: user.profile_picture 
        ? `/uploads/profile-pictures/${user.profile_picture}`
        : null,
      selected_hospital_id: hospitalData?.id || null,
      selected_hospital_name: hospitalData?.name || null,
      hospital: hospitalData, // ✅ Full hospital object
    };

    console.log(`✅ Login successful: ${user.email} (${user.role})`);

    res.json({
      success: true,
      token,
      user: userResponse,
    });
  } catch (e) {
    console.error('❌ Login error:', e);
    res.status(500).json({ error: 'Login failed' });
  }
});

// ✅ POST /auth/register
router.post('/register', async (req, res) => {
  try {
    const { name, email, password, role } = req.body;

    if (!name || !email || !password || !role) {
      return res.status(400).json({ error: 'All fields required' });
    }

    if (!['patient', 'doctor'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role' });
    }

    // Check existing
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: 'Email already registered' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const userResult = await pool.query(
      `INSERT INTO users (name, email, password_hash, role)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, email, role, profile_picture`,
      [name, email.toLowerCase(), hashedPassword, role]
    );

    const user = userResult.rows[0];

    // If doctor, create doctor entry
    if (role === 'doctor') {
      await pool.query(
        'INSERT INTO doctors (user_id) VALUES ($1)',
        [user.id]
      );
      console.log(`✅ Doctor entry created for user ${user.id}`);
    }

    // Generate token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET || 'dev-secret',
      { expiresIn: '7d' }
    );

    const userResponse = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      profile_picture: user.profile_picture,
      profile_picture_url: null,
      selected_hospital_id: null,
      selected_hospital_name: null,
      hospital: null,
    };

    console.log(`✅ Registration: ${user.email} (${user.role})`);

    res.json({
      success: true,
      token,
      user: userResponse,
    });
  } catch (e) {
    console.error('❌ Registration error:', e);
    res.status(500).json({ error: 'Registration failed' });
  }
});

module.exports = router;

// routes/drivers.js
const express = require('express');
const router = express.Router();
const pool = require('../db');

// GET /drivers/nearby
router.get('/nearby', async (req, res) => {
    try {
        const { lat, lng, radiusKm = 10 } = req.query;

        console.log(`📍 GET /drivers/nearby: lat=${lat}, lng=${lng}, r=${radiusKm}`);

        // Simple query: find all users with role 'driver'
        // in a real app, you'd filter by location logic (PostGIS or Haversine)
        const result = await pool.query(
            `SELECT u.id, u.name, u.email, u.role, u.profile_picture
       FROM users u
       WHERE u.role = 'driver'`
        );

        // Mock location for demo purposes if database doesn't have real location columns for users yet
        // or if we haven't implemented live driver tracking fully.
        const drivers = result.rows.map(d => ({
            ...d,
            current_lat: parseFloat(lat) + (Math.random() * 0.02 - 0.01),
            current_lng: parseFloat(lng) + (Math.random() * 0.02 - 0.01),
        }));

        console.log(`✅ Found ${drivers.length} nearby drivers`);
        res.json({ drivers });
    } catch (e) {
        console.error('GET /drivers/nearby error', e);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;

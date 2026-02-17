// routes/doctor-location.js
const express = require('express');
const router = express.Router();
const pool = require('../db');
const auth = require('../middleware/auth');

/**
 * POST /doctor/location
 * Save hospital location for logged-in doctor
 */
router.post('/location', auth, async (req, res) => {
    const client = await pool.connect();
    try {
        const userId = req.user.id;
        const { latitude, longitude, address } = req.body;

        if (latitude == null || longitude == null) {
            return res.status(400).json({
                error: 'latitude and longitude are required',
            });
        }

        await client.query('BEGIN');

        // 1️⃣ Get doctor's hospital_id
        const doctorRes = await client.query(
            `SELECT d.hospital_id
       FROM doctors d
       WHERE d.user_id = $1`,
            [userId]
        );

        if (doctorRes.rows.length === 0 || !doctorRes.rows[0].hospital_id) {
            await client.query('ROLLBACK');
            return res.status(400).json({
                error: 'Doctor has no hospital assigned. Please select a hospital first.',
            });
        }

        const hospitalId = doctorRes.rows[0].hospital_id;

        // 2️⃣ Update hospital location
        await client.query(
            `UPDATE hospitals
       SET latitude = $1,
           longitude = $2,
           address = COALESCE($3, address)
       WHERE id = $4`,
            [latitude, longitude, address || null, hospitalId]
        );

        await client.query('COMMIT');

        res.json({
            success: true,
            hospital_id: hospitalId,
            message: 'Hospital location updated successfully',
        });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Doctor location error:', err);
        res.status(500).json({ error: 'Failed to save doctor location' });
    } finally {
        client.release();
    }
});

module.exports = router;

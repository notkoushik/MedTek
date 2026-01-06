const express = require('express');
const router = express.Router();
const pool = require('../db');

// GET /activities/appointments
router.get('/appointments', async (req, res) => {
    try {
        const { userId, status } = req.query;

        if (!userId) {
            return res.status(400).json({ error: 'userId required' });
        }

        let query = `
      SELECT 
        a.id,
        a.appointment_date as datetime,
        a.status,
        a.reason,
        d.id as doctor_id,
        u_doc.name as doctor_name,
        h.name as hospital_name
      FROM appointments a
      LEFT JOIN doctors d ON a.doctor_id = d.id
      LEFT JOIN users u_doc ON d.user_id = u_doc.id
      LEFT JOIN hospitals h ON a.hospital_id = h.id
      WHERE a.user_id = $1
    `;

        const params = [userId];

        if (status && status.toLowerCase() !== 'all') {
            query += ` AND a.status = $2`;
            params.push(status.toLowerCase());
        }

        query += ` ORDER BY a.appointment_date DESC`;

        const result = await pool.query(query, params);

        // Map to match frontend expectations implicitly
        const items = result.rows.map(row => ({
            ...row,
            title: row.doctor_name ? `Dr. ${row.doctor_name}` : 'Appointment',
            date: row.datetime // Frontend checks both datetime and date
        }));

        res.json({ items });
    } catch (e) {
        console.error('GET /activities/appointments error', e);
        res.status(500).json({ error: 'Server error' });
    }
});

// GET /activities/rides
router.get('/rides', async (req, res) => {
    try {
        const { userId, status } = req.query;

        if (!userId) {
            return res.status(400).json({ error: 'userId required' });
        }

        let query = `SELECT * FROM rides WHERE rider_id = $1`;
        const params = [userId];

        if (status && status.toLowerCase() !== 'all') {
            query += ` AND status = $2`;
            params.push(status.toLowerCase());
        }

        query += ` ORDER BY created_at DESC`;

        const result = await pool.query(query, params);

        res.json({ items: result.rows });
    } catch (e) {
        console.error('GET /activities/rides error', e);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;

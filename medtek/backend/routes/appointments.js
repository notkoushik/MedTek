// routes/appointments.js
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// POST /appointments
router.post('/', async (req, res) => {
  try {
    const {
      user_id,
      doctor_id,
      hospital_id,
      appointment_date,
      reason,
      status = 'pending',
    } = req.body;

    if (!user_id || !doctor_id || !appointment_date) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await pool.query(
      `INSERT INTO appointments 
       (user_id, doctor_id, hospital_id, appointment_date, reason, status)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [user_id, doctor_id, hospital_id, appointment_date, reason, status]
    );

    res.status(201).json({ appointment: result.rows[0] });
  } catch (e) {
    console.error('POST /appointments error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /appointments/:id/triage-result
router.post('/:id/triage-result', async (req, res) => {
  try {
    const { id } = req.params;
    const { diagnosis, selectedTests, notes } = req.body;

    await pool.query(
      `UPDATE appointments
       SET triage_diagnosis = $1,
           triage_selected_tests = $2,
           triage_notes = $3,
           updated_at = NOW()
       WHERE id = $4`,
      [
        diagnosis || null,
        Array.isArray(selectedTests) ? selectedTests.join(',') : null,
        notes || null,
        id,
      ]
    );

    res.json({ success: true });
  } catch (e) {
    console.error('POST /appointments/:id/triage-result error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /appointments/pending - MUST come BEFORE generic GET /
router.get('/pending', async (req, res) => {
  try {
    const { doctor_id } = req.query;

    if (!doctor_id) {
      return res.status(400).json({ error: 'doctor_id required' });
    }

    const result = await pool.query(
      `SELECT a.*, u.name AS patient_name, u.email AS patient_email
       FROM appointments a
       LEFT JOIN users u ON a.user_id = u.id
       WHERE a.doctor_id = $1 AND a.status = $2
       ORDER BY a.appointment_date ASC`,
      [doctor_id, 'pending']
    );

    res.json({ appointments: result.rows });
  } catch (e) {
    console.error('GET /appointments/pending error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /appointments - Generic route MUST come AFTER specific routes
router.get('/', async (req, res) => {
  try {
    const { doctor_id } = req.query;

    if (!doctor_id) {
      return res.status(400).json({ error: 'doctor_id required' });
    }

    const result = await pool.query(
      `SELECT a.*, u.name AS patient_name, u.email AS patient_email
       FROM appointments a
       LEFT JOIN users u ON a.user_id = u.id
       WHERE a.doctor_id = $1
       ORDER BY a.appointment_date DESC`,
      [doctor_id]
    );

    res.json({ appointments: result.rows });
  } catch (e) {
    console.error('GET /appointments error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

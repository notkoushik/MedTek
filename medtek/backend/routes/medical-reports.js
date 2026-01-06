// routes/medical-reports.js
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const auth = require('../middleware/auth');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// POST /medical-reports
router.post('/', auth, async (req, res) => {
  try {
    const doctorId = req.user.id; // from JWT
    const {
      patient_id,
      appointment_id,
      diagnosis,
      prescription,
      lab_tests,           // can be a CSV or JSON string from Flutter
      notes,
      description_type,    // 'text' or 'image'
      description_text,
      description_image_url,
      status,
      report_status,
    } = req.body || {};

    if (!patient_id || !appointment_id) {
      return res
        .status(400)
        .json({ error: 'patient_id and appointment_id are required' });
    }

    const result = await pool.query(
      `INSERT INTO medical_reports (
         doctor_id,
         patient_id,
         appointment_id,
         diagnosis,
         prescription,
         lab_tests,
         lab_tests_count,
         notes,
         description_type,
         description_text,
         description_image_url,
         status,
         report_status
       )
       VALUES (
         $1, $2, $3, $4, $5, $6, $7,
         $8, $9, $10, $11, $12, $13
       )
       RETURNING id`,
      [
        doctorId,
        patient_id,
        appointment_id,
        diagnosis || '',
        prescription || '',
        Array.isArray(lab_tests) ? lab_tests.join(',') : (lab_tests || ''),
        Array.isArray(lab_tests) ? lab_tests.length : 0,
        notes || '',
        description_type || 'text',
        description_text || '',
        description_image_url || null,
        status || 'completed',
        report_status || 'completed',
      ]
    );

    res.status(201).json({ reportId: result.rows[0].id });
  } catch (e) {
    console.error('POST /medical-reports error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /medical-reports/mine
router.get('/mine', auth, async (req, res) => {
  try {
    const userId = req.user?.id; // from auth middleware
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const result = await pool.query(
      `SELECT id,
              doctor_id,
              patient_id,
              patient_name,
              patient_age,
              condition,
              triage_diagnosis,
              diagnosis,
              prescription,
              lab_tests,
              lab_tests_count,
              notes,
              description_type,
              description_text,
              description_image_url,
              status,
              report_status,
              created_at
       FROM medical_reports
       WHERE patient_id = $1
       ORDER BY created_at DESC`,
      [userId]
    );

    res.json({ reports: result.rows });
  } catch (e) {
    console.error('GET /medical-reports/mine error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

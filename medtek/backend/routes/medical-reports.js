// routes/medical-reports.js
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const auth = require('../middleware/auth');
const { resolveDoctorId } = require('../utils/doctorUtils');

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

    // ✅ Resolve Doctor ID (fk to doctors table)
    const finalDoctorId = await resolveDoctorId(pool, doctorId);

    if (!finalDoctorId) {
      console.error(`❌ Doctor not found for user_id ${doctorId}`);
      return res.status(400).json({ error: 'Doctor profile not found' });
    }

    // ✅ Fetch Patient Details for Snapshot
    let patientName = 'Unknown';
    let patientAge = 'N/A';

    try {
      const patResult = await pool.query(
        `SELECT u.name, pp.age 
         FROM users u 
         LEFT JOIN patient_profiles pp ON u.id = pp.user_id 
         WHERE u.id = $1`,
        [patient_id]
      );
      if (patResult.rows.length > 0) {
        patientName = patResult.rows[0].name || 'Unknown';
        patientAge = (patResult.rows[0].age || 'N/A').toString();
      }
    } catch (err) {
      console.error('Error fetching patient details for report snapshot:', err);
    }

    // ✅ Calculate lab tests count & JSON status
    let finalLabTestsStr = '';
    let finalLabTestsCount = 0;
    let finalLabTestsJson = {};

    if (Array.isArray(lab_tests)) {
      finalLabTestsStr = lab_tests.join(',');
      finalLabTestsCount = lab_tests.length;
      lab_tests.forEach(t => finalLabTestsJson[t.trim()] = 'pending');
    } else if (typeof lab_tests === 'string' && lab_tests.trim().length > 0) {
      finalLabTestsStr = lab_tests;
      const tests = lab_tests.split(',').map(t => t.trim()).filter(t => t.length > 0);
      finalLabTestsCount = tests.length;
      tests.forEach(t => finalLabTestsJson[t] = 'pending');
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
         report_status,
         patient_name,
         patient_age,
         lab_tests_json
       )
       VALUES (
         $1, $2, $3, $4, $5, $6, $7,
         $8, $9, $10, $11, $12, $13,
         $14, $15, $16
       )
       RETURNING id`,
      [
        finalDoctorId,
        patient_id,
        appointment_id,
        diagnosis || '',
        prescription || '',
        finalLabTestsStr,
        finalLabTestsCount,
        notes || '',
        description_type || 'text',
        description_text || '',
        description_image_url || null,
        status || 'completed',
        report_status || 'completed',
        patientName,
        patientAge,
        finalLabTestsJson
      ]
    );

    // ✅ NEW: Update appointment status based on lab tests
    // If tests ordered -> 'testing_in_progress' (so it stays in Active list showing "Testing in Progress")
    // If NO tests -> 'completed' (so it moves to Completed list)
    const newStatus = finalLabTestsCount > 0 ? 'testing_in_progress' : 'completed';

    await pool.query(
      `UPDATE appointments SET status = $1 WHERE id = $2`,
      [newStatus, appointment_id]
    );

    res.status(201).json({ reportId: result.rows[0].id });
  } catch (e) {
    console.error('POST /medical-reports error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ✅ PATCH /medical-reports/:id/test-status - Update single test status
router.patch('/:id/test-status', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { testName, status } = req.body; // status: 'done' | 'pending'

    if (!testName || !status) {
      return res.status(400).json({ error: 'testName and status are required' });
    }

    // 1. Get current JSON
    const currentRes = await pool.query(
      'SELECT lab_tests_json FROM medical_reports WHERE id = $1',
      [id]
    );

    if (currentRes.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    let labs = currentRes.rows[0].lab_tests_json || {};

    // 2. Update status
    if (labs[testName] !== undefined) {
      labs[testName] = status;
    } else {
      // Handle case where test name might strictly match or be new
      labs[testName] = status;
    }

    // 3. Save back
    await pool.query(
      'UPDATE medical_reports SET lab_tests_json = $1 WHERE id = $2',
      [labs, id]
    );

    res.json({ success: true, lab_tests_json: labs });

  } catch (e) {
    console.error('PATCH /test-status error', e);
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
              lab_tests_json,
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

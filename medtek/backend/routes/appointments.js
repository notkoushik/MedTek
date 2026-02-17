// routes/appointments.js
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const { resolveDoctorId } = require('../utils/doctorUtils');

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

    // ✅ Resolve doctor_id using utility
    const finalDoctorId = await resolveDoctorId(pool, doctor_id);

    if (!finalDoctorId) {
      console.error(`❌ Doctor ID ${doctor_id} not found in doctors table (as id or user_id)`);
      return res.status(400).json({ error: 'Doctor not found' });
    }

    // ✅ Check for existing appointment with same user + doctor + date
    const existingAppointment = await pool.query(
      `SELECT id FROM appointments 
       WHERE user_id = $1 
         AND doctor_id = $2 
         AND appointment_date::date = $3::date
         AND status != 'cancelled'`,
      [user_id, finalDoctorId, appointment_date]
    );

    if (existingAppointment.rows.length > 0) {
      return res.status(409).json({
        error: 'You already have an appointment with this doctor on this date',
        existing_appointment_id: existingAppointment.rows[0].id
      });
    }

    const result = await pool.query(
      `INSERT INTO appointments 
       (user_id, doctor_id, hospital_id, appointment_date, reason, status)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [user_id, finalDoctorId, hospital_id, appointment_date, reason, status]
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

    // RESOLVE DOCTOR ID (Handle user_id vs doctor_id confusion)
    const finalDoctorId = await resolveDoctorId(pool, doctor_id);
    if (!finalDoctorId) {
      // If we can't resolve it, try using the raw ID or return empty
      console.warn(`Could not resolve doctor ID for: ${doctor_id}`);
    }

    // UPDATED QUERY:
    // 1. Join medical_reports to check if a report exists for this appointment
    // 2. Filter: Only show appointments where status is 'pending' 
    //    AND (no report exists OR report status is 'awaiting_lab_results')
    //    Actually, user wants "Pending" list to basically mean "Not seen yet".
    //    So if a report exists, it shouldn't be here (it moves to Active/completed).

    const result = await pool.query(
      `SELECT a.*, 
              u.name AS patient_name, 
              u.email AS patient_email,
              mr.report_status,
              mr.id as report_id
       FROM appointments a
       LEFT JOIN users u ON a.user_id = u.id
       LEFT JOIN medical_reports mr ON a.id = mr.appointment_id
       WHERE a.doctor_id = $1 
         AND a.status = 'pending'
         AND mr.id IS NULL
       ORDER BY a.appointment_date ASC`,
      [finalDoctorId || doctor_id]
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
    const { doctor_id, date } = req.query;

    if (!doctor_id) {
      return res.status(400).json({ error: 'doctor_id required' });
    }

    // Resolve Doctor ID (handle user_id case)
    const finalDoctorId = await resolveDoctorId(pool, doctor_id);
    if (!finalDoctorId) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    let queryText = `
    SELECT
      a.*,
      u.name AS patient_name,
      u.profile_picture,
      pp.age AS patient_age,
      pp.weight,
      pp.height,
      pp.gender,
      pp.blood_group,
      mr.report_status,
      mr.lab_tests_count,
      mr.id as report_id,
      mr.diagnosis as triage_diagnosis,
      mr.lab_tests as triage_selected_tests
       FROM appointments a
       LEFT JOIN users u ON a.user_id = u.id
       LEFT JOIN patient_profiles pp ON u.id = pp.user_id
       LEFT JOIN medical_reports mr ON a.id = mr.appointment_id
       WHERE a.doctor_id = $1
      `;
    const queryParams = [finalDoctorId];

    if (date) {
      // Ensure date comparison is robust (ignoring time)
      queryText += ` AND a.appointment_date:: date = $2:: date`;
      queryParams.push(date);
    }

    queryText += ` ORDER BY a.appointment_date ASC`;

    const result = await pool.query(queryText, queryParams);

    res.json({ appointments: result.rows });
  } catch (e) {
    console.error('GET /appointments error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// ✅ PATCH /appointments/:id/status - Doctor accepts/declines booking
router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'confirmed' or 'declined'

    if (!status || !['confirmed', 'declined'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status. Use confirmed or declined' });
    }

    // Get appointment details first
    const apptRes = await pool.query(
      'SELECT doctor_id, appointment_date FROM appointments WHERE id = $1',
      [id]
    );

    if (apptRes.rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    const { doctor_id, appointment_date } = apptRes.rows[0];
    let queueNumber = null;

    // If confirming, calculate queue number for this doctor on this day
    if (status === 'confirmed') {
      const queueRes = await pool.query(
        `SELECT COALESCE(MAX(queue_number), 0) + 1 as next_queue
         FROM appointments 
         WHERE doctor_id = $1 
           AND appointment_date::date = $2::date
           AND status = 'confirmed'`,
        [doctor_id, appointment_date]
      );
      queueNumber = queueRes.rows[0].next_queue;
    }

    // Update the appointment
    const updateQuery = status === 'confirmed'
      ? `UPDATE appointments SET status = $1, queue_number = $2, updated_at = NOW() WHERE id = $3 RETURNING *`
      : `UPDATE appointments SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *`;

    const updateParams = status === 'confirmed'
      ? [status, queueNumber, id]
      : [status, id];

    const result = await pool.query(updateQuery, updateParams);

    console.log(`✅ Appointment ${id} ${status}${queueNumber ? ` - OP #${queueNumber}` : ''}`);

    res.json({
      success: true,
      appointment: result.rows[0],
      queue_number: queueNumber
    });
  } catch (e) {
    console.error('PATCH /appointments/:id/status error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

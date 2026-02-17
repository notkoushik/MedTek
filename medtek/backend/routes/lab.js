// routes/lab.js - Lab Assistant API endpoints
const express = require('express');
const router = express.Router();
const pool = require('../db');
const auth = require('../middleware/auth');

/**
 * GET /lab/pending-tests
 * Get all pending lab tests for the lab assistant's assigned hospital
 */
router.get('/pending-tests', auth, async (req, res) => {
    try {
        const userId = req.user.id;

        // 1. Get lab assistant's assigned hospital
        const userRes = await pool.query(
            'SELECT assigned_hospital_id, role FROM users WHERE id = $1',
            [userId]
        );

        if (userRes.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const { assigned_hospital_id, role } = userRes.rows[0];

        if (role !== 'lab_assistant') {
            return res.status(403).json({ error: 'Access denied. Lab assistant role required.' });
        }

        if (!assigned_hospital_id) {
            return res.status(400).json({ error: 'Lab assistant not assigned to a hospital' });
        }

        // 2. Get all medical reports with pending tests for this hospital
        const result = await pool.query(`
      SELECT 
        mr.id as report_id,
        mr.patient_id,
        mr.patient_name,
        mr.patient_age,
        mr.lab_tests,
        mr.lab_tests_json,
        mr.lab_tests_count,
        mr.created_at as ordered_at,
        mr.appointment_id,
        a.appointment_date as appointment_time,
        h.name as hospital_name,
        u_doc.name as doctor_name
      FROM medical_reports mr
      LEFT JOIN appointments a ON mr.appointment_id = a.id
      LEFT JOIN hospitals h ON mr.hospital_id = h.id
      LEFT JOIN doctors d ON mr.doctor_id = d.id
      LEFT JOIN users u_doc ON d.user_id = u_doc.id
      WHERE mr.hospital_id = $1
        AND mr.lab_tests_count > 0
        AND mr.report_status != 'completed'
      ORDER BY mr.created_at ASC
    `, [assigned_hospital_id]);

        // 3. Transform data to show individual pending tests
        const pendingTests = [];

        for (const row of result.rows) {
            const testsJson = row.lab_tests_json || {};

            for (const [testName, status] of Object.entries(testsJson)) {
                if (status === 'pending' || status === 'sample_collected') {
                    pendingTests.push({
                        report_id: row.report_id,
                        patient_id: row.patient_id,
                        patient_name: row.patient_name,
                        patient_age: row.patient_age,
                        test_name: testName,
                        test_status: status,
                        ordered_at: row.ordered_at,
                        appointment_id: row.appointment_id,
                        doctor_name: row.doctor_name,
                        hospital_name: row.hospital_name
                    });
                }
            }
        }

        res.json({
            tests: pendingTests,
            total_count: pendingTests.length,
            hospital_id: assigned_hospital_id
        });

    } catch (e) {
        console.error('GET /lab/pending-tests error:', e);
        res.status(500).json({ error: 'Server error' });
    }
});

/**
 * PATCH /lab/test/:reportId/collect-sample
 * Mark that sample has been collected for a specific test
 */
router.patch('/test/:reportId/collect-sample', auth, async (req, res) => {
    try {
        const { reportId } = req.params;
        const { testName } = req.body;

        if (!testName) {
            return res.status(400).json({ error: 'testName is required' });
        }

        // 1. Verify lab assistant role
        const userRes = await pool.query(
            'SELECT role FROM users WHERE id = $1',
            [req.user.id]
        );

        if (userRes.rows[0]?.role !== 'lab_assistant') {
            return res.status(403).json({ error: 'Access denied' });
        }

        // 2. Get current lab_tests_json
        const reportRes = await pool.query(
            'SELECT lab_tests_json FROM medical_reports WHERE id = $1',
            [reportId]
        );

        if (reportRes.rows.length === 0) {
            return res.status(404).json({ error: 'Report not found' });
        }

        let labs = reportRes.rows[0].lab_tests_json || {};

        // 3. Update status to sample_collected
        if (labs[testName] === undefined) {
            return res.status(400).json({ error: `Test "${testName}" not found in report` });
        }

        labs[testName] = 'sample_collected';

        // 4. Save
        await pool.query(
            'UPDATE medical_reports SET lab_tests_json = $1, updated_at = NOW() WHERE id = $2',
            [labs, reportId]
        );

        console.log(`📦 Sample collected for "${testName}" on report ${reportId}`);

        res.json({
            success: true,
            message: `Sample collected for ${testName}`,
            lab_tests_json: labs
        });

    } catch (e) {
        console.error('PATCH /lab/test/:reportId/collect-sample error:', e);
        res.status(500).json({ error: 'Server error' });
    }
});

/**
 * PATCH /lab/test/:reportId/complete
 * Mark a specific test as done (after sample was collected)
 */
router.patch('/test/:reportId/complete', auth, async (req, res) => {
    try {
        const { reportId } = req.params;
        const { testName } = req.body;

        if (!testName) {
            return res.status(400).json({ error: 'testName is required' });
        }

        // 1. Verify lab assistant role
        const userRes = await pool.query(
            'SELECT role FROM users WHERE id = $1',
            [req.user.id]
        );

        if (userRes.rows[0]?.role !== 'lab_assistant') {
            return res.status(403).json({ error: 'Access denied' });
        }

        // 2. Get current data
        const reportRes = await pool.query(
            'SELECT lab_tests_json, appointment_id FROM medical_reports WHERE id = $1',
            [reportId]
        );

        if (reportRes.rows.length === 0) {
            return res.status(404).json({ error: 'Report not found' });
        }

        let labs = reportRes.rows[0].lab_tests_json || {};
        const appointmentId = reportRes.rows[0].appointment_id;

        // 3. Verify sample was collected first
        if (labs[testName] !== 'sample_collected') {
            return res.status(400).json({
                error: `Cannot complete test "${testName}". Sample must be collected first.`,
                current_status: labs[testName]
            });
        }

        // 4. Mark as done
        labs[testName] = 'done';

        // 5. Check if all tests are done
        const allTestsDone = Object.values(labs).every(s => s === 'done');
        const newReportStatus = allTestsDone ? 'completed' : 'awaiting_lab_results';

        // 6. Update report
        await pool.query(
            'UPDATE medical_reports SET lab_tests_json = $1, report_status = $2, updated_at = NOW() WHERE id = $3',
            [labs, newReportStatus, reportId]
        );

        // 7. Update appointment status if all tests done
        if (appointmentId && allTestsDone) {
            await pool.query(
                "UPDATE appointments SET status = 'ready_for_review', updated_at = NOW() WHERE id = $1",
                [appointmentId]
            );
        }

        console.log(`✅ Test "${testName}" completed on report ${reportId}. All done: ${allTestsDone}`);

        res.json({
            success: true,
            message: `Test ${testName} completed`,
            lab_tests_json: labs,
            all_tests_done: allTestsDone
        });

    } catch (e) {
        console.error('PATCH /lab/test/:reportId/complete error:', e);
        res.status(500).json({ error: 'Server error' });
    }
});

/**
 * GET /lab/stats
 * Get summary stats for the lab dashboard
 */
router.get('/stats', auth, async (req, res) => {
    try {
        console.log('📊 GET /lab/stats called by User:', req.user.id);
        const userId = req.user.id;

        // Get assigned hospital
        const userRes = await pool.query(
            'SELECT assigned_hospital_id, role FROM users WHERE id = $1',
            [userId]
        );

        if (userRes.rows.length === 0) {
            console.log('⚠️ User not found in DB');
            return res.status(404).json({ error: 'User not found' });
        }

        const hospitalId = userRes.rows[0]?.assigned_hospital_id;
        console.log(`🏥 User Role: ${userRes.rows[0].role}, Hospital ID: ${hospitalId}`);

        if (!hospitalId) {
            console.log('ℹ️ No hospital assigned, returning 0 stats');
            return res.json({ pending: 0, sample_collected: 0, completed_today: 0 });
        }

        // Count pending tests
        console.log('🔍 Executing pending tests query...');
        const statsRes = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE value = 'pending') as pending,
        COUNT(*) FILTER (WHERE value = 'sample_collected') as sample_collected
      FROM medical_reports mr
      CROSS JOIN LATERAL jsonb_each_text(COALESCE(mr.lab_tests_json, '{}'::jsonb))
      WHERE mr.hospital_id = $1
        AND mr.report_status != 'completed'
    `, [hospitalId]);

        console.log('✅ Pending stats:', statsRes.rows[0]);

        // Count completed today
        console.log('🔍 Executing completed query...');
        const completedRes = await pool.query(`
      SELECT COUNT(*) as completed_today
      FROM medical_reports
      WHERE hospital_id = $1
        AND (report_status = 'completed' OR status = 'completed')
        AND DATE(updated_at) = CURRENT_DATE
    `, [hospitalId]);

        console.log('✅ Completed stats:', completedRes.rows[0]);

        const responseData = {
            pending: parseInt(statsRes.rows[0]?.pending || 0),
            sample_collected: parseInt(statsRes.rows[0]?.sample_collected || 0),
            completed_today: parseInt(completedRes.rows[0]?.completed_today || 0)
        };

        console.log('📤 Sending response:', responseData);
        res.json(responseData);

    } catch (e) {
        console.error('❌ GET /lab/stats error:', e);
        console.error('Stack:', e.stack);
        res.status(500).json({ error: 'Server error: ' + e.message });
    }
});

module.exports = router;

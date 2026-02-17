// Run: node scripts/verify_lab_query.js
const pool = require('../db');
require('dotenv').config();

async function verify() {
    try {
        // Get lab assistant's hospital
        const labUser = await pool.query(`
      SELECT id, name, assigned_hospital_id 
      FROM users WHERE role = 'lab_assistant' LIMIT 1;
    `);

        if (labUser.rows.length === 0) {
            console.log('❌ No lab assistant found');
            return;
        }

        const user = labUser.rows[0];
        console.log('🧪 Lab Assistant:', user.name);
        console.log('   Assigned Hospital ID:', user.assigned_hospital_id);

        // Check column type
        const colType = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'medical_reports' AND column_name = 'lab_tests_json';
    `);
        console.log('\n📋 lab_tests_json column type:', colType.rows[0]?.data_type || 'NOT FOUND');

        // Run the exact stats query from lab.js
        console.log('\n📊 Running stats query for hospital', user.assigned_hospital_id, '...');

        const statsRes = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE value = 'pending') as pending,
        COUNT(*) FILTER (WHERE value = 'sample_collected') as sample_collected
      FROM medical_reports mr,
           jsonb_each_text(mr.lab_tests_json)
      WHERE mr.hospital_id = $1
        AND mr.report_status != 'completed'
    `, [user.assigned_hospital_id]);

        console.log('✅ Stats result:', statsRes.rows[0]);

        // Count completed today
        const completedRes = await pool.query(`
      SELECT COUNT(*) as completed_today
      FROM medical_reports
      WHERE hospital_id = $1
        AND report_status = 'completed'
        AND DATE(updated_at) = CURRENT_DATE
    `, [user.assigned_hospital_id]);

        console.log('✅ Completed today:', completedRes.rows[0]);

        console.log('\n✅ All queries successful!');

    } catch (e) {
        console.error('❌ Error:', e.message);
        console.error('   Code:', e.code);
        console.error('   Detail:', e.detail);
    } finally {
        await pool.end();
    }
}

verify();

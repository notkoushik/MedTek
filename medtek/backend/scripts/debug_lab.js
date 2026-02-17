// Run: node scripts/debug_lab.js
const pool = require('../db');
require('dotenv').config();

async function debug() {
    try {
        // Check lab assistant
        const labUser = await pool.query(`
      SELECT id, name, role, assigned_hospital_id 
      FROM users WHERE role = 'lab_assistant';
    `);

        console.log('🧪 Lab Assistants:');
        for (const user of labUser.rows) {
            console.log(`  ID: ${user.id}, Name: ${user.name}, Hospital: ${user.assigned_hospital_id || 'NOT ASSIGNED'}`);
        }

        // List available hospitals
        const hospitals = await pool.query('SELECT id, name FROM hospitals LIMIT 5;');
        console.log('\n🏥 Available Hospitals:');
        hospitals.rows.forEach(h => console.log(`  ID: ${h.id}, Name: ${h.name}`));

        // Test the stats query directly
        console.log('\n📊 Testing stats query...');
        const statsRes = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE value = 'pending') as pending,
        COUNT(*) FILTER (WHERE value = 'sample_collected') as sample_collected
      FROM medical_reports mr,
           jsonb_each_text(mr.lab_tests_json)
      WHERE mr.hospital_id = 1
        AND mr.report_status != 'completed'
    `);
        console.log('Stats result:', statsRes.rows[0]);

    } catch (e) {
        console.error('❌ Error:', e.message);
        console.error('   Code:', e.code);
    } finally {
        await pool.end();
    }
}

debug();

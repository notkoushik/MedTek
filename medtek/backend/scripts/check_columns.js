// Run: node scripts/check_columns.js
const pool = require('../db');
require('dotenv').config();

async function check() {
    try {
        // Check medical_reports columns
        const mrCols = await pool.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'medical_reports'
      ORDER BY column_name;
    `);
        console.log('📋 medical_reports columns:');
        mrCols.rows.forEach(r => console.log('  -', r.column_name));

        // Check if hospital_id exists
        const hasHospitalId = mrCols.rows.some(r => r.column_name === 'hospital_id');
        console.log('\n✅ hospital_id exists:', hasHospitalId);

        // Check users.assigned_hospital_id
        const userCols = await pool.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'assigned_hospital_id';
    `);
        console.log('✅ users.assigned_hospital_id exists:', userCols.rows.length > 0);

        // Check lab assistant user
        const labUser = await pool.query(`
      SELECT id, name, role, assigned_hospital_id 
      FROM users WHERE role = 'lab_assistant' LIMIT 1;
    `);
        if (labUser.rows.length > 0) {
            console.log('\n🧪 Lab Assistant found:');
            console.log('   ID:', labUser.rows[0].id);
            console.log('   Name:', labUser.rows[0].name);
            console.log('   Hospital ID:', labUser.rows[0].assigned_hospital_id);
        } else {
            console.log('\n⚠️ No lab_assistant found');
        }

    } catch (e) {
        console.error('Error:', e.message);
    } finally {
        await pool.end();
    }
}

check();

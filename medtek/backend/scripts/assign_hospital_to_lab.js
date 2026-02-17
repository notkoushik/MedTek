// Run: node scripts/assign_hospital_to_lab.js
const pool = require('../db');
require('dotenv').config();

async function assign() {
    try {
        // Check lab assistant
        const labUser = await pool.query(`
      SELECT id, name, assigned_hospital_id 
      FROM users WHERE role = 'lab_assistant';
    `);

        if (labUser.rows.length === 0) {
            console.log('❌ No lab assistant found');
            return;
        }

        const user = labUser.rows[0];
        console.log('🧪 Lab Assistant:');
        console.log('   ID:', user.id);
        console.log('   Name:', user.name);
        console.log('   Current Hospital:', user.assigned_hospital_id || 'NOT ASSIGNED');

        if (user.assigned_hospital_id) {
            console.log('✅ Already assigned to hospital', user.assigned_hospital_id);
            return;
        }

        // Get first hospital
        const hospitals = await pool.query('SELECT id, name FROM hospitals LIMIT 1;');
        if (hospitals.rows.length === 0) {
            console.log('❌ No hospitals in database');
            return;
        }

        const hospital = hospitals.rows[0];
        console.log('\n🏥 Assigning to:', hospital.name, '(ID:', hospital.id, ')');

        // Assign
        await pool.query(
            'UPDATE users SET assigned_hospital_id = $1 WHERE id = $2',
            [hospital.id, user.id]
        );

        console.log('✅ Assignment complete!');

    } catch (e) {
        console.error('❌ Error:', e.message);
    } finally {
        await pool.end();
    }
}

assign();

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
    try {
        // 1. Get first doctor
        const docRes = await pool.query('SELECT id, user_id FROM doctors LIMIT 1');
        if (docRes.rows.length === 0) {
            console.log('No doctors found');
            return;
        }
        const doctor = docRes.rows[0];

        // 2. Get first patient
        const patRes = await pool.query("SELECT id, name, age FROM users WHERE role = 'patient' LIMIT 1");
        if (patRes.rows.length === 0) {
            console.log('No patients found');
            return;
        }
        const patient = patRes.rows[0];

        // 3. Insert report
        await pool.query(
            `INSERT INTO medical_reports (
         doctor_id, patient_id, appointment_id,
         patient_name, patient_age, condition,
         lab_tests_count, created_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
            [
                doctor.id,
                patient.id,
                999, // Dummy appointment ID
                patient.name,
                patient.age || '30',
                'Routine Checkup - Seeded',
                1 // Count as l lab test
            ]
        );

        console.log(`✅ Seeded report for Dr ID ${doctor.id} (User ${doctor.user_id}) - Patient ${patient.name}`);

    } catch (e) {
        console.error('❌ Error:', e);
    } finally {
        pool.end();
    }
}

run();

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
    try {
        console.log('🗑️ Dropping medical_reports table...');
        await pool.query('DROP TABLE IF EXISTS medical_reports');

        console.log('⚠️ Recreating medical_reports table...');
        await pool.query(`
      CREATE TABLE IF NOT EXISTS medical_reports (
        id SERIAL PRIMARY KEY,
        doctor_id INTEGER NOT NULL,
        patient_id INTEGER NOT NULL,
        appointment_id INTEGER NOT NULL,
        diagnosis TEXT,
        prescription TEXT,
        lab_tests TEXT,
        lab_tests_count INTEGER DEFAULT 0,
        notes TEXT,
        description_type TEXT,
        description_text TEXT,
        description_image_url TEXT,
        status TEXT DEFAULT 'completed',
        report_status TEXT DEFAULT 'completed',
        patient_name TEXT,
        patient_age TEXT,
        condition TEXT,
        triage_diagnosis TEXT,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

        // Seed
        // 1. Get first doctor
        const docRes = await pool.query('SELECT id, user_id FROM doctors LIMIT 1');
        if (docRes.rows.length === 0) { console.log('No doctors found'); return; }
        const doctor = docRes.rows[0];

        // 2. Get first patient
        const patRes = await pool.query("SELECT id, name FROM users WHERE role = 'patient' LIMIT 1");
        if (patRes.rows.length === 0) { console.log('No patients found'); return; }
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
                999,
                patient.name,
                '30', // Dummy age since we didn't fetch it
                'Routine Checkup - Seeded',
                1
            ]
        );

        console.log(`✅ Table recreated and seeded for Dr ID ${doctor.id} (User ${doctor.user_id})`);

    } catch (e) {
        console.error('❌ Error:', e);
    } finally {
        pool.end();
    }
}

run();

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
    try {
        console.log('--- MEDICAL REPORTS (Lab Counts) ---');
        const res = await pool.query('SELECT id, doctor_id, patient_name, lab_tests, lab_tests_count FROM medical_reports ORDER BY id DESC');
        console.table(res.rows);

        const sumRes = await pool.query('SELECT SUM(lab_tests_count) as total FROM medical_reports');
        console.log('Total Sum in DB:', sumRes.rows[0]);

    } catch (e) {
        console.error(e);
    } finally {
        pool.end();
    }
}

run();

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
    try {
        console.log('--- DOCTORS ---');
        const docs = await pool.query('SELECT * FROM doctors');
        console.table(docs.rows);

        console.log('\n--- MEDICAL REPORTS ---');
        const reports = await pool.query('SELECT * FROM medical_reports');
        console.table(reports.rows);

        console.log('\n--- USERS (Patients) ---');
        const patients = await pool.query("SELECT id, name, role FROM users WHERE role = 'patient'");
        console.table(patients.rows);

    } catch (e) {
        console.error(e);
    } finally {
        pool.end();
    }
}

run();

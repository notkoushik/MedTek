require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
    try {
        const res = await pool.query("DELETE FROM medical_reports WHERE patient_name IS NULL OR patient_name = 'Unknown'");
        console.log(`✅ Deleted ${res.rowCount} bad reports`);
    } catch (e) {
        console.error(e);
    } finally {
        pool.end();
    }
}

run();

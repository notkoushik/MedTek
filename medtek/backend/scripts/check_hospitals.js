const { Pool } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

async function checkHospitals() {
    try {
        const res = await pool.query('SELECT id, name, address, latitude, longitude FROM hospitals ORDER BY id');
        console.table(res.rows);
    } catch (e) {
        console.error(e);
    } finally {
        pool.end();
    }
}

checkHospitals();

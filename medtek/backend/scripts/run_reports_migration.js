require('dotenv').config();
const fs = require('fs');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
    try {
        const sql = fs.readFileSync('./create_reports_table.sql', 'utf8');
        await pool.query(sql);
        console.log('✅ Created medical_reports table');
    } catch (e) {
        console.error('❌ Error:', e);
    } finally {
        pool.end();
    }
}

run();

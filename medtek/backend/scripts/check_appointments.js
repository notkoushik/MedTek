// Run: node scripts/check_appointments.js
const pool = require('../db');
require('dotenv').config();

async function check() {
    try {
        const cols = await pool.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_name = 'appointments'
      ORDER BY column_name;
    `);
        console.log('📋 appointments table columns:');
        cols.rows.forEach(r => console.log('  -', r.column_name));
    } catch (e) {
        console.error('❌ Error:', e.message);
    } finally {
        await pool.end();
    }
}

check();

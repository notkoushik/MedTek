// Run: node scripts/check_schema.js
const pool = require('../db');
require('dotenv').config();

async function check() {
    try {
        const res = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'medical_reports'
      ORDER BY column_name
    `);

        console.log('📋 medical_reports schema:');
        res.rows.forEach(r => console.log(`  - ${r.column_name} (${r.data_type})`));

    } catch (e) {
        console.error('❌ Error:', e.message);
    } finally {
        await pool.end();
    }
}

check();

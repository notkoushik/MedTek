// Run: node scripts/add_updated_at.js
const pool = require('../db');
require('dotenv').config();

async function migrate() {
    try {
        console.log('🔧 Adding updated_at column to medical_reports...');

        await pool.query(`
      ALTER TABLE medical_reports 
      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();
    `);

        console.log('✅ Column added!');

        // Set default value for existing rows
        await pool.query(`
      UPDATE medical_reports 
      SET updated_at = created_at 
      WHERE updated_at IS NULL;
    `);

        console.log('✅ Existing rows updated!');

    } catch (e) {
        console.error('❌ Error:', e.message);
    } finally {
        await pool.end();
    }
}

migrate();

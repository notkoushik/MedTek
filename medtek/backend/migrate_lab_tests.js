const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function migrate() {
    try {
        console.log('🔌 Connecting to database...');
        // Check if column exists
        const checkRes = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name='medical_reports' AND column_name='lab_tests_json';
    `);

        if (checkRes.rows.length > 0) {
            console.log('⚠️ Column lab_tests_json already exists.');
        } else {
            console.log('✨ Adding lab_tests_json column...');
            await pool.query(`
        ALTER TABLE medical_reports 
        ADD COLUMN lab_tests_json JSONB DEFAULT '{}';
      `);
            console.log('✅ Column added successfully.');
        }
    } catch (e) {
        console.error('❌ Migration failed:', e);
    } finally {
        await pool.end();
    }
}

migrate();

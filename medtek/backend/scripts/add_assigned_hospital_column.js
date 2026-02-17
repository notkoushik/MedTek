// Run this with: node add_assigned_hospital_column.js
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function migrate() {
    try {
        console.log('🔧 Adding assigned_hospital_id column to users table...');

        await pool.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS assigned_hospital_id INTEGER REFERENCES hospitals(id);
    `);

        console.log('✅ Column added successfully!');

        // Verify
        const result = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'assigned_hospital_id';
    `);

        if (result.rows.length > 0) {
            console.log('✅ Verified: assigned_hospital_id column exists');
            console.log('   Type:', result.rows[0].data_type);
        }

    } catch (e) {
        console.error('❌ Migration error:', e.message);
    } finally {
        await pool.end();
    }
}

migrate();

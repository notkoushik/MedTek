// Run this with: node add_hospital_id_to_reports.js
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function migrate() {
    try {
        console.log('🔧 Adding hospital_id column to medical_reports table...');

        await pool.query(`
      ALTER TABLE medical_reports 
      ADD COLUMN IF NOT EXISTS hospital_id INTEGER REFERENCES hospitals(id);
    `);

        console.log('✅ Column added successfully!');

        // Backfill: Set hospital_id from doctor's hospital for existing records
        console.log('🔧 Backfilling hospital_id from doctors table...');

        await pool.query(`
      UPDATE medical_reports mr
      SET hospital_id = d.hospital_id
      FROM doctors d
      WHERE mr.doctor_id = d.id
        AND mr.hospital_id IS NULL;
    `);

        console.log('✅ Backfill complete!');

        // Verify
        const result = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'medical_reports' AND column_name = 'hospital_id';
    `);

        if (result.rows.length > 0) {
            console.log('✅ Verified: hospital_id column exists');
            console.log('   Type:', result.rows[0].data_type);
        }

    } catch (e) {
        console.error('❌ Migration error:', e.message);
    } finally {
        await pool.end();
    }
}

migrate();

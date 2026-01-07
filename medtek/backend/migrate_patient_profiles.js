const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function migrate() {
    try {
        console.log('🔌 Connecting to database...');

        // Create patient_profiles table if not exists
        await pool.query(`
      CREATE TABLE IF NOT EXISTS patient_profiles (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        age INTEGER,
        weight NUMERIC(5,2),
        height NUMERIC(5,2),
        gender VARCHAR(20),
        blood_group VARCHAR(10),
        reference_notes JSONB,
        insurances JSONB,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
        console.log('✅ patient_profiles table ensured.');

        // Add columns if they don't exist (idempotent)
        const columns = [
            'age INTEGER',
            'weight NUMERIC(5,2)',
            'height NUMERIC(5,2)',
            'gender VARCHAR(20)',
            'blood_group VARCHAR(10)'
        ];

        for (const col of columns) {
            const colName = col.split(' ')[0];
            try {
                await pool.query(`
          ALTER TABLE patient_profiles ADD COLUMN IF NOT EXISTS ${col};
        `);
                console.log(`   - Ensured column: ${colName}`);
            } catch (e) {
                console.log(`   - Error adding column ${colName}: ${e.message}`);
            }
        }

        console.log('✨ Migration complete.');
    } catch (e) {
        console.error('❌ Migration failed:', e);
    } finally {
        await pool.end();
    }
}

migrate();

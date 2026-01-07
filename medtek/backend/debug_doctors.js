require('dotenv').config();
const fs = require('fs');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
    try {
        const sql = fs.readFileSync('./fix_missing_tables.sql', 'utf8');

        // Split SQL into separate statements if needed, or run as one block
        // Specifically running creation first
        await pool.query(`
      CREATE TABLE IF NOT EXISTS patient_profiles (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        age INTEGER DEFAULT 0,
        reference_notes JSONB DEFAULT '[]',
        insurances JSONB DEFAULT '[]'
      );
      
      CREATE TABLE IF NOT EXISTS patient_doctors (
        patient_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        doctor_id INTEGER REFERENCES users(id) ON DELETE SET NULL
      );
    `);
        console.log('✅ Created missing tables');

        console.log('\n--- USERS with role=doctor ---');
        const users = await pool.query("SELECT id, name, email FROM users WHERE role = 'doctor'");
        console.table(users.rows);

        console.log('\n--- DOCTORS table ---');
        const doctors = await pool.query('SELECT * FROM doctors');
        console.table(doctors.rows);

    } catch (e) {
        console.error('❌ Error:', e);
    } finally {
        pool.end();
    }
}

run();

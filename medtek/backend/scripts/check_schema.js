const { Pool } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') }); // Robust path resolution

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
});

async function checkSchema() {
    console.log('🔍 Validating Database Schema...');

    const requiredTables = [
        'users',
        'doctors',
        'hospitals',
        'appointments',
        'medical_reports',
        'rides'
    ];

    try {
        const res = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);

        const existingTables = res.rows.map(r => r.table_name);
        console.log('✅ Found tables:', existingTables.join(', '));

        const missing = requiredTables.filter(t => !existingTables.includes(t));

        if (missing.length > 0) {
            console.error('❌ CRITICAL: Missing required tables:', missing.join(', '));
            console.error('   The provided database does not match the application requirements.');
            process.exit(1);
        }

        console.log('✅ Schema validation PASSED. All critical tables exist.');
        process.exit(0);

    } catch (e) {
        console.error('❌ Database connection failed during schema check:', e.message);
        process.exit(1);
    }
}

checkSchema();

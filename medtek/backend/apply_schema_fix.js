const fs = require('fs');
const pool = require('./db');

async function runMigration() {
    try {
        const sql = fs.readFileSync('./fix_appointments_schema.sql', 'utf8');
        console.log('Running schema fix...');
        await pool.query(sql);
        console.log('✅ Schema fix successful');
    } catch (e) {
        console.error('❌ Schema fix failed:', e);
    } finally {
        pool.end();
    }
}

runMigration();

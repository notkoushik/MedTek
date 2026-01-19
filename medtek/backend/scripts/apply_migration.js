const fs = require('fs');
const pool = require('./db');

async function runMigration() {
    try {
        const sql = fs.readFileSync('./add_verification_columns.sql', 'utf8');
        console.log('Running migration...');
        await pool.query(sql);
        console.log('✅ Migration successful');
    } catch (e) {
        console.error('❌ Migration failed:', e);
    } finally {
        pool.end();
    }
}

runMigration();

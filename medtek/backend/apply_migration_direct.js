const pool = require('./db');

async function runMigration() {
    try {
        console.log('Running migration...');

        // Split commands manually since pool.query usually handles one at a time if not configured for multi-statement
        await pool.query('ALTER TABLE doctors ADD COLUMN IF NOT EXISTS nmc_number VARCHAR(50);');
        console.log('Added nmc_number');

        await pool.query('ALTER TABLE doctors ADD COLUMN IF NOT EXISTS verification_points INTEGER DEFAULT 0;');
        console.log('Added verification_points');

        await pool.query('ALTER TABLE doctors ADD COLUMN IF NOT EXISTS verification_details JSONB;');
        console.log('Added verification_details');

        await pool.query('ALTER TABLE doctors ADD COLUMN IF NOT EXISTS verification_documents JSONB;');
        console.log('Added verification_documents');

        console.log('✅ Migration successful');
    } catch (e) {
        console.error('❌ Migration failed:', e);
    } finally {
        pool.end();
    }
}

runMigration();

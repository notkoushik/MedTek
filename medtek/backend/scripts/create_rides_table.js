const { Pool } = require('pg');
const path = require('path');
// Robustly find .env in the parent directory (backend/.env)
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

console.log('🔌 DB URL:', process.env.DATABASE_URL ? 'Loaded' : 'MISSING');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
});

async function createRidesTable() {
    console.log('🚧 Creating rides table...');
    try {
        await pool.query(`
      CREATE TABLE IF NOT EXISTS rides (
        id SERIAL PRIMARY KEY,
        rider_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        driver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        
        pickup_lat DOUBLE PRECISION NOT NULL,
        pickup_lng DOUBLE PRECISION NOT NULL,
        drop_lat DOUBLE PRECISION NOT NULL,
        drop_lng DOUBLE PRECISION NOT NULL,
        
        distance_km DOUBLE PRECISION,
        estimated_fare DOUBLE PRECISION,
        
        status VARCHAR(20) DEFAULT 'requested', -- requested, accepted, arrived, in_progress, completed, cancelled
        pin VARCHAR(10),
        
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        accepted_at TIMESTAMPTZ,
        completed_at TIMESTAMPTZ,
        
        driver_lat DOUBLE PRECISION,
        driver_lng DOUBLE PRECISION
      );
    `);
        console.log('✅ Rides table created successfully.');
    } catch (e) {
        console.error('❌ Error creating rides table:', e);
    } finally {
        pool.end();
    }
}

createRidesTable();

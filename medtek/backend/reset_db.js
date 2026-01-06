const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const dbName = 'Medtek';
const password = process.env.DATABASE_URL.split(':')[2].split('@')[0] || '0907';
const user = 'postgres';
const host = 'localhost';
const port = 5432;

async function reset() {
    const client = new Client({
        user,
        host,
        database: dbName,
        password,
        port,
    });

    try {
        await client.connect();
        console.log(`✅ Connected to ${dbName} database`);

        // Drop all tables
        console.log('🗑️ Dropping existing schema/tables...');
        await client.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');

        // Run new SQL schema
        const sqlPath = path.join(__dirname, 'Sql.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('🔄 Applying new SQL schema...');
        await client.query(sql);
        console.log('✅ Schema updated successfully');

        await client.end();
    } catch (err) {
        console.error('❌ Error resetting database:', err);
        if (client) await client.end();
    }
}

reset();

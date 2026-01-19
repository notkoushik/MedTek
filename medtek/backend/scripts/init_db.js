const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const dbName = 'Medtek';
const password = '0907'; // Using provided password explicitly or from env
const user = 'postgres';
const host = 'localhost';
const port = 5432;

async function init() {
    // 1. Connect to default 'postgres' db to create the new db
    const client = new Client({
        user,
        host,
        database: 'postgres',
        password,
        port,
    });

    try {
        await client.connect();
        console.log('✅ Connected to postgres database');

        // Check if DB exists
        const res = await client.query(`SELECT 1 FROM pg_database WHERE datname='${dbName.toLowerCase()}'`);
        if (res.rowCount === 0) {
            console.log(`Creating database ${dbName}...`);
            await client.query(`CREATE DATABASE "${dbName}"`);
            console.log(`✅ Database ${dbName} created`);
        } else {
            console.log(`ℹ️ Database ${dbName} already exists`);
        }
        await client.end();

        // 2. Connect to the (new) Medtek db to run SQL schema
        const dbClient = new Client({
            user,
            host,
            database: dbName,
            password,
            port,
        });

        await dbClient.connect();
        console.log(`✅ Connected to ${dbName} database`);

        const sqlPath = path.join(__dirname, 'Sql.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('Running SQL schema...');
        await dbClient.query(sql);
        console.log('✅ Schema applied successfully');

        await dbClient.end();
    } catch (err) {
        console.error('❌ Error initializing database:', err);
        if (client) await client.end();
    }
}

init();

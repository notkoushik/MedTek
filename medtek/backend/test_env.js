// Run: node test_env.js
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

console.log('📂 CWD:', process.cwd());
console.log('📂 .env path:', path.resolve('.env'));

// Check if file exists
if (fs.existsSync('.env')) {
    console.log('✅ .env file exists');
    const content = fs.readFileSync('.env', 'utf8');
    console.log('📄 Content length:', content.length);
    console.log('📄 First line:', content.split('\n')[0]);
} else {
    console.error('❌ .env file NOT found');
}

// Try loading
const result = dotenv.config();

if (result.error) {
    console.error('❌ dotenv config error:', result.error);
} else {
    console.log('✅ dotenv loaded successfully');
    console.log('🔑 Parsed keys:', Object.keys(result.parsed));
}

console.log('🔑 process.env.DATABASE_URL:', process.env.DATABASE_URL ? 'SET' : 'MISSING');

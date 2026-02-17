// Run: node scripts/test_api_flow.js
const API_URL = 'http://localhost:4000';

async function test() {
    try {
        console.log('🚀 Testing API Flow (via fetch)...');

        // 1. Login
        console.log('🔑 Logging in as Lab Assistant...');
        const loginRes = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: 'satya@gmail.com', password: 'satya' })
        });

        const loginData = await loginRes.json();

        if (!loginRes.ok) {
            console.error('❌ Login Failed:', loginData);
            return;
        }

        console.log('✅ Login Successful!');
        const token = loginData.token;

        // 2. Get Stats
        console.log('📊 Fetching Lab Stats...');
        const statsRes = await fetch(`${API_URL}/lab/stats`, {
            headers: { Authorization: `Bearer ${token}` }
        });

        const statsData = await statsRes.json();

        if (!statsRes.ok) {
            console.error('❌ Stats API Error:', statsRes.status, statsData);
            return;
        }

        console.log('✅ Stats Response:', statsData);
        console.log('🎉 Backend Check Passed!');

    } catch (e) {
        console.error('❌ Test failed:', e.message);
    }
}

test();

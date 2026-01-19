const { Pool } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

// Known locations for demo (Hyderabad)
const KNOWN_LOCATIONS = {
    'Apollo Hospitals': { lat: 17.4156, lng: 78.4124 },
    'Yashoda Hospitals': { lat: 17.4399, lng: 78.4862 },
    'KIMS Hospitals': { lat: 17.4265, lng: 78.4834 },
    'Medicover Hospitals': { lat: 17.4474, lng: 78.3762 },
    'Care Hospitals': { lat: 17.4116, lng: 78.4485 },
    'Sunshine Hospitals': { lat: 17.4385, lng: 78.4883 },
    'Continental Hospitals': { lat: 17.4168, lng: 78.3444 },
    'AIG Hospitals': { lat: 17.4452, lng: 78.3683 },
};

// Center of Hyderabad for random fallback
const CENTER_LAT = 17.3850;
const CENTER_LNG = 78.4867;

async function updateHospitalLocations() {
    console.log('🏥 Updating Hospital Locations...');

    try {
        const res = await pool.query('SELECT id, name FROM hospitals');
        console.log(`Found ${res.rows.length} hospitals.`);

        for (const h of res.rows) {
            let lat, lng;

            // Check partial match
            const knownKey = Object.keys(KNOWN_LOCATIONS).find(k => h.name.includes(k) || k.includes(h.name));

            if (knownKey) {
                lat = KNOWN_LOCATIONS[knownKey].lat;
                lng = KNOWN_LOCATIONS[knownKey].lng;
                console.log(`✅ Matched "${h.name}" to known location.`);
            } else {
                // Random nearby location (within ~5km)
                lat = CENTER_LAT + (Math.random() - 0.5) * 0.1;
                lng = CENTER_LNG + (Math.random() - 0.5) * 0.1;
                console.log(`🎲 Assigned random location to "${h.name}".`);
            }

            await pool.query(
                'UPDATE hospitals SET latitude = $1, longitude = $2 WHERE id = $3',
                [lat, lng, h.id]
            );
        }

        console.log('✨ All hospitals updated with coordinates.');

    } catch (e) {
        console.error('Error updating hospitals:', e);
    } finally {
        pool.end();
    }
}

updateHospitalLocations();

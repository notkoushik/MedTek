// Script to view hospitals with simpler output
const pool = require('../db');

async function viewHospitals() {
    try {
        const result = await pool.query(`
      SELECT id, name, 
        COALESCE(address, 'NULL') as address, 
        COALESCE(latitude::text, 'NULL') as lat, 
        COALESCE(longitude::text, 'NULL') as lng, 
        COALESCE(google_place_id, 'NULL') as place_id 
      FROM hospitals 
      ORDER BY id
    `);

        console.log('\n=== ALL HOSPITALS ===');
        result.rows.forEach(r => {
            console.log(`ID: ${r.id} | Name: ${r.name}`);
            console.log(`   Address: ${r.address}`);
            console.log(`   Coords: ${r.lat}, ${r.lng}`);
            console.log(`   PlaceID: ${r.place_id}`);
            console.log('---');
        });

        // Find doctors linked to old hospitals
        const doctors = await pool.query(`
      SELECT d.user_id, u.name as doctor_name, d.hospital_id, h.name as hospital_name,
        CASE WHEN h.latitude IS NULL OR h.latitude = 0 THEN 'MISSING COORDS' ELSE 'OK' END as status
      FROM doctors d
      JOIN users u ON d.user_id = u.id
      LEFT JOIN hospitals h ON d.hospital_id = h.id
    `);

        console.log('\n=== DOCTORS & THEIR HOSPITALS ===');
        doctors.rows.forEach(r => {
            console.log(`Doctor: ${r.doctor_name} (user_id: ${r.user_id})`);
            console.log(`   Hospital: ${r.hospital_name} (id: ${r.hospital_id}) - ${r.status}`);
            console.log('---');
        });

        process.exit(0);
    } catch (e) {
        console.error('Error:', e.message);
        process.exit(1);
    }
}

viewHospitals();

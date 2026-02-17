// Automatic hospital cleanup script
// This will consolidate duplicate hospitals and update doctor references

const pool = require('../db');

async function cleanup() {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        console.log('\n=== BEFORE CLEANUP ===\n');

        // Show current state
        const before = await client.query(`
      SELECT d.user_id, u.name as doctor, h.id as hosp_id, h.name as hospital,
        CASE WHEN h.latitude IS NULL OR h.latitude = 0 THEN 'MISSING' ELSE h.latitude::text END as lat
      FROM doctors d
      JOIN users u ON d.user_id = u.id
      LEFT JOIN hospitals h ON d.hospital_id = h.id
    `);

        before.rows.forEach(r => {
            console.log(`${r.doctor}: Hospital "${r.hospital}" (id: ${r.hosp_id}) - Lat: ${r.lat}`);
        });

        // Find the best hospital for each name (the one with coordinates)
        const hospitals = await client.query(`
      SELECT id, name, address, latitude, longitude, google_place_id
      FROM hospitals
      ORDER BY name, 
        CASE WHEN latitude IS NOT NULL AND latitude != 0 THEN 0 ELSE 1 END,
        id DESC
    `);

        // Group by similar name, prefer the one with coordinates
        const bestHospitals = {};
        hospitals.rows.forEach(h => {
            const key = h.name.toLowerCase().trim();
            if (!bestHospitals[key] || (h.latitude && !bestHospitals[key].latitude)) {
                bestHospitals[key] = h;
            }
        });

        console.log('\n=== BEST HOSPITAL FOR EACH NAME ===\n');
        Object.values(bestHospitals).forEach(h => {
            console.log(`${h.name} (id: ${h.id}) - Lat: ${h.latitude || 'NULL'}`);
        });

        // Update doctors to use best hospital
        for (const row of before.rows) {
            const currentHosp = hospitals.rows.find(h => h.id === row.hosp_id);
            if (currentHosp) {
                const key = currentHosp.name.toLowerCase().trim();
                const best = bestHospitals[key];
                if (best && best.id !== currentHosp.id && best.latitude) {
                    console.log(`\nUpdating ${row.doctor}: ${currentHosp.id} -> ${best.id}`);
                    await client.query(
                        'UPDATE doctors SET hospital_id = $1 WHERE user_id = $2',
                        [best.id, row.user_id]
                    );
                }
            }
        }

        // Delete orphan hospitals (not used by any doctor)
        const deleted = await client.query(`
      DELETE FROM hospitals 
      WHERE id NOT IN (SELECT DISTINCT hospital_id FROM doctors WHERE hospital_id IS NOT NULL)
      RETURNING id, name
    `);

        if (deleted.rows.length > 0) {
            console.log('\n=== DELETED ORPHAN HOSPITALS ===\n');
            deleted.rows.forEach(h => console.log(`Deleted: ${h.name} (id: ${h.id})`));
        }

        console.log('\n=== AFTER CLEANUP ===\n');

        const after = await client.query(`
      SELECT d.user_id, u.name as doctor, h.id as hosp_id, h.name as hospital,
        CASE WHEN h.latitude IS NULL OR h.latitude = 0 THEN 'MISSING' ELSE 'OK' END as status
      FROM doctors d
      JOIN users u ON d.user_id = u.id
      LEFT JOIN hospitals h ON d.hospital_id = h.id
    `);

        after.rows.forEach(r => {
            console.log(`${r.doctor}: Hospital "${r.hospital}" (id: ${r.hosp_id}) - ${r.status}`);
        });

        await client.query('COMMIT');
        console.log('\n✅ Cleanup completed successfully!\n');

    } catch (e) {
        await client.query('ROLLBACK');
        console.error('❌ Error:', e.message);
    } finally {
        client.release();
        process.exit(0);
    }
}

cleanup();

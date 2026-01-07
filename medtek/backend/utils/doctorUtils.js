const { Pool } = require('pg');

/**
 * Resolves the primary key (id) of a doctor from a given ID,
 * checking both the primary key and the user_id column.
 * 
 * @param {Pool} pool - The PostgreSQL pool or client
 * @param {string|number} idOrUserId - The ID to look up (could be '1' or '7')
 * @returns {Promise<number|null>} The doctor's primary key ID, or null if not found.
 */
async function resolveDoctorId(pool, idOrUserId) {
    if (!idOrUserId) return null;

    try {
        // 1. Check if it's already the primary key
        const pkRes = await pool.query('SELECT id FROM doctors WHERE id = $1', [idOrUserId]);
        if (pkRes.rows.length > 0) {
            return pkRes.rows[0].id;
        }

        // 2. Check if it's the user_id
        const userRes = await pool.query('SELECT id FROM doctors WHERE user_id = $1', [idOrUserId]);
        if (userRes.rows.length > 0) {
            return userRes.rows[0].id; // Returns the doctor.id (e.g., 1)
        }

        return null; // Not found
    } catch (e) {
        console.error('Error resolving doctor ID:', e);
        return null;
    }
}

module.exports = { resolveDoctorId };

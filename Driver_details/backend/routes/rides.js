// routes/rides.js
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// simple 4‑digit PIN generator
function generatePin() {
  return String(Math.floor(Math.random() * 10000)).padStart(4, '0');
}

// POST /rides – create ride (patient app)
router.post('/', async (req, res) => {
  const {
    riderId,
    pickupLat,
    pickupLng,
    dropLat,
    dropLng,
    distanceKm,
    estimatedFare,
  } = req.body;

  const pin = generatePin();
  console.log('🔑 Generated PIN:', pin, 'Type:', typeof pin);

  try {
    const result = await pool.query(
      `INSERT INTO rides
         (rider_id, pickup_lat, pickup_lng, drop_lat, drop_lng,
          distance_km, estimated_fare, pin, status, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'requested', now())
       RETURNING *`,
      [riderId, pickupLat, pickupLng, dropLat, dropLng, distanceKm, estimatedFare, pin]
    );
    console.log('Ride created:', result.rows[0].id, 'PIN:', pin);
    res.status(201).json({ ride: result.rows[0] });
  } catch (e) {
    console.error('POST /rides error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /rides/available – list rides for drivers to accept
router.get('/available', async (req, res) => {
  try {
    const { lat, lng, radiusKm = 10 } = req.query;

    // For now: return all requested rides without a driver.
    const result = await pool.query(
      `SELECT * FROM rides
       WHERE status = 'requested' AND driver_id IS NULL
       ORDER BY created_at DESC`
    );

    console.log(`GET /rides/available found ${result.rows.length} rides`);
    res.json({ rides: result.rows });
  } catch (e) {
    console.error('GET /rides/available error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rides/:id/assign – driver accepts ride
router.post('/:id/assign', async (req, res) => {
  try {
    const { id } = req.params;
    const { driverId } = req.body;

    if (!driverId) {
      return res.status(400).json({ error: 'driverId required' });
    }

    const result = await pool.query(
      `UPDATE rides
         SET driver_id = $1, status = 'accepted', accepted_at = now()
       WHERE id = $2 AND driver_id IS NULL
       RETURNING *`,
      [driverId, id]
    );

    if (result.rows.length === 0) {
      return res
        .status(404)
        .json({ error: 'Ride not found or already assigned' });
    }

    console.log(`Ride ${id} assigned to driver ${driverId}`);
    res.json({ ride: result.rows[0] });
  } catch (e) {
    console.error('POST /rides/:id/assign error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /rides/:id/driver-location – driver live location updates
router.patch('/:id/driver-location', async (req, res) => {
  try {
    const { id } = req.params;
    const { driverLat, driverLng } = req.body;

    if (driverLat == null || driverLng == null) {
      return res
        .status(400)
        .json({ error: 'driverLat and driverLng required' });
    }

    const result = await pool.query(
      `UPDATE rides
         SET driver_lat = $1, driver_lng = $2
       WHERE id = $3
       RETURNING *`,
      [driverLat, driverLng, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    res.json({ ride: result.rows[0] });
  } catch (e) {
    console.error('PATCH /rides/:id/driver-location error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rides/:id/verify-pin – driver enters passenger PIN
router.post('/:id/verify-pin', async (req, res) => {
  try {
    const { id } = req.params;
    const { pin } = req.body;

    if (!pin) {
      return res.status(400).json({ error: 'pin required' });
    }

    const result = await pool.query(
      `UPDATE rides
         SET status = 'in_progress'
       WHERE id = $1 AND pin = $2
       RETURNING *`,
      [id, pin]
    );

    if (result.rows.length === 0) {
      return res
        .status(400)
        .json({ error: 'Invalid PIN or ride not found' });
    }

    res.json({ ride: result.rows[0] });
  } catch (e) {
    console.error('POST /rides/:id/verify-pin error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /rides/:id/status – update ride status
router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = [
      'requested',
      'accepted',
      'arrived',
      'in_progress',
      'completed',
      'cancelled',
    ];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const result = await pool.query(
      `UPDATE rides
         SET status = $1
       WHERE id = $2
       RETURNING *`,
      [status, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    res.json({ ride: result.rows[0] });
  } catch (e) {
    console.error('PATCH /rides/:id/status error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /rides/:id – get single ride
router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM rides WHERE id = $1', [
      req.params.id,
    ]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ride not found' });
    }
    res.json({ ride: result.rows[0] });
  } catch (e) {
    console.error('GET /rides/:id error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /rides – list rides for a rider (optionally by status)
router.get('/', async (req, res) => {
  try {
    const { rider_id, status } = req.query;

    if (!rider_id) {
      return res.status(400).json({ error: 'rider_id required' });
    }

    const params = [rider_id];
    let where = 'rider_id = $1';

    if (status) {
      params.push(status);
      where += ' AND status = $2';
    }

    const result = await pool.query(
      `SELECT *
         FROM rides
        WHERE ${where}
        ORDER BY created_at DESC`,
      params
    );

    res.json({ rides: result.rows });
  } catch (e) {
    console.error('GET /rides error', e);
    res.status(500).json({ error: 'Server error' });
  }
}); 

module.exports = router;

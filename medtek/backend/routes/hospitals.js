// routes/hospitals.js
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const fetch = require('node-fetch');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /hospitals
router.get('/', async (req, res) => {
  try {
    console.log('GET /hospitals');
    const result = await pool.query(
      'SELECT id, name, latitude, longitude FROM hospitals ORDER BY name'
    );
    res.json({ hospitals: result.rows });
  } catch (e) {
    console.error('GET /hospitals error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /hospitals/nearby-live?lat=17.4&lng=78.4&radius=5000
router.get('/nearby-live', async (req, res) => {
  try {
    const { lat, lng, radius = 5000 } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'lat and lng required' });
    }

    console.log(`GET /hospitals/nearby-live lat=${lat} lng=${lng} radius=${radius}`);

    const url =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json' +
      `?location=${lat},${lng}&radius=${radius}&type=hospital&key=${process.env.GOOGLE_PLACES_KEY}`;

    const r = await fetch(url);
    const json = await r.json();

    if (json.status !== 'OK' && json.status !== 'ZERO_RESULTS') {
      console.error('Google Places error:', json);
      return res.status(500).json({
        error: json.error_message || 'Places API error',
        status: json.status,
      });
    }

    const hospitals = (json.results || []).map((place) => ({
      id: place.place_id,
      name: place.name,
      latitude: place.geometry.location.lat,
      longitude: place.geometry.location.lng,
      address: place.vicinity || '',
      source: 'google_places',
    }));

    console.log(`Found ${hospitals.length} nearby hospitals`);
    res.json({ hospitals });
  } catch (e) {
    console.error('Nearby live error:', e);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/search', async (req, res) => {
  try {
    const { query, lat, lng, radius = 10000 } = req.query;

    if (!query) {
      return res.status(400).json({ error: 'query is required' });
    }

    const result = await pool.query(
      `SELECT id, name, latitude, longitude
       FROM hospitals
       WHERE name ILIKE $1
       ORDER BY name
       LIMIT 20`,
      [`%${query}%`]
    );

    res.json({ hospitals: result.rows });
  } catch (e) {
    console.error('GET /hospitals/search error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /hospitals/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    console.log('GET /hospitals/:id', id);

    const result = await pool.query(
      'SELECT id, name, latitude, longitude FROM hospitals WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Hospital not found' });
    }

    res.json(result.rows[0]);
  } catch (e) {
    console.error('GET /hospitals/:id error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /hospitals/:id/doctors
router.get('/:id/doctors', async (req, res) => {
  try {
    const hospitalId = req.params.id;

    const result = await pool.query(
      `SELECT 
         u.id AS id,
         u.name,
         u.email,
         d.specialization,
         d.experience_years
       FROM doctors d
       JOIN users u ON u.id = d.user_id
       WHERE d.hospital_id = $1
         AND u.role = 'doctor'`,
      [hospitalId]
    );

    res.json({ doctors: result.rows });
  } catch (e) {
    console.error('GET /hospitals/:id/doctors error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /hospitals – doctor creates a new hospital
router.post('/', async (req, res) => {
  try {
    const { name, latitude, longitude, address } = req.body;

    if (!name || latitude == null || longitude == null) {
      return res
        .status(400)
        .json({ error: 'name, latitude, longitude are required' });
    }

    const result = await pool.query(
      `INSERT INTO hospitals (name, latitude, longitude, address)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, latitude, longitude, address`,
      [name, latitude, longitude, address || '']
    );

    res.status(201).json({ hospital: result.rows[0] });
  } catch (e) {
    console.error('POST /hospitals error', e);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

-- users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role VARCHAR(20) NOT NULL,
  profile_picture TEXT,
  -- Added to match code
  specialization VARCHAR(100),
  -- kept for legacy/redundancy if needed
  hospital_name VARCHAR(150),
  experience_years INTEGER,
  about TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- hospitals table
CREATE TABLE hospitals (
  id SERIAL PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  address TEXT,
  city VARCHAR(100),
  -- Added to match code
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  phone VARCHAR(30),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- doctors table
CREATE TABLE doctors (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  -- Added UNIQUE
  hospital_id INTEGER REFERENCES hospitals(id) ON DELETE
  SET NULL,
    specialization VARCHAR(100),
    -- Renamed from specialty
    experience_years INTEGER,
    -- Renamed from experience
    about TEXT,
    -- Verification Columns (POC)
    nmc_number VARCHAR(50),
    verification_points INTEGER DEFAULT 0,
    verification_details JSONB,
    verification_documents JSONB,
    -- End Verification Columns
    verified BOOLEAN DEFAULT FALSE,
    -- Added
    rating NUMERIC(3, 2) DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- appointments table
CREATE TABLE appointments (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  hospital_id INTEGER REFERENCES hospitals(id) ON DELETE
  SET NULL,
    status VARCHAR(20) NOT NULL,
    scheduled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- doctor_reviews table
CREATE TABLE doctor_reviews (
  id SERIAL PRIMARY KEY,
  doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  patient_name VARCHAR(100) NOT NULL,
  rating INTEGER NOT NULL CHECK (
    rating BETWEEN 1 AND 5
  ),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE hospital_doctors (
  user_id INT REFERENCES users(id) ON DELETE CASCADE,
  hospital_id INT REFERENCES hospitals(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, hospital_id)
);
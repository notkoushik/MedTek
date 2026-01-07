-- Create missing tables
CREATE TABLE IF NOT EXISTS patient_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    age INTEGER DEFAULT 0,
    reference_notes JSONB DEFAULT '[]',
    insurances JSONB DEFAULT '[]'
);
CREATE TABLE IF NOT EXISTS patient_doctors (
    patient_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    doctor_id INTEGER REFERENCES users(id) ON DELETE
    SET NULL
);
-- Inspection queries (results will show in console)
SELECT *
FROM users
WHERE role = 'doctor';
SELECT *
FROM doctors;
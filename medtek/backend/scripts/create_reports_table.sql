CREATE TABLE IF NOT EXISTS medical_reports (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL,
    patient_id INTEGER NOT NULL,
    appointment_id INTEGER NOT NULL,
    diagnosis TEXT,
    prescription TEXT,
    lab_tests TEXT,
    lab_tests_count INTEGER DEFAULT 0,
    notes TEXT,
    description_type TEXT,
    description_text TEXT,
    description_image_url TEXT,
    status TEXT DEFAULT 'completed',
    report_status TEXT DEFAULT 'completed',
    -- Snapshot fields (commonly used in reports)
    patient_name TEXT,
    patient_age TEXT,
    condition TEXT,
    triage_diagnosis TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
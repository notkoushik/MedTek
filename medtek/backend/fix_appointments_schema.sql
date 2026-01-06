-- Rename scheduled_at to appointment_date to match code
ALTER TABLE appointments
    RENAME COLUMN scheduled_at TO appointment_date;
-- Add missing columns expected by code
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS triage_diagnosis TEXT;
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS triage_selected_tests TEXT;
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS triage_notes TEXT;
-- Migration: Add Lab Assistant Support
-- Run with: node scripts/apply_migration.js 008_add_lab_assistant.sql
-- 1. Add assigned_hospital_id to users for lab staff assignment
ALTER TABLE users
ADD COLUMN IF NOT EXISTS assigned_hospital_id INTEGER REFERENCES hospitals(id);
-- 2. Add sample_collected status to track sample collection before testing
-- Update lab_tests_json to support: pending -> sample_collected -> done
-- (This is handled at application level, no schema change needed for JSONB)
-- 3. Create index for efficient lab queries
CREATE INDEX IF NOT EXISTS idx_medical_reports_lab_pending ON medical_reports USING GIN (lab_tests_json)
WHERE lab_tests_count > 0;
-- 4. Add hospital_id to medical_reports for easier lab filtering
ALTER TABLE medical_reports
ADD COLUMN IF NOT EXISTS hospital_id INTEGER REFERENCES hospitals(id);
-- Done!
COMMENT ON COLUMN users.assigned_hospital_id IS 'For lab_assistant role: the hospital they work at';
-- Hospital Table Cleanup Script
-- This script will:
-- 1. Show current state
-- 2. Identify duplicates
-- 3. Keep the hospital with complete data, update doctor references, delete old ones
-- First, let's see the current state
SELECT id,
    name,
    COALESCE(address, 'NULL') as address,
    COALESCE(latitude::text, 'NULL') as lat,
    COALESCE(google_place_id, 'NULL') as place_id
FROM hospitals
ORDER BY id;
-- Find hospitals that need cleanup (have NULL coords)
-- Option 1: UPDATE old hospitals with data from the LATEST hospital with same/similar name
-- Option 2: DELETE old incomplete hospitals and update doctors to use new ones
-- Let's do Option 2 (safer - consolidate to new hospitals with complete data)
-- Step 1: For each doctor pointing to old hospital, find a matching new hospital by name pattern
-- Step 2: Update doctor to point to new hospital
-- Step 3: Delete old orphan hospitals
-- START TRANSACTION (run these manually to review each step)
BEGIN;
-- Show doctors and their hospitals before cleanup
SELECT d.user_id,
    u.name as doctor,
    h.id as hosp_id,
    h.name as hospital,
    CASE
        WHEN h.latitude IS NULL THEN 'NEEDS FIX'
        ELSE 'OK'
    END as status
FROM doctors d
    JOIN users u ON d.user_id = u.id
    LEFT JOIN hospitals h ON d.hospital_id = h.id;
-- To run the actual cleanup, execute these UPDATE statements:
-- For each doctor with missing hospital coords, you need to manually map them to new hospitals
-- Example: Update doctor's hospital_id to a valid hospital
-- UPDATE doctors SET hospital_id = (valid_hospital_id) WHERE user_id = (doctor_user_id);
-- After all doctors are updated, delete orphan hospitals
-- DELETE FROM hospitals WHERE id NOT IN (SELECT DISTINCT hospital_id FROM doctors WHERE hospital_id IS NOT NULL);
ROLLBACK;
-- Change to COMMIT when you're ready to apply
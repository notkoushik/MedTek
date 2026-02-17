-- Add google_place_id column to hospitals table
-- Run this in your PostgreSQL database
ALTER TABLE hospitals
ADD COLUMN IF NOT EXISTS google_place_id VARCHAR(255);
-- Create index for faster lookups by google_place_id
CREATE INDEX IF NOT EXISTS idx_hospitals_google_place_id ON hospitals(google_place_id);
-- Verify the column was added
SELECT column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'hospitals';
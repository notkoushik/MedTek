-- Migration: Add verification columns to doctors table
ALTER TABLE doctors
ADD COLUMN IF NOT EXISTS nmc_number VARCHAR(50);
ALTER TABLE doctors
ADD COLUMN IF NOT EXISTS verification_points INTEGER DEFAULT 0;
ALTER TABLE doctors
ADD COLUMN IF NOT EXISTS verification_details JSONB;
ALTER TABLE doctors
ADD COLUMN IF NOT EXISTS verification_documents JSONB;
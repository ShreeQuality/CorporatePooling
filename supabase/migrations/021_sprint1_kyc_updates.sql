-- ==============================================================================
-- Migration 021: Sprint 1 KYC Data Updates
-- Description: Adds missing Vahan and Aadhaar DigiLocker fields to support 
--              the Real-Time API integration and 5-User-Type logic.
-- ==============================================================================

-- 1. Updates to public.users (Area 2: Aadhaar & Driver Intent)
ALTER TABLE public.users 
    ADD COLUMN IF NOT EXISTS date_of_birth DATE,
    ADD COLUMN IF NOT EXISTS home_city VARCHAR(100),
    ADD COLUMN IF NOT EXISTS selfie_photo_url TEXT,
    ADD COLUMN IF NOT EXISTS is_driver BOOLEAN DEFAULT FALSE;

-- 2. Updates to public.vehicles (Area 3: Vahan Data)
ALTER TABLE public.vehicles
    ADD COLUMN IF NOT EXISTS fuel_type VARCHAR(30),
    ADD COLUMN IF NOT EXISTS seating_capacity INTEGER,
    ADD COLUMN IF NOT EXISTS insurance_expiry_date DATE,
    ADD COLUMN IF NOT EXISTS puc_expiry_date DATE,
    ADD COLUMN IF NOT EXISTS vehicle_exterior_photo_url TEXT;

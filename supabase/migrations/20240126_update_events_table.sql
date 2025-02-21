-- Add platform fee payment columns to events table
ALTER TABLE public.events
ADD COLUMN is_platform_fee_paid boolean DEFAULT false,
ADD COLUMN platform_payment_id text,
ADD CONSTRAINT events_platform_payment_id_key UNIQUE (platform_payment_id);

-- Add draft status to event_status enum if not exists
DO $$ 
BEGIN 
    ALTER TYPE event_status ADD VALUE IF NOT EXISTS 'draft' BEFORE 'upcoming';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

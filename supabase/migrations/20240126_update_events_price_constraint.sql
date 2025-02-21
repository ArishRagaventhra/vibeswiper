-- Drop existing price constraint if it exists
DO $$ 
BEGIN
    ALTER TABLE public.events DROP CONSTRAINT IF EXISTS valid_price;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Add updated price constraint that allows 0 for free events
ALTER TABLE public.events
ADD CONSTRAINT valid_price 
CHECK (
    (event_type = 'free' AND (ticket_price IS NULL OR ticket_price = 0)) OR 
    (event_type = 'paid' AND ticket_price > 0)
);

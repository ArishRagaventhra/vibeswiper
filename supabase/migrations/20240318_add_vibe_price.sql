-- Add vibe_price column to events table
ALTER TABLE public.events
ADD COLUMN vibe_price numeric(10, 2) null;

-- Update the valid_vibe_price constraint to handle free events
ALTER TABLE public.events
ADD CONSTRAINT valid_vibe_price CHECK (
    (event_type = 'free' AND vibe_price IS NULL) OR
    (event_type = 'paid' AND vibe_price IS NOT NULL AND vibe_price <= ticket_price)
);

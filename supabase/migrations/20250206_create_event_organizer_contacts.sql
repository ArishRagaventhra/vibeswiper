-- Create event_organizer_contacts table
CREATE TABLE IF NOT EXISTS public.event_organizer_contacts (
    id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
    event_id uuid NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    phone text NOT NULL,
    contact_verified boolean DEFAULT false,
    verification_deadline timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT event_organizer_contacts_pkey PRIMARY KEY (id),
    CONSTRAINT event_organizer_contacts_event_id_fkey 
        FOREIGN KEY (event_id) 
        REFERENCES public.events(id) 
        ON DELETE CASCADE,
    CONSTRAINT event_organizer_contacts_email_check 
        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT event_organizer_contacts_phone_check 
        CHECK (phone ~* '^\+?[\d\s-]{10,}$')
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_event_organizer_contacts_event_id 
ON public.event_organizer_contacts(event_id);

CREATE INDEX IF NOT EXISTS idx_event_organizer_contacts_verification 
ON public.event_organizer_contacts(contact_verified, verification_deadline);

-- Create RLS policies
ALTER TABLE public.event_organizer_contacts ENABLE ROW LEVEL SECURITY;

-- Policy for inserting contacts (event creators only)
CREATE POLICY "Users can create their own event contacts" ON public.event_organizer_contacts
    FOR INSERT 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

-- Policy for viewing contacts (event creators and admins)
CREATE POLICY "Users can view their own event contacts" ON public.event_organizer_contacts
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
        OR 
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

-- Policy for updating contacts (event creators only)
CREATE POLICY "Users can update their own event contacts" ON public.event_organizer_contacts
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

-- Policy for deleting contacts (event creators and admins)
CREATE POLICY "Users can delete their own event contacts" ON public.event_organizer_contacts
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
        OR 
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.event_organizer_contacts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Function to delete unverified events
CREATE OR REPLACE FUNCTION public.delete_unverified_events()
RETURNS void AS $$
BEGIN
    DELETE FROM public.events
    WHERE id IN (
        SELECT event_id 
        FROM public.event_organizer_contacts
        WHERE contact_verified = false
        AND verification_deadline < now()
    );
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT ALL ON public.event_organizer_contacts TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

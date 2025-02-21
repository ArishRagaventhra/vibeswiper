-- Drop function and trigger
DROP TRIGGER IF EXISTS set_updated_at ON public.event_organizer_contacts;
DROP FUNCTION IF EXISTS public.handle_updated_at();
DROP FUNCTION IF EXISTS public.delete_unverified_events();

-- Drop policies
DROP POLICY IF EXISTS "Users can create their own event contacts" ON public.event_organizer_contacts;
DROP POLICY IF EXISTS "Users can view their own event contacts" ON public.event_organizer_contacts;
DROP POLICY IF EXISTS "Users can update their own event contacts" ON public.event_organizer_contacts;
DROP POLICY IF EXISTS "Users can delete their own event contacts" ON public.event_organizer_contacts;

-- Drop indexes
DROP INDEX IF EXISTS idx_event_organizer_contacts_event_id;
DROP INDEX IF EXISTS idx_event_organizer_contacts_verification;

-- Drop table
DROP TABLE IF EXISTS public.event_organizer_contacts;

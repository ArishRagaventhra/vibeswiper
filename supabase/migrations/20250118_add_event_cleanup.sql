-- Function to clean up events marked for deletion
CREATE OR REPLACE FUNCTION cleanup_deleted_events()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete events where deleted_at is in the past
  DELETE FROM public.events
  WHERE deleted_at IS NOT NULL
    AND deleted_at < CURRENT_TIMESTAMP;
END;
$$;

-- Create a scheduled job to run the cleanup function daily
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'cleanup-deleted-events',           -- name of the cron job
  '0 0 * * *',                       -- run at midnight every day
  'SELECT cleanup_deleted_events()'   -- SQL to execute
);

-- Drop existing policies first
DROP POLICY IF EXISTS "Enable soft delete for event creators" ON public.events;
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON public.events;
DROP POLICY IF EXISTS "Enable delete for event creators after soft delete period" ON public.events;

-- Add RLS policies for soft delete
CREATE POLICY "Enable soft delete for event creators"
ON public.events
FOR UPDATE
TO authenticated
USING (auth.uid() = creator_id)
WITH CHECK (
  auth.uid() = creator_id 
  AND (
    -- Allow setting deleted_at only if it was not already set
    (deleted_at IS NULL AND cancellation_reason IS NOT NULL) OR
    -- Allow normal updates when not deleting
    deleted_at IS NULL
  )
);

-- Update existing delete policy to prevent hard deletes
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON public.events;
CREATE POLICY "Enable delete for event creators after soft delete period"
ON public.events
FOR DELETE
TO authenticated
USING (
  auth.uid() = creator_id 
  AND deleted_at IS NOT NULL 
  AND deleted_at < CURRENT_TIMESTAMP
);

-- Add index for efficient querying of non-deleted events
DROP INDEX IF EXISTS idx_events_active;
CREATE INDEX idx_events_active ON public.events (created_at)
WHERE deleted_at IS NULL;

-- Add deleted_at column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN deleted_at timestamp with time zone;

-- Create function to handle account recovery on login
CREATE OR REPLACE FUNCTION public.handle_account_recovery()
RETURNS trigger AS $$
BEGIN
  -- If account was marked for deletion and user logs in, recover the account
  IF NEW.last_seen IS NOT NULL AND OLD.deleted_at IS NOT NULL THEN
    NEW.deleted_at = NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for account recovery
CREATE TRIGGER on_account_recovery
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_account_recovery();

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."profiles";
DROP POLICY IF EXISTS "Enable users to view their own data only" ON "public"."profiles";

-- Create new policies with soft delete conditions
CREATE POLICY "Enable read access for all users"
ON "public"."profiles"
FOR SELECT
USING (deleted_at IS NULL);

CREATE POLICY "Enable users to view their own data only"
ON "public"."profiles"
FOR SELECT
TO authenticated
USING ((auth.uid() = id) AND (deleted_at IS NULL OR auth.uid() = id));

-- Create a scheduled function to permanently delete accounts after 30 days
CREATE OR REPLACE FUNCTION public.delete_expired_accounts()
RETURNS void AS $$
BEGIN
  -- Delete auth.users entries which will cascade to profiles
  DELETE FROM auth.users
  WHERE id IN (
    SELECT id FROM public.profiles
    WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '30 days'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

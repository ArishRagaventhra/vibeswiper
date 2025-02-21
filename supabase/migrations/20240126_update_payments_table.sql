-- Drop the existing table if it exists
DROP TABLE IF EXISTS payments;

-- Create the payments table with proper constraints
CREATE TABLE payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    event_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    razorpay_payment_id TEXT NOT NULL UNIQUE,
    razorpay_order_id TEXT,
    status TEXT NOT NULL DEFAULT 'success',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(event_id)  -- Remove this if you want to allow multiple payments per event
);

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own payments" ON payments;
DROP POLICY IF EXISTS "Users can insert their own payments" ON payments;
DROP POLICY IF EXISTS "Users can update their own payments" ON payments;

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own payments"
ON payments
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own payments"
ON payments
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own payments"
ON payments
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON payments TO authenticated;

-- Create indexes
CREATE INDEX IF NOT EXISTS payments_user_id_idx ON payments(user_id);
CREATE INDEX IF NOT EXISTS payments_event_id_idx ON payments(event_id);
CREATE INDEX IF NOT EXISTS payments_razorpay_payment_id_idx ON payments(razorpay_payment_id);

-- Remove the UNIQUE constraint on event_id if you want to allow multiple payments per event
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_event_id_key;

-- Create payments table
create table public.payments (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) not null,
    event_id uuid references events(id) not null,
    amount decimal not null,
    razorpay_payment_id text not null,
    razorpay_order_id text not null,
    status text not null check (status in ('pending', 'success', 'failed')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,

    -- Indexes for faster queries
    constraint payments_razorpay_payment_id_key unique (razorpay_payment_id),
    constraint payments_razorpay_order_id_key unique (razorpay_order_id)
);

-- Set up RLS (Row Level Security)
alter table public.payments enable row level security;

-- Policies
create policy "Users can view their own payments"
    on public.payments for select
    using (auth.uid() = user_id);

create policy "Service role can create payments"
    on public.payments for insert
    to service_role
    with check (true);

create policy "Service role can update payments"
    on public.payments for update
    to service_role
    using (true);

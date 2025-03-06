-- Create enum for question types
CREATE TYPE question_type AS ENUM ('text', 'multiple_choice', 'yes_no');

-- Create table for event custom questions
CREATE TABLE public.event_custom_questions (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
    question_text text NOT NULL,
    question_type question_type NOT NULL DEFAULT 'text',
    options jsonb, -- For multiple choice questions
    is_required boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create trigger function to enforce max questions per event
CREATE OR REPLACE FUNCTION check_max_questions_per_event()
RETURNS TRIGGER AS $$
BEGIN
    IF (
        SELECT COUNT(*)
        FROM public.event_custom_questions
        WHERE event_id = NEW.event_id
    ) >= 5 THEN
        RAISE EXCEPTION 'Maximum of 5 questions allowed per event';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER enforce_max_questions_per_event
    BEFORE INSERT ON public.event_custom_questions
    FOR EACH ROW
    EXECUTE FUNCTION check_max_questions_per_event();

-- Create table for event refund policies
CREATE TABLE public.event_refund_policies (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE UNIQUE,
    policy_text text NOT NULL,
    refund_window_hours integer, -- Number of hours before event start when refund is possible
    refund_percentage decimal(5,2), -- Percentage of ticket price to be refunded
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create table for event acceptance confirmations
CREATE TABLE public.event_acceptance_confirmations (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE UNIQUE,
    confirmation_text text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on all tables
ALTER TABLE public.event_custom_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_refund_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_acceptance_confirmations ENABLE ROW LEVEL SECURITY;

-- Create policies for event custom questions
CREATE POLICY "Users can view event custom questions" ON public.event_custom_questions
    FOR SELECT USING (true);

CREATE POLICY "Event creators can manage their event custom questions" ON public.event_custom_questions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

-- Create policies for event refund policies
CREATE POLICY "Users can view event refund policies" ON public.event_refund_policies
    FOR SELECT USING (true);

CREATE POLICY "Event creators can manage their event refund policies" ON public.event_refund_policies
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

-- Create policies for event acceptance confirmations
CREATE POLICY "Users can view event acceptance confirmations" ON public.event_acceptance_confirmations
    FOR SELECT USING (true);

CREATE POLICY "Event creators can manage their event acceptance confirmations" ON public.event_acceptance_confirmations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

-- Create indexes for better query performance
CREATE INDEX idx_event_custom_questions_event_id ON public.event_custom_questions(event_id);
CREATE INDEX idx_event_refund_policies_event_id ON public.event_refund_policies(event_id);
CREATE INDEX idx_event_acceptance_confirmations_event_id ON public.event_acceptance_confirmations(event_id);

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.event_custom_questions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.event_refund_policies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.event_acceptance_confirmations TO authenticated;


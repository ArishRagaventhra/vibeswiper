-- Create table for event question responses
CREATE TABLE public.event_question_responses (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    question_id uuid REFERENCES public.event_custom_questions(id) ON DELETE CASCADE,
    response_text text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(event_id, user_id, question_id) -- Each user can only answer each question once
);

-- Create table for event acceptance records
CREATE TABLE public.event_acceptance_records (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    accepted_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    acceptance_text text NOT NULL, -- Store the version of the text they accepted
    UNIQUE(event_id, user_id)
);

-- Create table for refund policy acknowledgments
CREATE TABLE public.event_refund_acknowledgments (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    acknowledged_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    policy_text text NOT NULL, -- Store the version of the policy they acknowledged
    UNIQUE(event_id, user_id)
);

-- Enable RLS on all tables
ALTER TABLE public.event_question_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_acceptance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_refund_acknowledgments ENABLE ROW LEVEL SECURITY;

-- Create policies for event question responses
CREATE POLICY "Users can view their own responses" ON public.event_question_responses
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Event creators can view all responses" ON public.event_question_responses
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

CREATE POLICY "Users can create their own responses" ON public.event_question_responses
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create policies for event acceptance records
CREATE POLICY "Users can view their own acceptance records" ON public.event_acceptance_records
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Event creators can view all acceptance records" ON public.event_acceptance_records
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

CREATE POLICY "Users can create their own acceptance records" ON public.event_acceptance_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create policies for refund policy acknowledgments
CREATE POLICY "Users can view their own acknowledgments" ON public.event_refund_acknowledgments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Event creators can view all acknowledgments" ON public.event_refund_acknowledgments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.events
            WHERE id = event_id
            AND creator_id = auth.uid()
        )
    );

CREATE POLICY "Users can create their own acknowledgments" ON public.event_refund_acknowledgments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create indexes for better query performance
CREATE INDEX idx_event_question_responses_event_id ON public.event_question_responses(event_id);
CREATE INDEX idx_event_question_responses_user_id ON public.event_question_responses(user_id);
CREATE INDEX idx_event_acceptance_records_event_id ON public.event_acceptance_records(event_id);
CREATE INDEX idx_event_acceptance_records_user_id ON public.event_acceptance_records(user_id);
CREATE INDEX idx_event_refund_acknowledgments_event_id ON public.event_refund_acknowledgments(event_id);
CREATE INDEX idx_event_refund_acknowledgments_user_id ON public.event_refund_acknowledgments(user_id);

-- Grant necessary permissions
GRANT SELECT, INSERT ON public.event_question_responses TO authenticated;
GRANT SELECT, INSERT ON public.event_acceptance_records TO authenticated;
GRANT SELECT, INSERT ON public.event_refund_acknowledgments TO authenticated;

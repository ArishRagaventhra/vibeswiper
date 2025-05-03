create table public.webhook_events (
  id uuid not null default gen_random_uuid (),
  event_id text not null,
  event_type text not null default ''::text,
  payload jsonb not null,
  processed_at timestamp with time zone not null,
  created_at timestamp with time zone not null default now(),
  constraint webhook_events_pkey primary key (id),
  constraint webhook_events_event_id_key unique (event_id)
) TABLESPACE pg_default;

create index IF not exists webhook_events_event_type_idx on public.webhook_events using btree (event_type) TABLESPACE pg_default;
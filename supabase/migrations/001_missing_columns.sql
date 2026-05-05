-- =============================================================================
-- Migration 001 — Add columns required by the updated Flutter app
-- Run this in the Supabase SQL Editor on an EXISTING project.
-- Every statement is idempotent (safe to run more than once).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- performers table
-- ---------------------------------------------------------------------------

-- Profile photo URL (used by Portfolio tab and Dashboard header)
alter table public.performers
  add column if not exists avatar_url text;

-- Approval workflow column (was missing in some older schemas)
alter table public.performers
  add column if not exists approval_status text not null default 'pending'
    check (approval_status in ('pending','approved','rejected'));

-- Social links stored as JSON object  {"Instagram":"...", "YouTube":"..."}
alter table public.performers
  add column if not exists social_links jsonb not null default '{}';

-- updated_at timestamp
alter table public.performers
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- events table
-- ---------------------------------------------------------------------------

-- Free-text description shown on event cards
alter table public.events
  add column if not exists description text;

-- When performers must register by
alter table public.events
  add column if not exists registration_deadline timestamptz;

-- Maximum number of performers allowed to register
alter table public.events
  add column if not exists max_performers int not null default 50;

-- When voting closes (may differ from event end)
alter table public.events
  add column if not exists voting_deadline timestamptz;

-- When the event record expires / is archived
alter table public.events
  add column if not exists expires_at timestamptz;

-- End date/time of the event (separate from event_date which is the start)
alter table public.events
  add column if not exists end_date timestamptz;

-- How many votes each student can cast in this event
alter table public.events
  add column if not exists votes_per_user int not null default 1;

-- updated_at timestamp
alter table public.events
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- notifications table
-- ---------------------------------------------------------------------------

-- Relax the type constraint to match the app's NotificationType enum.
-- Drop the old constraint first (name may vary), then add the correct one.
alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
    check (type in ('info','success','warning','error','event_update','vote_reminder'));

-- is_read column (mark-as-read feature)
alter table public.notifications
  add column if not exists is_read boolean not null default false;

-- Optional JSON payload for deep-linking
alter table public.notifications
  add column if not exists data jsonb;

-- ---------------------------------------------------------------------------
-- votes table
-- ---------------------------------------------------------------------------

-- score column (1–5 rating per vote)
alter table public.votes
  add column if not exists score int check (score between 1 and 5);

-- voted_at timestamp
alter table public.votes
  add column if not exists voted_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- feedback table
-- ---------------------------------------------------------------------------

-- is_public flag
alter table public.feedback
  add column if not exists is_public boolean not null default true;

-- ---------------------------------------------------------------------------
-- Unique constraint on votes (one vote per user per performer per event)
-- ---------------------------------------------------------------------------
alter table public.votes
  drop constraint if exists votes_user_performer_event_unique;

alter table public.votes
  add constraint votes_user_performer_event_unique
    unique (event_id, user_id, performer_id);

-- ---------------------------------------------------------------------------
-- Unique constraint on event_registrations
-- ---------------------------------------------------------------------------
alter table public.event_registrations
  drop constraint if exists event_registrations_event_performer_unique;

alter table public.event_registrations
  add constraint event_registrations_event_performer_unique
    unique (event_id, performer_id);

-- ---------------------------------------------------------------------------
-- Indexes for new columns
-- ---------------------------------------------------------------------------
create index if not exists idx_performers_approval_status
  on public.performers(approval_status);

create index if not exists idx_votes_performer_id
  on public.votes(performer_id);

create index if not exists idx_notifications_is_read
  on public.notifications(user_id, is_read);

create index if not exists idx_events_status
  on public.events(status);

-- ---------------------------------------------------------------------------
-- updated_at auto-stamp trigger (idempotent)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_performers_updated_at on public.performers;
create trigger trg_performers_updated_at
  before update on public.performers
  for each row execute function public.set_updated_at();

drop trigger if exists trg_events_updated_at on public.events;
create trigger trg_events_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- handle_new_user trigger — creates users row + performers row on sign-up
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, name, role, created_at, updated_at)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'student'),
    now(),
    now()
  )
  on conflict (id) do update
    set email      = excluded.email,
        updated_at = now();

  if coalesce(new.raw_user_meta_data->>'role', 'student') = 'performer' then
    insert into public.performers (id, created_at, updated_at)
    values (new.id, now(), now())
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Duplicate-vote guard trigger (idempotent)
-- ---------------------------------------------------------------------------
create or replace function public.prevent_duplicate_vote()
returns trigger language plpgsql as $$
begin
  if exists (
    select 1 from public.votes
    where user_id      = new.user_id
      and performer_id = new.performer_id
      and event_id     = new.event_id
  ) then
    raise exception 'You have already voted for this performer in this event';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_duplicate_vote on public.votes;
create trigger trg_prevent_duplicate_vote
  before insert on public.votes
  for each row execute function public.prevent_duplicate_vote();

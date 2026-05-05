-- =============================================================================
-- Campus Talent Show — Full Schema
-- Run this once on a fresh Supabase project.
-- For existing projects use migrations/001_missing_columns.sql instead.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- USERS
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null unique,
  name        text,
  role        text not null default 'student'
                check (role in ('admin','performer','student')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- PERFORMERS
-- (one row per performer user — id == users.id)
-- ---------------------------------------------------------------------------
create table if not exists public.performers (
  id               uuid primary key references public.users(id) on delete cascade,
  bio              text,
  talent_type      text not null default 'other'
                     check (talent_type in ('music','dance','comedy','drama','magic','other')),
  experience_level text not null default 'beginner'
                     check (experience_level in ('beginner','intermediate','advanced')),
  social_links     jsonb not null default '{}',
  avatar_url       text,
  approval_status  text not null default 'pending'
                     check (approval_status in ('pending','approved','rejected')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- EVENTS
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id                      uuid primary key default uuid_generate_v4(),
  title                   text not null,
  description             text,
  event_date              timestamptz not null,
  end_date                timestamptz,
  registration_deadline   timestamptz,
  voting_deadline         timestamptz,
  expires_at              timestamptz,
  location                text,
  max_performers          int not null default 50,
  votes_per_user          int not null default 1,
  status                  text not null default 'upcoming'
                            check (status in ('upcoming','active','completed','cancelled')),
  created_by              uuid references public.users(id) on delete set null,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- EVENT REGISTRATIONS
-- ---------------------------------------------------------------------------
create table if not exists public.event_registrations (
  id                       uuid primary key default uuid_generate_v4(),
  event_id                 uuid not null references public.events(id) on delete cascade,
  performer_id             uuid not null references public.performers(id) on delete cascade,
  performance_title        text not null,
  performance_description  text,
  duration_minutes         int,
  status                   text not null default 'pending'
                             check (status in ('pending','approved','rejected')),
  submission_date          timestamptz not null default now(),
  unique (event_id, performer_id)
);

-- ---------------------------------------------------------------------------
-- VOTES
-- ---------------------------------------------------------------------------
create table if not exists public.votes (
  id           uuid primary key default uuid_generate_v4(),
  event_id     uuid not null references public.events(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  performer_id uuid not null references public.performers(id) on delete cascade,
  score        int not null check (score between 1 and 5),
  voted_at     timestamptz not null default now(),
  unique (event_id, user_id, performer_id)
);

-- ---------------------------------------------------------------------------
-- FEEDBACK
-- ---------------------------------------------------------------------------
create table if not exists public.feedback (
  id           uuid primary key default uuid_generate_v4(),
  event_id     uuid not null references public.events(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  performer_id uuid not null references public.performers(id) on delete cascade,
  rating       int check (rating between 1 and 5),
  comment      text,
  is_public    boolean not null default true,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- NOTIFICATIONS
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references public.users(id) on delete cascade,
  title      text not null,
  message    text not null,
  type       text not null default 'info'
               check (type in ('info','success','warning','error','event_update','vote_reminder')),
  is_read    boolean not null default false,
  data       jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- INDEXES
-- ---------------------------------------------------------------------------
create index if not exists idx_performers_talent_type      on public.performers(talent_type);
create index if not exists idx_performers_approval_status  on public.performers(approval_status);
create index if not exists idx_events_status               on public.events(status);
create index if not exists idx_events_event_date           on public.events(event_date);
create index if not exists idx_event_regs_event_id         on public.event_registrations(event_id);
create index if not exists idx_event_regs_performer_id     on public.event_registrations(performer_id);
create index if not exists idx_votes_event_id              on public.votes(event_id);
create index if not exists idx_votes_performer_id          on public.votes(performer_id);
create index if not exists idx_votes_user_id               on public.votes(user_id);
create index if not exists idx_feedback_performer_id       on public.feedback(performer_id);
create index if not exists idx_notifications_user_id       on public.notifications(user_id);
create index if not exists idx_notifications_is_read       on public.notifications(user_id, is_read);

-- ---------------------------------------------------------------------------
-- AUTO-CREATE USER ROW ON SIGN-UP
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

  -- If the role is performer, also create a performers row
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
-- PREVENT DUPLICATE VOTES (belt-and-suspenders alongside the unique index)
-- ---------------------------------------------------------------------------
create or replace function public.prevent_duplicate_vote()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1 from public.votes
    where user_id    = new.user_id
      and performer_id = new.performer_id
      and event_id   = new.event_id
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

-- ---------------------------------------------------------------------------
-- UPDATED_AT auto-stamp
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_users_updated_at     on public.users;
drop trigger if exists trg_performers_updated_at on public.performers;
drop trigger if exists trg_events_updated_at     on public.events;

create trigger trg_users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

create trigger trg_performers_updated_at
  before update on public.performers
  for each row execute function public.set_updated_at();

create trigger trg_events_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

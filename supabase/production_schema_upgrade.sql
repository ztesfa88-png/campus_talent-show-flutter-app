-- Production upgrade for Campus Talent Show
-- Run this in Supabase SQL editor after base schema.

create table if not exists categories (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  slug text not null unique,
  created_at timestamptz not null default now()
);

alter table performers
  add column if not exists category_id uuid references categories(id);

create index if not exists idx_performers_category_id on performers(category_id);

-- Optional media fields for performer profiles.
alter table performers
  add column if not exists image_url text,
  add column if not exists video_url text;

-- Strict anti-fraud helper: block multiple votes by same user for same performer/event.
create or replace function prevent_duplicate_vote()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from votes
    where user_id = new.user_id
      and performer_id = new.performer_id
      and event_id = new.event_id
  ) then
    raise exception 'Duplicate vote denied for performer and event';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_duplicate_vote on votes;
create trigger trg_prevent_duplicate_vote
before insert on votes
for each row execute procedure prevent_duplicate_vote();

-- Daily vote cap (optional security hardening)
create or replace function enforce_daily_vote_cap(max_votes int default 40)
returns trigger
language plpgsql
as $$
declare
  daily_count int;
begin
  select count(*) into daily_count
  from votes
  where user_id = new.user_id
    and voted_at::date = now()::date;

  if daily_count >= max_votes then
    raise exception 'Daily vote cap reached';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_daily_vote_cap on votes;
create trigger trg_enforce_daily_vote_cap
before insert on votes
for each row execute procedure enforce_daily_vote_cap(40);

-- Notification types for required events.
alter table notifications
  drop constraint if exists notifications_type_check;

alter table notifications
  add constraint notifications_type_check
  check (type in (
    'info','success','warning','error',
    'event_update','vote_reminder',
    'new_performer','voting_start','voting_end','vote_confirmation'
  ));

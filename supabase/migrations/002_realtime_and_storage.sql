-- =============================================================================
-- Migration 002 — Realtime publication + Storage bucket
-- Run in the Supabase SQL Editor AFTER migration 001.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Realtime
-- Enable change-data-capture on the three tables the app subscribes to.
-- ---------------------------------------------------------------------------

-- Add tables to the supabase_realtime publication (idempotent via DO block)
do $$
begin
  -- votes
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'votes'
  ) then
    alter publication supabase_realtime add table public.votes;
  end if;

  -- notifications
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;

  -- events
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'events'
  ) then
    alter publication supabase_realtime add table public.events;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage bucket for performer avatars
-- The bucket must be created via the Supabase Dashboard or Management API.
-- The SQL below sets the RLS policies on the storage.objects table so that:
--   • Anyone can read avatar images (public bucket)
--   • A performer can upload/replace only their own avatar
--   • Admins can manage all avatars
-- ---------------------------------------------------------------------------

-- Allow public reads on the avatars bucket
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

-- Performers can upload their own avatar (path must start with their user id)
drop policy if exists "avatars_performer_upload" on storage.objects;
create policy "avatars_performer_upload" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(storage.filename(name), '.', 1) = auth.uid()::text
  );

-- Performers can replace (upsert) their own avatar
drop policy if exists "avatars_performer_update" on storage.objects;
create policy "avatars_performer_update" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and split_part(storage.filename(name), '.', 1) = auth.uid()::text
  );

-- Admins can delete any avatar
drop policy if exists "avatars_admin_delete" on storage.objects;
create policy "avatars_admin_delete" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and exists (
      select 1 from public.users
      where id = auth.uid() and role = 'admin'
    )
  );

-- =============================================================================
-- Campus Talent Show — Row Level Security Policies
-- Run AFTER schema.sql (or after migrations/001_missing_columns.sql on
-- an existing project).
-- Safe to re-run: all policies use CREATE POLICY IF NOT EXISTS or are
-- dropped first.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Enable RLS on every table
-- ---------------------------------------------------------------------------
alter table public.users              enable row level security;
alter table public.performers         enable row level security;
alter table public.events             enable row level security;
alter table public.event_registrations enable row level security;
alter table public.votes              enable row level security;
alter table public.feedback           enable row level security;
alter table public.notifications      enable row level security;

-- ---------------------------------------------------------------------------
-- Helper: is the current user an admin?
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
$$;

-- =============================================================================
-- USERS
-- =============================================================================
drop policy if exists "users_select"        on public.users;
drop policy if exists "users_insert_own"    on public.users;
drop policy if exists "users_update_own"    on public.users;
drop policy if exists "users_admin_all"     on public.users;

-- Anyone authenticated can read all user rows (needed for name lookups)
create policy "users_select" on public.users
  for select using (true);

-- A user can insert only their own row
create policy "users_insert_own" on public.users
  for insert with check (auth.uid() = id);

-- A user can update only their own row; admins can update any row
create policy "users_update_own" on public.users
  for update using (auth.uid() = id or public.is_admin());

-- Admins can delete users
create policy "users_admin_all" on public.users
  for delete using (public.is_admin());

-- =============================================================================
-- PERFORMERS
-- =============================================================================
drop policy if exists "performers_select"       on public.performers;
drop policy if exists "performers_insert_own"   on public.performers;
drop policy if exists "performers_update_own"   on public.performers;
drop policy if exists "performers_admin_all"    on public.performers;

-- Everyone can read approved performers; performers can read their own row
create policy "performers_select" on public.performers
  for select using (
    approval_status = 'approved'
    or id = auth.uid()
    or public.is_admin()
  );

-- A performer can insert only their own row
create policy "performers_insert_own" on public.performers
  for insert with check (auth.uid() = id);

-- A performer can update only their own row; admins can update any row
create policy "performers_update_own" on public.performers
  for update using (auth.uid() = id or public.is_admin());

-- Admins can delete performer rows
create policy "performers_admin_all" on public.performers
  for delete using (public.is_admin());

-- =============================================================================
-- EVENTS
-- =============================================================================
drop policy if exists "events_select"     on public.events;
drop policy if exists "events_admin_all"  on public.events;

-- Everyone can read events
create policy "events_select" on public.events
  for select using (true);

-- Only admins can insert / update / delete events
create policy "events_admin_all" on public.events
  for all using (public.is_admin())
  with check (public.is_admin());

-- =============================================================================
-- EVENT REGISTRATIONS
-- =============================================================================
drop policy if exists "regs_select"           on public.event_registrations;
drop policy if exists "regs_insert_performer" on public.event_registrations;
drop policy if exists "regs_update_own"       on public.event_registrations;
drop policy if exists "regs_delete_own"       on public.event_registrations;
drop policy if exists "regs_admin_all"        on public.event_registrations;

-- Performers can see their own registrations; admins see all
create policy "regs_select" on public.event_registrations
  for select using (
    performer_id = auth.uid()
    or public.is_admin()
  );

-- Performers can register themselves
create policy "regs_insert_performer" on public.event_registrations
  for insert with check (
    auth.uid() = performer_id
    and exists (
      select 1 from public.users
      where id = auth.uid() and role = 'performer'
    )
  );

-- Performers can update their own pending registrations; admins can update any
create policy "regs_update_own" on public.event_registrations
  for update using (
    (auth.uid() = performer_id and status = 'pending')
    or public.is_admin()
  );

-- Performers can cancel their own registrations; admins can delete any
create policy "regs_delete_own" on public.event_registrations
  for delete using (
    auth.uid() = performer_id
    or public.is_admin()
  );

-- =============================================================================
-- VOTES
-- =============================================================================
drop policy if exists "votes_select"        on public.votes;
drop policy if exists "votes_insert_student" on public.votes;
drop policy if exists "votes_admin_all"     on public.votes;

-- Users can read all votes (needed for leaderboard); own votes always visible
create policy "votes_select" on public.votes
  for select using (true);

-- Only students can insert votes; enforced by trigger + unique index too
create policy "votes_insert_student" on public.votes
  for insert with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.users
      where id = auth.uid() and role = 'student'
    )
  );

-- Admins can manage all votes (e.g. reset for an event)
create policy "votes_admin_all" on public.votes
  for all using (public.is_admin())
  with check (public.is_admin());

-- =============================================================================
-- FEEDBACK
-- =============================================================================
drop policy if exists "feedback_select"         on public.feedback;
drop policy if exists "feedback_insert_student" on public.feedback;
drop policy if exists "feedback_update_own"     on public.feedback;
drop policy if exists "feedback_admin_all"      on public.feedback;

-- Public feedback is readable by everyone; private only by owner or admin
create policy "feedback_select" on public.feedback
  for select using (
    is_public = true
    or user_id = auth.uid()
    or public.is_admin()
  );

-- Students can submit feedback
create policy "feedback_insert_student" on public.feedback
  for insert with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.users
      where id = auth.uid() and role = 'student'
    )
  );

-- Users can update their own feedback
create policy "feedback_update_own" on public.feedback
  for update using (auth.uid() = user_id);

-- Admins can manage all feedback
create policy "feedback_admin_all" on public.feedback
  for all using (public.is_admin())
  with check (public.is_admin());

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================
drop policy if exists "notifs_select_own"  on public.notifications;
drop policy if exists "notifs_insert"      on public.notifications;
drop policy if exists "notifs_update_own"  on public.notifications;
drop policy if exists "notifs_admin_all"   on public.notifications;

-- Users can only read their own notifications
create policy "notifs_select_own" on public.notifications
  for select using (user_id = auth.uid() or public.is_admin());

-- Any authenticated user (or service role) can insert notifications
-- (needed for vote confirmations, broadcast, etc.)
create policy "notifs_insert" on public.notifications
  for insert with check (true);

-- Users can mark their own notifications as read
create policy "notifs_update_own" on public.notifications
  for update using (user_id = auth.uid() or public.is_admin());

-- Admins can delete notifications
create policy "notifs_admin_all" on public.notifications
  for delete using (public.is_admin());

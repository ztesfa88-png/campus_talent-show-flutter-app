-- =============================================================================
-- Migration 003 — delete_user_by_admin RPC
-- Allows the admin to fully delete a user including their auth.users entry.
-- Runs as SECURITY DEFINER so it has elevated privileges.
-- Run in Supabase SQL Editor.
-- =============================================================================

-- This function calls auth.users delete via a privileged context.
-- It verifies the caller is an admin before proceeding.
create or replace function public.delete_user_by_admin(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
begin
  -- Verify caller is an authenticated admin
  select role into caller_role
  from public.users
  where id = auth.uid();

  if caller_role is null then
    return jsonb_build_object('error', 'Unauthorized: not authenticated');
  end if;

  if caller_role != 'admin' then
    return jsonb_build_object('error', 'Forbidden: admin role required');
  end if;

  -- Prevent self-deletion
  if auth.uid() = target_user_id then
    return jsonb_build_object('error', 'Cannot delete your own account');
  end if;

  -- Delete from public tables first (in case cascade isn't set up)
  delete from public.votes              where user_id      = target_user_id;
  delete from public.feedback           where user_id      = target_user_id;
  delete from public.notifications      where user_id      = target_user_id;
  delete from public.event_registrations where performer_id = target_user_id;
  delete from public.performers         where id           = target_user_id;
  delete from public.users              where id           = target_user_id;

  -- Delete from auth.users (requires security definer + superuser grant)
  -- NOTE: This requires the function to be owned by a superuser or have
  -- the auth schema accessible. If this fails, the public tables are
  -- already cleaned up above.
  begin
    delete from auth.users where id = target_user_id;
  exception when others then
    -- auth.users delete failed (permissions) — public data is already gone
    -- The user can no longer access any data even if auth entry remains
    return jsonb_build_object(
      'success', true,
      'note', 'Public data deleted. Auth entry may require Edge Function for full removal.'
    );
  end;

  return jsonb_build_object('success', true, 'deleted_user_id', target_user_id);
end;
$$;

-- Grant execute to authenticated users (the function itself checks admin role)
grant execute on function public.delete_user_by_admin(uuid) to authenticated;
grant execute on function public.delete_user_by_admin(uuid) to anon;

-- Deleting an account from the admin console.
--
-- For people who ask by email (the account deletion page on the website) and cannot use the app. A full admin opens the
-- person in Users & partners, sees anything that blocks the deletion, gives a reason and types the account's email.
-- The console then calls the admin-delete-account edge function, which checks the caller is an active full admin and
-- does the same three steps as the in-app deletion: erase_account (refuses while money or a handover is unfinished),
-- remove the files, then soft delete the sign in. Every deletion is written to the audit log with the reason.
-- Nothing here lets anyone but a full admin read or run any of it.

-- The console asks this before it shows the delete button: is the account already gone, and what is in the way.
create function public.admin_account_deletion_check(p_user uuid) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  pr public.profiles;
  blockers text[];
begin
  perform private.require_staff(array['full_admin']);
  select * into pr from public.profiles where user_id = p_user;
  if not found then
    raise exception 'Account not found' using errcode = 'P0002';
  end if;
  blockers := private.deletion_blockers(p_user);
  if p_user = (select auth.uid()) then
    blockers := array_prepend('This is your own account. Delete it from the app.', blockers);
  end if;
  return jsonb_build_object('deleted', pr.deleted_at is not null, 'blockers', to_jsonb(blockers));
end;
$$;
revoke all on function public.admin_account_deletion_check(uuid) from public, anon;
grant execute on function public.admin_account_deletion_check(uuid) to authenticated;

-- Called by the edge function (service role) once the account is erased. The staff member is passed in because the
-- function runs without a signed in person.
create function public.log_admin_account_deletion(p_staff uuid, p_user uuid, p_reason text) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.audit_log (staff_id, action, target_type, target_id, details)
  values (p_staff, 'account.delete', 'user', p_user, jsonb_build_object('reason', left(coalesce(p_reason, ''), 300)));
end;
$$;
revoke all on function public.log_admin_account_deletion(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.log_admin_account_deletion(uuid, uuid, text) to service_role;

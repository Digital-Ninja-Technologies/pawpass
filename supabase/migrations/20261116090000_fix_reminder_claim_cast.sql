-- Fix: claim_reminder_emails cast part of every notification key to a uuid, which fails for a key that does not
-- have one there (Postgres may evaluate the cast before it filters). The cast now only happens for reminders.
-- Replaces one function; safe to run more than once.

create or replace function public.claim_reminder_emails(p_limit integer default 50, p_now timestamptz default now())
returns table (notification_id uuid, email text, first_name text, title text, body text)
language plpgsql security definer
set search_path = ''
as $$
declare
  lagos_hour integer := extract(hour from p_now at time zone 'Africa/Lagos');
begin
  -- Quiet hours: nothing is sent before 8am or from 8pm, Lagos time. It is picked up in the morning.
  if lagos_hour < 8 or lagos_hour >= 20 then
    return;
  end if;

  return query
  with picked as (
    select n.id
      from public.notifications n
      join public.reminders r
        on r.id = case when n.kind = 'reminder_due' and n.dedupe_key like 'reminder:%'
                       then split_part(n.dedupe_key, ':', 2)::uuid end
      join public.profiles pr on pr.user_id = n.user_id
      join auth.users u on u.id = n.user_id
     where n.kind = 'reminder_due'
       and n.dedupe_key like 'reminder:%'
       and n.emailed_at is null
       and n.created_at > p_now - interval '2 days'
       and n.email_attempts < 3
       and (n.email_claimed_at is null or n.email_claimed_at < p_now - interval '15 minutes')
       and 'email' = any (r.channels)
       and r.status = 'scheduled'
       and pr.deleted_at is null
       and pr.suspended_at is null
       and u.email is not null
     order by n.created_at
     limit greatest(coalesce(p_limit, 50), 1)
     for update of n skip locked
  )
  update public.notifications n
     set email_claimed_at = p_now, email_attempts = n.email_attempts + 1
    from picked
    join public.profiles pr2 on true
    join auth.users u2 on true
   where n.id = picked.id and pr2.user_id = n.user_id and u2.id = n.user_id
  returning n.id, u2.email::text, pr2.first_name, n.title, n.body;
end;
$$;
revoke all on function public.claim_reminder_emails(integer, timestamptz) from public, anon, authenticated;
grant execute on function public.claim_reminder_emails(integer, timestamptz) to service_role;

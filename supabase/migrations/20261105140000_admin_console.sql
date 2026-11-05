-- Admin console support.
--
-- Reads: views with security_invoker, so staff see only what RLS lets their role read.
-- Writes: SECURITY DEFINER functions that check the staff role and write audit_log.
-- The web app never needs the service role key.
--
-- Staff roles: full_admin (always allowed), payouts_disputes, support_reports,
-- verifications, read_only (no write functions).

-- ---------------------------------------------------------------------------
-- Columns the console needs
-- ---------------------------------------------------------------------------
alter table public.partner_accounts
  add column submitted_at timestamptz,
  add column decided_at timestamptz,
  add column decision_note text;         -- shown to the partner when more info is requested

update public.partner_accounts set submitted_at = created_at where status <> 'draft' and submitted_at is null;

-- Reviewer notes and checklist. A separate table because partner owners can read their
-- own partner_accounts row, and these must stay staff only.
create table public.partner_reviews (
  partner_account_id uuid primary key references public.partner_accounts (id) on delete cascade,
  kyc_checks jsonb not null default '{}',
  internal_note text,
  updated_by uuid references public.staff_members (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger touch_updated_at before update on public.partner_reviews
  for each row execute function private.touch_updated_at();
alter table public.partner_reviews enable row level security;
create policy "verification staff read review notes" on public.partner_reviews
  for select to authenticated
  using (private.is_staff(array['verifications', 'read_only']));
revoke all on public.partner_reviews from anon, authenticated;
grant select on public.partner_reviews to authenticated;

alter table public.disputes
  add column decision_refund_kobo bigint check (decision_refund_kobo >= 0),
  add column decision_note text,
  add column decided_at timestamptz;

alter table public.profiles
  add column suspended_at timestamptz,
  add column suspension_reason text;

-- Users may edit their own details but never their suspension state.
revoke update on public.profiles from authenticated;
grant update (first_name, last_name, area, phone, avatar_path) on public.profiles to authenticated;

-- Submitting an application starts the 48 hour clock.
create or replace function public.submit_partner_application(p_partner uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.partner_accounts
     set status = 'submitted', submitted_at = now()
   where id = p_partner
     and owner_user_id = (select auth.uid())
     and status in ('draft', 'needs_info');
  if not found then
    raise exception 'Application not found or cannot be submitted' using errcode = '42501';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create function private.current_staff_id() returns uuid
language sql stable security definer
set search_path = ''
as $$
  select s.id from public.staff_members s
  where s.user_id = (select auth.uid()) and s.status = 'active';
$$;

-- Raises unless the caller is active staff holding one of `roles` (full_admin always passes).
create function private.require_staff(roles text[]) returns uuid
language plpgsql stable security definer
set search_path = ''
as $$
declare sid uuid;
begin
  if not private.is_staff(roles) then
    raise exception 'You do not have permission to do this' using errcode = '42501';
  end if;
  select private.current_staff_id() into sid;
  return sid;
end;
$$;

create function private.write_audit(p_action text, p_target_type text, p_target_id uuid, p_details jsonb default '{}')
returns void
language sql security definer
set search_path = ''
as $$
  insert into public.audit_log (staff_id, action, target_type, target_id, details)
  values (private.current_staff_id(), p_action, p_target_type, p_target_id, coalesce(p_details, '{}'));
$$;

-- Suspending bans the sign in (auth.users.banned_until), flags the profile, suspends
-- their partner accounts and takes their live listings down.
create function private.suspend_user(p_user uuid, p_reason text) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.staff_members where user_id = p_user) then
    raise exception 'Staff accounts cannot be suspended here' using errcode = '42501';
  end if;
  update auth.users set banned_until = 'infinity' where id = p_user;
  update public.profiles set suspended_at = now(), suspension_reason = p_reason where user_id = p_user;
  update public.partner_accounts set status = 'suspended'
   where owner_user_id = p_user and status in ('approved', 'submitted', 'needs_info');
  update public.listings set status = 'removed'
   where status in ('live', 'draft')
     and partner_account_id in (select id from public.partner_accounts where owner_user_id = p_user);
end;
$$;

create function private.unsuspend_user(p_user uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update auth.users set banned_until = null where id = p_user;
  update public.profiles set suspended_at = null, suspension_reason = null where user_id = p_user;
  update public.partner_accounts
     set status = case when verified_at is not null then 'approved' else 'submitted' end
   where owner_user_id = p_user and status = 'suspended';
end;
$$;

-- ---------------------------------------------------------------------------
-- Read views (security invoker: RLS of the signed in staff member applies)
-- ---------------------------------------------------------------------------
create view public.admin_directory_v with (security_invoker = true) as
select
  'owner'::text as kind,
  p.user_id as id,
  trim(p.first_name || ' ' || p.last_name) as name,
  'owner'::text as type,
  p.area,
  p.created_at as joined_at,
  case when p.suspended_at is not null then 'suspended' else 'active' end as status,
  (select count(*) from public.pets x where x.owner_user_id = p.user_id) as pets,
  (select count(*) from public.bookings b where b.owner_user_id = p.user_id) as bookings,
  (select coalesce(sum(e.amount_kobo), 0) from public.escrow_transactions e
    where e.payer_user_id = p.user_id and e.status in ('held', 'paused')) as in_escrow_kobo,
  p.suspension_reason,
  p.user_id as user_id
from public.profiles p
where private.is_staff()
  and not exists (select 1 from public.staff_members s where s.user_id = p.user_id)
union all
select
  'partner'::text,
  a.id,
  a.business_name,
  a.type,
  a.area,
  a.created_at,
  a.status,
  0, 0, 0,
  null,
  a.owner_user_id
from public.partner_accounts a
where private.is_staff();

create view public.admin_kyc_v with (security_invoker = true) as
select
  a.id,
  a.business_name,
  a.type,
  a.area,
  a.status,
  a.submitted_at,
  a.decided_at,
  a.decision_note,
  r.internal_note,
  coalesce(r.kyc_checks, '{}'::jsonb) as kyc_checks,
  a.owner_user_id,
  trim(p.first_name || ' ' || p.last_name) as owner_name
from public.partner_accounts a
left join public.profiles p on p.user_id = a.owner_user_id
left join public.partner_reviews r on r.partner_account_id = a.id
where a.status <> 'draft' and private.is_staff();

create view public.admin_escrow_v with (security_invoker = true) as
select
  e.id,
  'T-' || upper(left(replace(e.id::text, '-', ''), 6)) as ref,
  e.kind,
  e.amount_kobo,
  e.fee_kobo,
  e.status,
  e.release_after,
  e.created_at,
  trim(pp.first_name || ' ' || pp.last_name) as payer_name,
  a.business_name as payee_name,
  coalesce(
    (select s.name || ' · ' || pt.name
       from public.bookings b
       join public.services s on s.id = b.service_id
       join public.pets pt on pt.id = b.pet_id
      where b.escrow_transaction_id = e.id limit 1),
    (select initcap(replace(e.kind, '_', ' ')) || ' · ' || pt.name
       from public.ownership_transfers t
       join public.pets pt on pt.id = t.pet_id
      where t.escrow_transaction_id = e.id limit 1),
    initcap(replace(e.kind, '_', ' '))
  ) as subject,
  (select d.id from public.disputes d
    where d.escrow_transaction_id = e.id and d.status <> 'decided' limit 1) as open_dispute_id
from public.escrow_transactions e
left join public.profiles pp on pp.user_id = e.payer_user_id
left join public.partner_accounts a on a.id = e.payee_partner_id;

create view public.admin_dispute_v with (security_invoker = true) as
select
  d.id,
  'D-' || upper(left(replace(d.id::text, '-', ''), 4)) as ref,
  d.status,
  d.decision,
  d.decision_refund_kobo,
  d.decision_note,
  d.decided_at,
  d.reason,
  d.details,
  d.partner_response,
  d.evidence_paths,
  d.due_at,
  d.created_at,
  e.id as escrow_id,
  e.kind as escrow_kind,
  e.amount_kobo,
  e.status as escrow_status,
  trim(pp.first_name || ' ' || pp.last_name) as buyer_name,
  a.business_name as partner_name,
  a.status = 'approved' as partner_verified,
  coalesce(
    (select s.name || ' · ' || pt.name
       from public.bookings b
       join public.services s on s.id = b.service_id
       join public.pets pt on pt.id = b.pet_id
      where b.escrow_transaction_id = e.id limit 1),
    (select pt.name
       from public.ownership_transfers t
       join public.pets pt on pt.id = t.pet_id
      where t.escrow_transaction_id = e.id limit 1),
    initcap(replace(e.kind, '_', ' '))
  ) as subject
from public.disputes d
join public.escrow_transactions e on e.id = d.escrow_transaction_id
left join public.profiles pp on pp.user_id = d.opened_by_user_id
left join public.partner_accounts a on a.id = e.payee_partner_id;

-- One row per reported item, with a short description of the content.
create view public.admin_report_v with (security_invoker = true) as
with grouped as (
  select
    r.target_type,
    r.target_id,
    count(*) as report_count,
    min(r.created_at) as first_reported_at,
    (array_agg(r.reason order by r.created_at))[1] as top_reason,
    bool_or(r.status = 'open') as is_open,
    max(r.status) as last_status,
    max(r.action) as action
  from public.reports r
  group by r.target_type, r.target_id
)
select
  g.*,
  case g.target_type
    when 'post' then (select left(po.body, 160) from public.posts po where po.id = g.target_id)
    when 'listing' then (select pt.name || ' · ' || l.kind || coalesce(' · ₦' || (l.price_kobo / 100)::text, '')
                           from public.listings l join public.pets pt on pt.id = l.pet_id where l.id = g.target_id)
    when 'review' then (select rv.rating || ' star review' || coalesce(': ' || left(rv.body, 120), '')
                          from public.reviews rv where rv.id = g.target_id)
    when 'lost_alert' then (select 'Lost alert · ' || pt.name
                              from public.lost_alerts la join public.pets pt on pt.id = la.pet_id where la.id = g.target_id)
    else (select trim(pr.first_name || ' ' || pr.last_name) from public.profiles pr
            where pr.user_id = g.target_id or pr.id = g.target_id limit 1)
  end as summary,
  -- Listing signals for scam review.
  (select a.business_name from public.listings l join public.partner_accounts a on a.id = l.partner_account_id
    where g.target_type = 'listing' and l.id = g.target_id) as seller_name,
  (select a.status from public.listings l join public.partner_accounts a on a.id = l.partner_account_id
    where g.target_type = 'listing' and l.id = g.target_id) as seller_status,
  (select extract(day from now() - a.created_at)::int from public.listings l join public.partner_accounts a on a.id = l.partner_account_id
    where g.target_type = 'listing' and l.id = g.target_id) as seller_age_days,
  (select l.price_kobo from public.listings l where g.target_type = 'listing' and l.id = g.target_id) as price_kobo,
  (select avg(l2.price_kobo)::bigint
     from public.listings l
     join public.pets p1 on p1.id = l.pet_id
     join public.pets p2 on p2.breed is not distinct from p1.breed
     join public.listings l2 on l2.pet_id = p2.id and l2.id <> l.id and l2.price_kobo is not null
    where g.target_type = 'listing' and l.id = g.target_id) as avg_price_kobo
from grouped g;

create view public.admin_lost_v with (security_invoker = true) as
select
  la.id,
  pt.name as pet_name,
  pt.breed,
  pt.species,
  la.status,
  la.radius_m,
  la.created_at,
  la.closes_at,
  la.description,
  pr.area as owner_area,
  extract(epoch from (la.closes_at - now())) / 86400.0 as days_left,
  (select count(*) from public.sightings s where s.lost_alert_id = la.id) as sightings,
  (select left(string_agg(distinct r.reason, ', '), 80)
     from public.reports r
    where r.target_type = 'lost_alert' and r.target_id = la.id and r.status = 'open') as flag
from public.lost_alerts la
join public.pets pt on pt.id = la.pet_id
left join public.profiles pr on pr.user_id = pt.owner_user_id;

create view public.admin_qr_v with (security_invoker = true) as
select
  o.id,
  'Q-' || upper(left(replace(o.id::text, '-', ''), 4)) as ref,
  o.status,
  o.created_at,
  o.shipped_at,
  trim(pr.first_name || ' ' || pr.last_name) as owner_name,
  pr.area,
  pt.name as pet_name
from public.qr_tag_orders o
left join public.profiles pr on pr.user_id = o.user_id
join public.pets pt on pt.id = o.pet_id;

create view public.admin_support_v with (security_invoker = true) as
select
  t.id,
  'S-' || upper(left(replace(t.id::text, '-', ''), 4)) as ref,
  t.topic,
  t.subject,
  t.status,
  t.linked_type,
  t.linked_id,
  t.created_at,
  t.updated_at,
  trim(pr.first_name || ' ' || pr.last_name) as user_name,
  (select m.body from public.support_messages m
    where m.ticket_id = t.id and m.author_user_id is not null
    order by m.created_at limit 1) as first_message,
  (select (m.author_staff_id is not null) from public.support_messages m
    where m.ticket_id = t.id and not m.internal order by m.created_at desc limit 1) as last_reply_is_staff
from public.support_tickets t
left join public.profiles pr on pr.user_id = t.user_id;

create view public.admin_staff_v with (security_invoker = true) as
select
  s.id,
  s.user_id,
  s.role,
  s.status,
  s.created_at,
  trim(p.first_name || ' ' || p.last_name) as name
from public.staff_members s
left join public.profiles p on p.user_id = s.user_id;

create view public.admin_audit_v with (security_invoker = true) as
select
  l.id,
  l.at,
  l.action,
  l.target_type,
  l.target_id,
  l.details,
  trim(p.first_name || ' ' || p.last_name) as staff_name
from public.audit_log l
left join public.staff_members s on s.id = l.staff_id
left join public.profiles p on p.user_id = s.user_id;

-- The signed in staff member's own role (any active staff can read their own row).
create view public.admin_me_v with (security_invoker = true) as
select s.id, s.user_id, s.role, s.status, trim(p.first_name || ' ' || p.last_name) as name
from public.staff_members s
left join public.profiles p on p.user_id = s.user_id
where s.user_id = (select auth.uid());

-- ---------------------------------------------------------------------------
-- Write functions
-- ---------------------------------------------------------------------------

-- Verifications ---------------------------------------------------------------
create function public.admin_review_partner(p_partner uuid, p_decision text, p_note text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare v_status text;
begin
  perform private.require_staff(array['verifications']);
  v_status := case p_decision
    when 'approve' then 'approved'
    when 'needs_info' then 'needs_info'
    when 'reject' then 'rejected'
  end;
  if v_status is null then
    raise exception 'Unknown decision' using errcode = '22023';
  end if;
  if p_decision <> 'approve' and coalesce(btrim(p_note), '') = '' then
    raise exception 'Add a note so the partner knows what to do next' using errcode = '22023';
  end if;

  update public.partner_accounts
     set status = v_status,
         decided_at = now(),
         decision_note = nullif(btrim(p_note), ''),
         verified_at = case when v_status = 'approved' then now() else verified_at end
   where id = p_partner and status in ('submitted', 'needs_info');
  if not found then
    raise exception 'This application is not waiting for review' using errcode = 'P0002';
  end if;

  if v_status in ('approved', 'rejected') then
    update public.partner_documents
       set status = case when v_status = 'approved' then 'approved' else 'rejected' end
     where partner_account_id = p_partner and status = 'submitted';
  end if;

  perform private.write_audit('partner.' || p_decision, 'partner_account', p_partner,
    jsonb_build_object('note', nullif(btrim(p_note), '')));
end;
$$;

create function public.admin_save_kyc_review(p_partner uuid, p_checks jsonb, p_internal_note text)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare v_staff uuid;
begin
  v_staff := private.require_staff(array['verifications']);
  if not exists (select 1 from public.partner_accounts where id = p_partner and status in ('submitted', 'needs_info')) then
    raise exception 'This application is not waiting for review' using errcode = 'P0002';
  end if;
  insert into public.partner_reviews (partner_account_id, kyc_checks, internal_note, updated_by)
  values (p_partner, coalesce(p_checks, '{}'), nullif(btrim(p_internal_note), ''), v_staff)
  on conflict (partner_account_id) do update
    set kyc_checks = excluded.kyc_checks, internal_note = excluded.internal_note, updated_by = excluded.updated_by;
  perform private.write_audit('partner.review_notes', 'partner_account', p_partner, jsonb_build_object('checks', p_checks));
end;
$$;

-- Disputes --------------------------------------------------------------------
create function public.admin_decide_dispute(p_dispute uuid, p_decision text, p_refund_kobo bigint default null, p_note text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  d public.disputes;
  e public.escrow_transactions;
  v_refund bigint;
begin
  perform private.require_staff(array['payouts_disputes']);
  if p_decision not in ('refund', 'split', 'release') then
    raise exception 'Unknown decision' using errcode = '22023';
  end if;

  select * into d from public.disputes where id = p_dispute for update;
  if not found then
    raise exception 'Dispute not found' using errcode = 'P0002';
  end if;
  if d.status = 'decided' then
    raise exception 'This dispute has already been decided' using errcode = 'P0001';
  end if;
  select * into e from public.escrow_transactions where id = d.escrow_transaction_id for update;

  v_refund := case p_decision
    when 'refund' then e.amount_kobo
    when 'release' then 0
    else p_refund_kobo
  end;
  if p_decision = 'split' and (v_refund is null or v_refund <= 0 or v_refund >= e.amount_kobo) then
    raise exception 'For a split, enter a refund above zero and below the full amount' using errcode = '22023';
  end if;

  update public.disputes
     set status = 'decided',
         decision = p_decision,
         decision_refund_kobo = v_refund,
         decision_note = nullif(btrim(p_note), ''),
         decided_by_staff_id = private.current_staff_id(),
         decided_at = now()
   where id = p_dispute;

  -- Refunds are paid back by the payments function; release goes out in the next payout run.
  update public.escrow_transactions
     set status = case p_decision when 'refund' then 'refunded' when 'split' then 'partially_refunded' else 'ready' end
   where id = e.id;

  perform private.write_audit('dispute.' || p_decision, 'dispute', p_dispute,
    jsonb_build_object('escrow_id', e.id, 'amount_kobo', e.amount_kobo, 'refund_kobo', v_refund,
                       'note', nullif(btrim(p_note), '')));
end;
$$;

-- Reports and users -------------------------------------------------------------
create function public.admin_resolve_report(p_target_type text, p_target_id uuid, p_action text, p_note text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_found boolean;
begin
  perform private.require_staff(array['support_reports']);
  if p_action not in ('remove_and_suspend', 'remove', 'keep') then
    raise exception 'Unknown action' using errcode = '22023';
  end if;
  if not exists (select 1 from public.reports where target_type = p_target_type and target_id = p_target_id and status = 'open') then
    raise exception 'There are no open reports for this item' using errcode = 'P0002';
  end if;

  if p_action <> 'keep' then
    case p_target_type
      when 'post' then
        update public.posts set status = 'removed' where id = p_target_id returning author_user_id into v_user;
      when 'listing' then
        update public.listings set status = 'removed' where id = p_target_id;
        select a.owner_user_id into v_user from public.listings l
          join public.partner_accounts a on a.id = l.partner_account_id where l.id = p_target_id;
      when 'review' then
        update public.reviews set status = 'hidden' where id = p_target_id;
        select b.owner_user_id into v_user from public.reviews r
          join public.bookings b on b.id = r.booking_id where r.id = p_target_id;
      when 'lost_alert' then
        update public.lost_alerts set status = 'closed' where id = p_target_id;
        select pt.owner_user_id into v_user from public.lost_alerts la
          join public.pets pt on pt.id = la.pet_id where la.id = p_target_id;
      else
        select coalesce((select user_id from public.profiles where id = p_target_id), p_target_id) into v_user;
    end case;

    if p_action = 'remove_and_suspend' then
      if v_user is null then
        raise exception 'Could not find the account to suspend' using errcode = 'P0002';
      end if;
      perform private.suspend_user(v_user, coalesce(nullif(btrim(p_note), ''), 'Suspended after a report'));
    end if;
  end if;

  update public.reports
     set status = case when p_action = 'keep' then 'dismissed' else 'actioned' end,
         action = p_action,
         decided_by_staff_id = private.current_staff_id()
   where target_type = p_target_type and target_id = p_target_id and status = 'open';

  perform private.write_audit('report.' || p_action, p_target_type, p_target_id,
    jsonb_build_object('note', nullif(btrim(p_note), ''), 'suspended_user', case when p_action = 'remove_and_suspend' then v_user end));
end;
$$;

create function public.admin_set_user_suspended(p_user uuid, p_suspended boolean, p_reason text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  perform private.require_staff(array['support_reports']);
  if p_suspended and coalesce(btrim(p_reason), '') = '' then
    raise exception 'Add a reason for the suspension' using errcode = '22023';
  end if;
  if p_suspended then
    perform private.suspend_user(p_user, btrim(p_reason));
  else
    perform private.unsuspend_user(p_user);
  end if;
  perform private.write_audit(case when p_suspended then 'user.suspend' else 'user.unsuspend' end, 'user', p_user,
    jsonb_build_object('reason', nullif(btrim(p_reason), '')));
end;
$$;

-- Reading a user's email address is personal data access, so it is logged.
create function public.admin_user_email(p_user uuid) returns text
language plpgsql security definer
set search_path = ''
as $$
declare v_email text;
begin
  perform private.require_staff(array['support_reports', 'verifications']);
  select email into v_email from auth.users where id = p_user;
  perform private.write_audit('user.view_email', 'user', p_user, '{}');
  return v_email;
end;
$$;

-- Payouts -----------------------------------------------------------------------
create function public.admin_prepare_payout_run(p_run_on date) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_run uuid;
  v_status text;
  v_total bigint;
begin
  perform private.require_staff(array['payouts_disputes']);

  select id, status into v_run, v_status from public.payout_runs where run_on = p_run_on;
  if v_run is not null and v_status <> 'draft' then
    raise exception 'The payout run for this date has already been %', v_status using errcode = 'P0001';
  end if;
  if v_run is null then
    insert into public.payout_runs (run_on) values (p_run_on) returning id into v_run;
  else
    delete from public.payout_items where payout_run_id = v_run;
  end if;

  -- Money that is ready (owner confirmed or check window over), net of fees, per partner.
  -- Paused (disputed) money is excluded because its status is 'paused'.
  insert into public.payout_items (payout_run_id, partner_account_id, amount_kobo)
  select v_run, e.payee_partner_id, sum(e.amount_kobo - e.fee_kobo)
    from public.escrow_transactions e
   where e.status = 'ready'
   group by e.payee_partner_id
  having sum(e.amount_kobo - e.fee_kobo) > 0;

  select coalesce(sum(amount_kobo), 0) into v_total from public.payout_items where payout_run_id = v_run;
  update public.payout_runs set total_kobo = v_total where id = v_run;

  perform private.write_audit('payout_run.prepare', 'payout_run', v_run, jsonb_build_object('run_on', p_run_on, 'total_kobo', v_total));
  return v_run;
end;
$$;

create function public.admin_approve_payout_run(p_run uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  perform private.require_staff(array['payouts_disputes']);
  update public.payout_runs set status = 'approved' where id = p_run and status = 'draft';
  if not found then
    raise exception 'Only a draft payout run can be approved' using errcode = 'P0001';
  end if;
  perform private.write_audit('payout_run.approve', 'payout_run', p_run, '{}');
end;
$$;

-- Settings ----------------------------------------------------------------------
create function public.admin_update_settings(p_values jsonb) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
begin
  perform private.require_staff(array['full_admin']);
  select to_jsonb(s) into v_old from public.settings s;

  update public.settings set
    booking_commission_bps = coalesce((p_values ->> 'booking_commission_bps')::int, booking_commission_bps),
    puppy_escrow_fee_bps   = coalesce((p_values ->> 'puppy_escrow_fee_bps')::int, puppy_escrow_fee_bps),
    deposit_fraction       = coalesce((p_values ->> 'deposit_fraction')::numeric, deposit_fraction),
    vet_check_hours        = coalesce((p_values ->> 'vet_check_hours')::int, vet_check_hours),
    free_cancel_hours      = coalesce((p_values ->> 'free_cancel_hours')::int, free_cancel_hours),
    kyc_target_hours       = coalesce((p_values ->> 'kyc_target_hours')::int, kyc_target_hours),
    lost_radius_m          = coalesce((p_values ->> 'lost_radius_m')::int, lost_radius_m),
    lost_autoclose_days    = coalesce((p_values ->> 'lost_autoclose_days')::int, lost_autoclose_days),
    payout_weekday         = coalesce((p_values ->> 'payout_weekday')::smallint, payout_weekday);

  select to_jsonb(s) into v_new from public.settings s;
  perform private.write_audit('settings.update', 'settings', null, jsonb_build_object('before', v_old - 'id', 'after', v_new - 'id'));
end;
$$;

-- Team ----------------------------------------------------------------------------
create function public.admin_create_staff_invite(p_email text, p_role text, p_note text, p_token_hash text, p_expires_at timestamptz)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_email text := lower(btrim(p_email));
begin
  perform private.require_staff(array['full_admin']);
  if p_role not in ('full_admin', 'payouts_disputes', 'support_reports', 'verifications', 'read_only') then
    raise exception 'Unknown role' using errcode = '22023';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Enter a valid work email' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.staff_invites i
    where lower(i.email) = v_email and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
  ) then
    raise exception 'There is already a live invite for this email' using errcode = 'P0001';
  end if;

  insert into public.staff_invites (email, role, invited_by, note, token_hash, expires_at)
  values (v_email, p_role, private.current_staff_id(), nullif(btrim(p_note), ''), p_token_hash, p_expires_at)
  returning id into v_id;

  perform private.write_audit('staff.invite', 'staff_invite', v_id, jsonb_build_object('email', v_email, 'role', p_role));
  return v_id;
end;
$$;

create function public.admin_revoke_staff_invite(p_invite uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  perform private.require_staff(array['full_admin']);
  update public.staff_invites set revoked_at = now() where id = p_invite and accepted_at is null and revoked_at is null;
  if not found then
    raise exception 'This invite can no longer be revoked' using errcode = 'P0001';
  end if;
  perform private.write_audit('staff.invite_revoke', 'staff_invite', p_invite, '{}');
end;
$$;

create function public.admin_set_staff_role(p_staff uuid, p_role text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare s public.staff_members;
begin
  perform private.require_staff(array['full_admin']);
  if p_role not in ('full_admin', 'payouts_disputes', 'support_reports', 'verifications', 'read_only') then
    raise exception 'Unknown role' using errcode = '22023';
  end if;
  select * into s from public.staff_members where id = p_staff for update;
  if not found then
    raise exception 'Team member not found' using errcode = 'P0002';
  end if;
  if s.user_id = (select auth.uid()) then
    raise exception 'You cannot change your own role' using errcode = 'P0001';
  end if;
  if s.role = 'full_admin' and p_role <> 'full_admin'
     and (select count(*) from public.staff_members where role = 'full_admin' and status = 'active') <= 1 then
    raise exception 'There must be at least one active full admin' using errcode = 'P0001';
  end if;
  update public.staff_members set role = p_role where id = p_staff;
  perform private.write_audit('staff.role', 'staff_member', p_staff, jsonb_build_object('from', s.role, 'to', p_role));
end;
$$;

create function public.admin_set_staff_status(p_staff uuid, p_status text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare s public.staff_members;
begin
  perform private.require_staff(array['full_admin']);
  if p_status not in ('active', 'suspended') then
    raise exception 'Unknown status' using errcode = '22023';
  end if;
  select * into s from public.staff_members where id = p_staff for update;
  if not found then
    raise exception 'Team member not found' using errcode = 'P0002';
  end if;
  if s.user_id = (select auth.uid()) then
    raise exception 'You cannot change your own access' using errcode = 'P0001';
  end if;
  if s.role = 'full_admin' and p_status = 'suspended'
     and (select count(*) from public.staff_members where role = 'full_admin' and status = 'active') <= 1 then
    raise exception 'There must be at least one active full admin' using errcode = 'P0001';
  end if;
  update public.staff_members set status = p_status where id = p_staff;
  perform private.write_audit('staff.status', 'staff_member', p_staff, jsonb_build_object('to', p_status));
end;
$$;

-- What the invitee sees before they have an account. Needs the secret token, returns no secrets.
create function public.staff_invite_preview(p_token text)
returns table (email text, role text, note text, expires_at timestamptz, inviter_name text)
language sql stable security definer
set search_path = ''
as $$
  select i.email, i.role, i.note, i.expires_at,
         (select trim(p.first_name || ' ' || p.last_name)
            from public.staff_members s join public.profiles p on p.user_id = s.user_id
           where s.id = i.invited_by)
    from public.staff_invites i
   where i.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and i.accepted_at is null and i.revoked_at is null and i.expires_at > now();
$$;

-- Called by the new staff member once they are signed in with the invited email.
create function public.accept_staff_invite(p_token text) returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  i public.staff_invites;
  v_email text := lower((select auth.jwt() ->> 'email'));
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into i from public.staff_invites
   where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and accepted_at is null and revoked_at is null and expires_at > now()
   for update;
  if not found then
    raise exception 'This invite is not valid any more' using errcode = 'P0002';
  end if;
  if lower(i.email) <> v_email then
    raise exception 'This invite was sent to a different email address' using errcode = '42501';
  end if;
  if exists (select 1 from public.staff_members where user_id = (select auth.uid())) then
    raise exception 'You already have staff access' using errcode = 'P0001';
  end if;

  insert into public.staff_members (user_id, role) values ((select auth.uid()), i.role);
  update public.staff_invites set accepted_at = now() where id = i.id;
  perform private.write_audit('staff.accept_invite', 'staff_invite', i.id, jsonb_build_object('role', i.role));
  return i.role;
end;
$$;

-- Lost and found, QR tags ------------------------------------------------------------
create function public.admin_widen_lost_alert(p_alert uuid, p_radius_m integer) returns void
language plpgsql security definer
set search_path = ''
as $$
declare v_old integer;
begin
  perform private.require_staff(array['support_reports']);
  if p_radius_m is null or p_radius_m <= 0 or p_radius_m > 50000 then
    raise exception 'Radius must be between 1 m and 50 km' using errcode = '22023';
  end if;
  select radius_m into v_old from public.lost_alerts where id = p_alert and status = 'active' for update;
  if not found then
    raise exception 'Only an active alert can be widened' using errcode = 'P0002';
  end if;
  update public.lost_alerts set radius_m = p_radius_m where id = p_alert;
  perform private.write_audit('lost_alert.widen', 'lost_alert', p_alert, jsonb_build_object('from_m', v_old, 'to_m', p_radius_m));
end;
$$;

create function public.admin_set_qr_order_status(p_order uuid, p_status text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare v_old text;
begin
  perform private.require_staff(array['support_reports']);
  if p_status not in ('shipped', 'delivered') then
    raise exception 'Unknown status' using errcode = '22023';
  end if;
  select status into v_old from public.qr_tag_orders where id = p_order for update;
  if not found then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;
  if not ((v_old = 'paid' and p_status = 'shipped') or (v_old = 'shipped' and p_status = 'delivered')) then
    raise exception 'An order cannot go from % to %', v_old, p_status using errcode = 'P0001';
  end if;
  update public.qr_tag_orders
     set status = p_status, shipped_at = case when p_status = 'shipped' then now() else shipped_at end
   where id = p_order;
  perform private.write_audit('qr_order.' || p_status, 'qr_tag_order', p_order, '{}');
end;
$$;

-- Support ------------------------------------------------------------------------------
create function public.admin_reply_ticket(p_ticket uuid, p_body text, p_internal boolean default false) returns void
language plpgsql security definer
set search_path = ''
as $$
declare v_staff uuid;
begin
  v_staff := private.require_staff(array['support_reports']);
  if coalesce(btrim(p_body), '') = '' then
    raise exception 'Write a message first' using errcode = '22023';
  end if;
  if not exists (select 1 from public.support_tickets where id = p_ticket) then
    raise exception 'Ticket not found' using errcode = 'P0002';
  end if;
  insert into public.support_messages (ticket_id, author_staff_id, body, internal)
  values (p_ticket, v_staff, btrim(p_body), p_internal);
  if not p_internal then
    update public.support_tickets set status = 'waiting_user' where id = p_ticket and status = 'open';
  end if;
  perform private.write_audit(case when p_internal then 'ticket.note' else 'ticket.reply' end, 'support_ticket', p_ticket, '{}');
end;
$$;

create function public.admin_set_ticket_status(p_ticket uuid, p_status text) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  perform private.require_staff(array['support_reports']);
  if p_status not in ('open', 'waiting_user', 'closed') then
    raise exception 'Unknown status' using errcode = '22023';
  end if;
  update public.support_tickets set status = p_status where id = p_ticket;
  if not found then
    raise exception 'Ticket not found' using errcode = 'P0002';
  end if;
  perform private.write_audit('ticket.status', 'support_ticket', p_ticket, jsonb_build_object('to', p_status));
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
revoke all on function private.current_staff_id(), private.require_staff(text[]),
  private.write_audit(text, text, uuid, jsonb), private.suspend_user(uuid, text), private.unsuspend_user(uuid)
  from public, anon;
grant execute on function private.current_staff_id(), private.require_staff(text[]),
  private.write_audit(text, text, uuid, jsonb), private.suspend_user(uuid, text), private.unsuspend_user(uuid)
  to authenticated, service_role;

-- Every public.admin_* function and accept_staff_invite: signed in users only (each checks the role itself).
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and (p.proname like 'admin\_%' or p.proname in ('accept_staff_invite', 'staff_invite_preview'))
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end;
$$;
-- The invite page needs the preview before the invitee has an account.
grant execute on function public.staff_invite_preview(text) to anon;

grant select on public.admin_directory_v, public.admin_kyc_v, public.admin_escrow_v, public.admin_dispute_v,
  public.admin_report_v, public.admin_lost_v, public.admin_qr_v, public.admin_support_v,
  public.admin_staff_v, public.admin_audit_v, public.admin_me_v to authenticated;

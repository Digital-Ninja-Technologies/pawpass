-- Partner mode (milestone 6): becoming a partner and the verification steps, the dashboards for vets,
-- groomers, breeders and shelters, earnings, listings, adoption decisions, and help and support.
-- Money and status changes still go through server functions; the app only asks.

-- ---------------------------------------------------------------------------
-- Payout account: where a partner is paid. Only the owner and staff can read it, and nobody writes it
-- directly (partner_save_payout_account does, after checking the shape).
-- ---------------------------------------------------------------------------
create table public.partner_payout_accounts (
  partner_account_id uuid primary key references public.partner_accounts (id) on delete cascade,
  bank_code text not null check (bank_code ~ '^[0-9]{3,6}$'),
  bank_name text not null check (char_length(bank_name) between 2 and 60),
  account_number text not null check (account_number ~ '^[0-9]{10}$'),
  account_name text not null check (char_length(account_name) between 2 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger touch_updated_at before update on public.partner_payout_accounts
  for each row execute function private.touch_updated_at();
alter table public.partner_payout_accounts enable row level security;
create policy "owner or finance staff read payout account" on public.partner_payout_accounts
  for select to authenticated
  using (private.owns_partner(partner_account_id) or private.is_staff(array['payouts_disputes', 'verifications']));
revoke all on public.partner_payout_accounts from anon, authenticated;
grant select on public.partner_payout_accounts to authenticated;

-- A short number people can quote when they write to support.
alter table public.support_tickets add column number bigint generated always as identity;

-- ---------------------------------------------------------------------------
-- The verification steps and where a partner stands
-- ---------------------------------------------------------------------------
-- Which steps this partner has to finish, and which are done. A vet clinic also needs a practising licence.
create function private.partner_steps(p_partner uuid) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  a public.partner_accounts;
  photos integer;
  has_payout boolean;
  steps jsonb;
begin
  select * into a from public.partner_accounts where id = p_partner;
  select count(*)::integer into photos from public.partner_documents
   where partner_account_id = p_partner and kind = 'facility_photo' and status <> 'rejected';
  has_payout := exists (select 1 from public.partner_payout_accounts where partner_account_id = p_partner);

  steps := jsonb_build_array(
    jsonb_build_object('key', 'business', 'required', true,
      'done', char_length(btrim(coalesce(a.business_name, ''))) >= 2 and btrim(coalesce(a.area, '')) <> ''),
    jsonb_build_object('key', 'owner_id', 'required', true,
      'done', exists (select 1 from public.partner_documents d
                       where d.partner_account_id = p_partner and d.kind = 'owner_id' and d.status <> 'rejected')),
    jsonb_build_object('key', 'cac', 'required', true,
      'done', exists (select 1 from public.partner_documents d
                       where d.partner_account_id = p_partner and d.kind = 'cac' and d.status <> 'rejected'))
  );
  if a.type = 'vet' then
    steps := steps || jsonb_build_array(jsonb_build_object('key', 'licence', 'required', true,
      'done', exists (select 1 from public.partner_documents d
                       where d.partner_account_id = p_partner and d.kind = 'licence' and d.status <> 'rejected')));
  end if;
  steps := steps || jsonb_build_array(jsonb_build_object('key', 'facility_payout', 'required', true,
    'done', photos >= 3 and has_payout, 'photos', photos, 'payout', has_payout));
  return steps;
end;
$$;
revoke all on function private.partner_steps(uuid) from public, anon, authenticated;

-- The caller's partner account: their approved one first (oldest), otherwise the one in progress, otherwise
-- the most recent. Null if they never started.
create function private.my_partner_id(p_partner uuid default null) returns uuid
language sql stable security definer
set search_path = ''
as $$
  select a.id from public.partner_accounts a
   where a.owner_user_id = (select auth.uid())
     and (p_partner is null or a.id = p_partner)
   order by case a.status
              when 'approved' then 0 when 'suspended' then 1
              when 'draft' then 2 when 'needs_info' then 2 when 'submitted' then 2
              else 3 end,
            case when a.status = 'approved' then a.created_at end asc,
            a.created_at desc, a.id
   limit 1;
$$;
revoke all on function private.my_partner_id(uuid) from public, anon, authenticated;

create function public.partner_application() returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  pid uuid;
  a public.partner_accounts;
  pay public.partner_payout_accounts;
  steps jsonb;
  total integer;
  done integer;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  pid := private.my_partner_id();
  if pid is null then
    return null;
  end if;
  select * into a from public.partner_accounts where id = pid;
  select * into pay from public.partner_payout_accounts where partner_account_id = pid;
  steps := private.partner_steps(pid);
  select count(*)::integer, count(*) filter (where (s ->> 'done')::boolean)::integer
    into total, done from jsonb_array_elements(steps) s;
  return jsonb_build_object(
    'partner_id', a.id,
    'type', a.type,
    'status', a.status,
    'business_name', a.business_name,
    'area', a.area,
    'verified', a.verified_at is not null,
    'submitted_at', a.submitted_at,
    'decided_at', a.decided_at,
    'decision_note', a.decision_note,
    'steps', steps,
    'steps_total', total,
    'steps_done', done,
    'can_submit', a.status in ('draft', 'needs_info') and done = total,
    'payout', case when pay.partner_account_id is null then null else jsonb_build_object(
      'bank_name', pay.bank_name, 'last4', right(pay.account_number, 4), 'account_name', pay.account_name) end
  );
end;
$$;
revoke all on function public.partner_application() from public, anon;
grant execute on function public.partner_application() to authenticated;

-- Starts the application, or updates the one in progress (the type can only change while it is a draft).
create function public.partner_start(p_type text, p_name text, p_area text) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  a public.partner_accounts;
  nm text := btrim(coalesce(p_name, ''));
  ar text := btrim(coalesce(p_area, ''));
  pid uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if p_type not in ('vet', 'service', 'breeder', 'shelter') then
    raise exception 'Choose what kind of partner you are' using errcode = '22023';
  end if;
  if char_length(nm) not between 2 and 60 then
    raise exception 'Enter your business name (2 to 60 characters)' using errcode = '22023';
  end if;
  if char_length(ar) not between 2 and 60 then
    raise exception 'Enter the area your business is in' using errcode = '22023';
  end if;

  if exists (select 1 from public.partner_accounts where owner_user_id = me and status in ('approved', 'suspended')) then
    raise exception 'You already have a partner account' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.partner_accounts where owner_user_id = me and status = 'submitted') then
    raise exception 'Your application is already being reviewed' using errcode = 'P0001';
  end if;

  select * into a from public.partner_accounts
   where owner_user_id = me and status in ('draft', 'needs_info')
   order by created_at desc limit 1 for update;
  if found then
    update public.partner_accounts
       set business_name = nm, area = ar, type = case when a.status = 'draft' then p_type else a.type end
     where id = a.id
     returning id into pid;
    return pid;
  end if;

  insert into public.partner_accounts (owner_user_id, type, business_name, area, status)
  values (me, p_type, nm, ar, 'draft')
  returning id into pid;
  return pid;
end;
$$;
revoke all on function public.partner_start(text, text, text) from public, anon;
grant execute on function public.partner_start(text, text, text) to authenticated;

-- Records an uploaded document. The file itself is already in the private partner-documents bucket,
-- inside the caller's own folder.
create function public.partner_add_document(p_partner uuid, p_kind text, p_path text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  a public.partner_accounts;
begin
  select * into a from public.partner_accounts where id = p_partner and owner_user_id = me for update;
  if not found then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  if a.status not in ('draft', 'needs_info') then
    raise exception 'This application can no longer be changed' using errcode = 'P0001';
  end if;
  if p_kind not in ('owner_id', 'cac', 'licence', 'facility_photo') then
    raise exception 'That document is not needed' using errcode = '22023';
  end if;
  if p_kind = 'licence' and a.type <> 'vet' then
    raise exception 'A practising licence is only needed for vet clinics' using errcode = '22023';
  end if;
  if p_path is null or char_length(p_path) > 300 or p_path not like (me::text || '/%') or p_path like '%..%' then
    raise exception 'That file cannot be used' using errcode = '22023';
  end if;

  if p_kind = 'facility_photo' then
    if (select count(*) from public.partner_documents
         where partner_account_id = p_partner and kind = 'facility_photo' and status <> 'rejected') >= 6 then
      raise exception 'You can add up to 6 facility photos' using errcode = 'P0001';
    end if;
  else
    -- A new upload replaces the earlier one (a rejected or blurry photo, say).
    delete from public.partner_documents
     where partner_account_id = p_partner and kind = p_kind and status <> 'approved';
  end if;
  insert into public.partner_documents (partner_account_id, kind, storage_path)
  values (p_partner, p_kind, p_path);
end;
$$;
revoke all on function public.partner_add_document(uuid, text, text) from public, anon;
grant execute on function public.partner_add_document(uuid, text, text) to authenticated;

create function public.partner_save_payout_account(
  p_partner uuid, p_bank_code text, p_bank_name text, p_account_number text, p_account_name text
) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  a public.partner_accounts;
begin
  select * into a from public.partner_accounts where id = p_partner and owner_user_id = (select auth.uid()) for update;
  if not found then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  if a.status not in ('draft', 'needs_info') then
    raise exception 'The payout account can be changed by contacting support' using errcode = 'P0001';
  end if;
  if coalesce(p_bank_code, '') !~ '^[0-9]{3,6}$' or char_length(btrim(coalesce(p_bank_name, ''))) not between 2 and 60 then
    raise exception 'Choose your bank' using errcode = '22023';
  end if;
  if coalesce(p_account_number, '') !~ '^[0-9]{10}$' then
    raise exception 'An account number has 10 digits' using errcode = '22023';
  end if;
  if char_length(btrim(coalesce(p_account_name, ''))) not between 2 and 80 then
    raise exception 'Enter the name on the account' using errcode = '22023';
  end if;
  insert into public.partner_payout_accounts (partner_account_id, bank_code, bank_name, account_number, account_name)
  values (p_partner, p_bank_code, btrim(p_bank_name), p_account_number, btrim(p_account_name))
  on conflict (partner_account_id) do update
    set bank_code = excluded.bank_code, bank_name = excluded.bank_name,
        account_number = excluded.account_number, account_name = excluded.account_name;
end;
$$;
revoke all on function public.partner_save_payout_account(uuid, text, text, text, text) from public, anon;
grant execute on function public.partner_save_payout_account(uuid, text, text, text, text) to authenticated;

-- Sends the application to the PawPass team once every step is done.
create function public.submit_partner_for_review(p_partner uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  a public.partner_accounts;
begin
  select * into a from public.partner_accounts where id = p_partner and owner_user_id = me for update;
  if not found then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  if a.status not in ('draft', 'needs_info') then
    raise exception 'This application is not waiting for you' using errcode = 'P0001';
  end if;
  if exists (select 1 from jsonb_array_elements(private.partner_steps(p_partner)) s
              where (s ->> 'required')::boolean and not (s ->> 'done')::boolean) then
    raise exception 'Finish every step before you submit' using errcode = 'P0001';
  end if;
  update public.partner_accounts set status = 'submitted', submitted_at = now() where id = p_partner;
  perform private.notify(me, 'booking', 'We got your application',
    'The PawPass team reviews it within 48 hours. You can keep using PawPass as an owner meanwhile.',
    '/partner/review', 'partner-submitted:' || p_partner || ':' || floor(extract(epoch from now()))::text);
end;
$$;
revoke all on function public.submit_partner_for_review(uuid) from public, anon;
grant execute on function public.submit_partner_for_review(uuid) to authenticated;

-- Tell the partner when the team decides.
create function private.notify_partner_decision() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  if new.status = 'approved' then
    perform private.notify(new.owner_user_id, 'booking', 'You are verified',
      new.business_name || ' is approved. Your partner dashboard is ready.', '/partner',
      'partner-status:' || new.id || ':approved');
  elsif new.status = 'needs_info' then
    perform private.notify(new.owner_user_id, 'booking', 'One more thing for your application',
      coalesce(new.decision_note, 'Open your application to see what is needed.'), '/partner/review',
      'partner-status:' || new.id || ':needs_info:' || floor(extract(epoch from now()))::text);
  elsif new.status = 'rejected' then
    perform private.notify(new.owner_user_id, 'booking', 'Your application was not approved',
      coalesce(new.decision_note, 'Open your application for the details.'), '/partner/review',
      'partner-status:' || new.id || ':rejected');
  end if;
  return new;
end;
$$;
revoke all on function private.notify_partner_decision() from public, anon, authenticated;
create trigger notify_partner_decision after update of status on public.partner_accounts
  for each row execute function private.notify_partner_decision();

-- ---------------------------------------------------------------------------
-- Dashboards
-- ---------------------------------------------------------------------------
-- Conversations about this partner's listings, newest first.
create function private.partner_enquiries(p_partner uuid, p_limit integer default 10) returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(row_to_json(t) order by t.last_at desc), '[]'::jsonb)
    from (
      select c.id as conversation_id, l.id as listing_id, p.name as pet_name,
             coalesce(nullif(btrim(op.first_name), ''), 'Someone') as other_name,
             (select m.body from public.messages m where m.conversation_id = c.id order by m.created_at desc limit 1) as last_body,
             coalesce((select max(m.created_at) from public.messages m where m.conversation_id = c.id), c.created_at) as last_at,
             (select count(*)::integer from public.messages m
               where m.conversation_id = c.id and m.sender_user_id <> (select auth.uid())
                 and (me.last_read_at is null or m.created_at > me.last_read_at)) as unread
        from public.conversations c
        join public.listings l on l.id = c.context_id and l.partner_account_id = p_partner
        join public.pets p on p.id = l.pet_id
        join public.conversation_members me on me.conversation_id = c.id and me.user_id = (select auth.uid())
        join public.conversation_members o on o.conversation_id = c.id and o.user_id <> (select auth.uid())
        join public.profiles op on op.user_id = o.user_id
       where c.context_type = 'listing'
         and not private.is_blocked_between(o.user_id, (select auth.uid()))
       order by coalesce((select max(m.created_at) from public.messages m where m.conversation_id = c.id), c.created_at) desc
       limit p_limit
    ) t;
$$;
revoke all on function private.partner_enquiries(uuid, integer) from public, anon, authenticated;

create function public.partner_dashboard(p_partner uuid default null) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  pid uuid;
  a public.partner_accounts;
  today date := (now() at time zone 'Africa/Lagos')::date;
  week_start date := date_trunc('week', now() at time zone 'Africa/Lagos')::date;
  stats jsonb := '{}'::jsonb;
  schedule jsonb := '[]'::jsonb;
  listings jsonb := '[]'::jsonb;
  enquiries jsonb := '[]'::jsonb;
  apps jsonb := '[]'::jsonb;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  pid := private.my_partner_id(p_partner);
  select * into a from public.partner_accounts where id = pid;
  if pid is null or a.status <> 'approved' then
    raise exception 'Your partner account is not approved yet' using errcode = '42501';
  end if;

  if a.type in ('vet', 'service') then
    select coalesce(jsonb_agg(jsonb_build_object(
             'booking_id', b.id, 'starts_at', b.starts_at, 'service', s.name, 'pet_name', p.name, 'pet_id', p.id,
             'breed', p.breed, 'owner_name', coalesce(nullif(btrim(op.first_name), ''), 'Owner'),
             'status', b.status, 'passport_shared', b.passport_share_id is not null) order by b.starts_at), '[]'::jsonb)
      into schedule
      from public.bookings b
      join public.services s on s.id = b.service_id
      join public.pets p on p.id = b.pet_id
      join public.profiles op on op.user_id = b.owner_user_id
     where b.partner_account_id = pid
       and b.status in ('confirmed', 'completed_awaiting_owner', 'completed')
       and (b.starts_at at time zone 'Africa/Lagos')::date = today;
    stats := jsonb_build_object(
      'visits_today', jsonb_array_length(schedule),
      'week_kobo', coalesce((
        select sum(e.amount_kobo - e.fee_kobo) from public.bookings b
          join public.escrow_transactions e on e.id = b.escrow_transaction_id
         where b.partner_account_id = pid and e.status in ('held', 'ready', 'paused', 'released')
           and (b.starts_at at time zone 'Africa/Lagos')::date >= week_start), 0),
      'rating', (select round(avg(r.rating)::numeric, 1) from public.reviews r
                   join public.bookings b on b.id = r.booking_id
                  where b.partner_account_id = pid and r.status = 'published'),
      'review_count', (select count(*) from public.reviews r
                         join public.bookings b on b.id = r.booking_id
                        where b.partner_account_id = pid and r.status = 'published'),
      'next_payout_kobo', coalesce((
        select sum(amount_kobo - fee_kobo) from public.escrow_transactions
         where payee_partner_id = pid and status = 'ready'), 0));
  else
    select coalesce(jsonb_agg(t order by t.sort, t.created_at desc), '[]'::jsonb) into listings
      from (
        select l.id as listing_id, p.id as pet_id, p.name as pet_name, p.photo_path, l.kind, l.status, l.price_kobo,
               l.handover_by, l.created_at,
               case l.status when 'reserved' then 0 when 'live' then 1 else 2 end as sort,
               (select count(*)::integer from public.conversations c where c.context_type = 'listing' and c.context_id = l.id) as enquiries,
               (select count(*)::integer from public.adoption_applications x where x.listing_id = l.id and x.status in ('submitted', 'home_visit')) as applications,
               o.id as order_id, o.status as order_status,
               coalesce(nullif(btrim(bp.first_name), ''), 'A buyer') as buyer_name
          from public.listings l
          join public.pets p on p.id = l.pet_id
          left join lateral (
            select x.* from public.puppy_orders x
             where x.listing_id = l.id and x.status not in ('pending_deposit', 'cancelled')
             order by x.created_at desc limit 1) o on true
          left join public.profiles bp on bp.user_id = o.buyer_user_id
         where l.partner_account_id = pid and l.status <> 'removed'
         order by case l.status when 'reserved' then 0 when 'live' then 1 else 2 end, l.created_at desc
         limit 50
      ) t;
    enquiries := private.partner_enquiries(pid, 10);
    if a.type = 'breeder' then
      stats := jsonb_build_object(
        'live_listings', (select count(*) from public.listings where partner_account_id = pid and status = 'live'),
        'new_enquiries', (select count(*) from jsonb_array_elements(enquiries) e where (e ->> 'unread')::integer > 0),
        'in_escrow_kobo', coalesce((
          select sum(amount_kobo - fee_kobo) from public.escrow_transactions
           where payee_partner_id = pid and kind in ('puppy_deposit', 'puppy_balance') and status in ('held', 'paused', 'ready')), 0),
        'next_payout_kobo', coalesce((
          select sum(amount_kobo - fee_kobo) from public.escrow_transactions
           where payee_partner_id = pid and status = 'ready'), 0));
    else
      select coalesce(jsonb_agg(row_to_json(t) order by t.created_at desc), '[]'::jsonb) into apps
        from (
          select x.id as application_id, l.id as listing_id, p.name as pet_name, p.photo_path, x.status, x.created_at,
                 coalesce(nullif(btrim(ap.first_name), ''), 'Someone') as applicant_name,
                 x.answers ->> 'home_type' as home_type, x.answers ->> 'other_pets' as other_pets,
                 x.answers ->> 'daytime' as daytime, x.answers ->> 'why' as why,
                 (select count(*)::integer from public.pets xp where xp.owner_user_id = x.applicant_user_id) as pets_total,
                 (select count(*)::integer from public.pets xp where xp.owner_user_id = x.applicant_user_id
                    and exists (select 1 from public.health_records h where h.pet_id = xp.id and h.type = 'vaccine')) as pets_vaccinated,
                 (select t.id from public.ownership_transfers t where t.application_id = x.id and t.completed_at is null limit 1) as transfer_id
            from public.adoption_applications x
            join public.listings l on l.id = x.listing_id and l.partner_account_id = pid
            join public.pets p on p.id = l.pet_id
            join public.profiles ap on ap.user_id = x.applicant_user_id
           where x.status in ('submitted', 'home_visit', 'approved') and l.status in ('live', 'reserved')
           order by x.created_at desc
           limit 30
        ) t;
      stats := jsonb_build_object(
        'pets_listed', (select count(*) from public.listings where partner_account_id = pid and kind = 'adoption' and status in ('live', 'reserved')),
        'new_applications', (select count(*) from public.adoption_applications x
                               join public.listings l on l.id = x.listing_id
                              where l.partner_account_id = pid and x.status = 'submitted'),
        'adopted_month', (select count(*) from public.listings
                           where partner_account_id = pid and status = 'adopted'
                             and (updated_at at time zone 'Africa/Lagos')::date >= date_trunc('month', now() at time zone 'Africa/Lagos')::date),
        'stale_pets', (select count(*) from public.listings l
                        where l.partner_account_id = pid and l.kind = 'adoption' and l.status = 'live'
                          and l.created_at < now() - interval '30 days'
                          and not exists (select 1 from public.adoption_applications x
                                           where x.listing_id = l.id and x.created_at > now() - interval '30 days')));
    end if;
  end if;

  return jsonb_build_object(
    'partner', jsonb_build_object('id', a.id, 'type', a.type, 'name', a.business_name, 'area', a.area),
    'stats', stats,
    'schedule', schedule,
    'listings', listings,
    'enquiries', enquiries,
    'applications', apps
  );
end;
$$;
revoke all on function public.partner_dashboard(uuid) from public, anon;
grant execute on function public.partner_dashboard(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Earnings: what is held, what is ready for Monday's payout, what was paid
-- ---------------------------------------------------------------------------
create function public.partner_earnings(p_partner uuid default null) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  pid uuid;
  a public.partner_accounts;
  pay public.partner_payout_accounts;
  d date := (now() at time zone 'Africa/Lagos')::date;
  recent jsonb;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  pid := private.my_partner_id(p_partner);
  select * into a from public.partner_accounts where id = pid;
  if pid is null or a.status <> 'approved' then
    raise exception 'Your partner account is not approved yet' using errcode = '42501';
  end if;
  select * into pay from public.partner_payout_accounts where partner_account_id = pid;

  select coalesce(jsonb_agg(row_to_json(t) order by t.at desc), '[]'::jsonb) into recent
    from (
      (select 'escrow'::text as source, e.id as ref,
              case e.kind
                when 'booking' then coalesce((select s.name || ' · ' || p.name from public.bookings b
                                                join public.services s on s.id = b.service_id
                                                join public.pets p on p.id = b.pet_id
                                               where b.escrow_transaction_id = e.id), 'Booking')
                when 'puppy_deposit' then 'Deposit · ' || coalesce((select p.name from public.puppy_orders o join public.pets p on p.id = o.pet_id where o.deposit_escrow_id = e.id), 'a pet')
                else 'Balance · ' || coalesce((select p.name from public.puppy_orders o join public.pets p on p.id = o.pet_id where o.balance_escrow_id = e.id), 'a pet')
              end as title,
              e.status as state, (e.amount_kobo - e.fee_kobo) as amount_kobo, e.created_at as at
         from public.escrow_transactions e
        where e.payee_partner_id = pid
        order by e.created_at desc limit 20)
      union all
      (select 'payout', i.id, 'Weekly payout', i.status, i.amount_kobo, i.created_at
         from public.payout_items i
        where i.partner_account_id = pid
        order by i.created_at desc limit 5)
    ) t;

  return jsonb_build_object(
    'next_payout_on', d + (8 - extract(isodow from d)::integer),
    'next_payout_kobo', coalesce((select sum(amount_kobo - fee_kobo) from public.escrow_transactions
                                   where payee_partner_id = pid and status = 'ready'), 0),
    'held_kobo', coalesce((select sum(amount_kobo - fee_kobo) from public.escrow_transactions
                            where payee_partner_id = pid and status in ('held', 'paused')), 0),
    'paid_month_kobo', coalesce((select sum(amount_kobo) from public.payout_items
                                  where partner_account_id = pid and status = 'sent'
                                    and (created_at at time zone 'Africa/Lagos')::date >= date_trunc('month', now() at time zone 'Africa/Lagos')::date), 0),
    'bank_name', pay.bank_name,
    'account_last4', case when pay.partner_account_id is null then null else right(pay.account_number, 4) end,
    'recent', recent
  );
end;
$$;
revoke all on function public.partner_earnings(uuid) from public, anon;
grant execute on function public.partner_earnings(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Listings (breeders and shelters)
-- ---------------------------------------------------------------------------
-- Adds a pet (or a whole litter) to the partner's listings. Each animal gets its own passport, which moves
-- to the buyer or adopter on handover. Breeders set a price; shelters list for free. Returns the new
-- listing and pet ids so the app can upload the photo into each pet's own folder.
create function public.partner_create_listings(p_partner uuid, p_input jsonb) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  a public.partner_accounts;
  nm text := btrim(coalesce(p_input ->> 'name', ''));
  species text := coalesce(nullif(p_input ->> 'species', ''), 'dog');
  sex text := coalesce(nullif(p_input ->> 'sex', ''), 'unknown');
  born date := nullif(p_input ->> 'born_on', '')::date;
  price bigint := nullif(p_input ->> 'price_kobo', '')::bigint;
  photo text := nullif(p_input ->> 'photo_path', '');
  n integer := coalesce(nullif(p_input ->> 'count', '')::integer, 1);
  mother uuid := nullif(p_input ->> 'mother_pet_id', '')::uuid;
  father uuid := nullif(p_input ->> 'father_pet_id', '')::uuid;
  handover timestamptz := nullif(p_input ->> 'handover_by', '')::timestamptz;
  kind text;
  pet_id uuid;
  listing_id uuid;
  ids jsonb := '[]'::jsonb;
  i integer;
begin
  select * into a from public.partner_accounts where id = p_partner and owner_user_id = me;
  if not found or a.status <> 'approved' or a.type not in ('breeder', 'shelter') then
    raise exception 'Only approved breeders and shelters can list pets' using errcode = '42501';
  end if;
  kind := case when a.type = 'breeder' then 'sale' else 'adoption' end;
  if char_length(nm) not between 1 and 40 then
    raise exception 'Give the pet a name (up to 40 characters)' using errcode = '22023';
  end if;
  if species not in ('dog', 'cat', 'other') or sex not in ('male', 'female', 'unknown') then
    raise exception 'Check the species and sex' using errcode = '22023';
  end if;
  if born is not null and (born > (now() at time zone 'Africa/Lagos')::date or born < date '2000-01-01') then
    raise exception 'Check the date of birth' using errcode = '22023';
  end if;
  if n not between 1 and 12 then
    raise exception 'A litter can have 1 to 12 puppies' using errcode = '22023';
  end if;
  if kind = 'sale' and (price is null or price < 100000 or price > 100000000000) then
    raise exception 'Enter a price of at least 1,000 naira' using errcode = '22023';
  end if;
  if kind = 'adoption' then
    price := null;
  end if;
  if photo is not null and photo not like (me::text || '/%') then
    raise exception 'That photo cannot be used' using errcode = '22023';
  end if;
  if mother is not null and not exists (select 1 from public.pets where id = mother and owner_user_id = me) then
    raise exception 'Choose parents from your own pets' using errcode = '22023';
  end if;
  if father is not null and not exists (select 1 from public.pets where id = father and owner_user_id = me) then
    raise exception 'Choose parents from your own pets' using errcode = '22023';
  end if;

  for i in 1..n loop
    insert into public.pets (owner_user_id, name, species, breed, sex, date_of_birth, photo_path, tag_code,
                             origin_partner_id, mother_pet_id, father_pet_id)
    values (me, case when n = 1 then nm else left(nm, 36) || ' ' || i end, species,
            nullif(btrim(coalesce(p_input ->> 'breed', '')), ''), sex, born, photo, private.new_tag_code(),
            p_partner, mother, father)
    returning id into pet_id;
    insert into public.listings (partner_account_id, pet_id, kind, price_kobo, status, handover_by)
    values (p_partner, pet_id, kind, price, 'live', handover)
    returning id into listing_id;
    ids := ids || jsonb_build_array(jsonb_build_object('listing_id', listing_id, 'pet_id', pet_id));
  end loop;
  return ids;
end;
$$;
revoke all on function public.partner_create_listings(uuid, jsonb) from public, anon;
grant execute on function public.partner_create_listings(uuid, jsonb) to authenticated;

-- Takes a listing down, or puts it back. A reserved or sold listing is handled through its order.
create function public.partner_set_listing_status(p_listing uuid, p_status text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  l public.listings;
begin
  if p_status not in ('live', 'removed') then
    raise exception 'Unknown status' using errcode = '22023';
  end if;
  select * into l from public.listings where id = p_listing for update;
  if not found or not private.owns_approved_partner(l.partner_account_id) then
    raise exception 'Listing not found' using errcode = '42501';
  end if;
  if l.status not in ('draft', 'live', 'removed') then
    raise exception 'This listing is in the middle of a sale or adoption' using errcode = 'P0001';
  end if;
  update public.listings set status = p_status where id = p_listing;
end;
$$;
revoke all on function public.partner_set_listing_status(uuid, text) from public, anon;
grant execute on function public.partner_set_listing_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Adoption applications: the shelter's decisions
-- ---------------------------------------------------------------------------
create function public.decide_application(p_application uuid, p_decision text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  x public.adoption_applications;
  l public.listings;
  pet_name text;
  new_status text;
begin
  new_status := case p_decision when 'home_visit' then 'home_visit' when 'approve' then 'approved' when 'decline' then 'declined' end;
  if new_status is null then
    raise exception 'Unknown decision' using errcode = '22023';
  end if;
  select * into x from public.adoption_applications where id = p_application for update;
  if not found then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  select * into l from public.listings where id = x.listing_id;
  if not private.owns_approved_partner(l.partner_account_id) then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  if x.status in ('approved', 'declined') or l.status not in ('live', 'reserved') then
    raise exception 'This application has already been decided' using errcode = 'P0001';
  end if;
  update public.adoption_applications set status = new_status where id = x.id;
  select name into pet_name from public.pets where id = l.pet_id;
  perform private.notify(x.applicant_user_id, 'booking',
    case new_status
      when 'home_visit' then 'A home visit for ' || pet_name
      when 'approved' then 'Your application for ' || pet_name || ' was approved'
      else 'About your application for ' || pet_name end,
    case new_status
      when 'home_visit' then 'The shelter would like to arrange a short home visit or video call.'
      when 'approved' then 'The shelter will arrange the handover with you.'
      else 'The shelter is not able to go ahead this time. Thank you for applying.' end,
    '/listing/' || l.id, 'application-' || new_status || ':' || x.id);
end;
$$;
revoke all on function public.decide_application(uuid, text) from public, anon;
grant execute on function public.decide_application(uuid, text) to authenticated;

-- The shelter messages an applicant (to arrange a home visit).
create function public.open_application_chat(p_application uuid) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  x public.adoption_applications;
  l public.listings;
  conv uuid;
begin
  select * into x from public.adoption_applications where id = p_application;
  if not found then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  select * into l from public.listings where id = x.listing_id;
  if not private.owns_approved_partner(l.partner_account_id) then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  if private.is_blocked_between(me, x.applicant_user_id) then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  select c.id into conv
    from public.conversations c
    join public.conversation_members m1 on m1.conversation_id = c.id and m1.user_id = me
    join public.conversation_members m2 on m2.conversation_id = c.id and m2.user_id = x.applicant_user_id
   where c.context_type = 'listing' and c.context_id = l.id
   limit 1;
  if conv is not null then
    return conv;
  end if;
  insert into public.conversations (context_type, context_id) values ('listing', l.id) returning id into conv;
  insert into public.conversation_members (conversation_id, user_id) values (conv, me), (conv, x.applicant_user_id);
  return conv;
end;
$$;
revoke all on function public.open_application_chat(uuid) from public, anon;
grant execute on function public.open_application_chat(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Help and support
-- ---------------------------------------------------------------------------
create function public.create_support_ticket(p_topic text, p_message text) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  msg text := btrim(coalesce(p_message, ''));
  t uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if p_topic not in ('payments', 'bookings', 'account', 'lost_pet', 'partner', 'other') then
    raise exception 'Choose a topic' using errcode = '22023';
  end if;
  if char_length(msg) not between 5 and 2000 then
    raise exception 'Tell us a little more (5 to 2000 characters)' using errcode = '22023';
  end if;
  if (select count(*) from public.support_tickets where user_id = me and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'You have sent a few requests already. We will reply soon.' using errcode = 'P0001';
  end if;
  insert into public.support_tickets (user_id, topic, subject)
  values (me, p_topic, left(regexp_replace(msg, '\s+', ' ', 'g'), 80))
  returning id into t;
  insert into public.support_messages (ticket_id, author_user_id, body) values (t, me, msg);
  return t;
end;
$$;
revoke all on function public.create_support_ticket(text, text) from public, anon;
grant execute on function public.create_support_ticket(text, text) to authenticated;

create function public.my_support_tickets()
returns table (ticket_id uuid, number bigint, topic text, subject text, status text, created_at timestamptz)
language sql stable security definer
set search_path = ''
as $$
  select t.id, t.number, t.topic, t.subject, t.status, t.created_at
    from public.support_tickets t
   where t.user_id = (select auth.uid())
   order by t.created_at desc
   limit 20;
$$;
revoke all on function public.my_support_tickets() from public, anon;
grant execute on function public.my_support_tickets() to authenticated;

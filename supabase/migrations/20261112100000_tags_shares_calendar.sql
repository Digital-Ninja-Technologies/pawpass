-- QR tag orders with payment, the list of passports an owner is sharing, blocked accounts, and the partner calendar.
-- Written to match the patterns in the earlier migrations. Apply with the rest (see supabase/README.md).

-- ---------------------------------------------------------------------------
-- QR tag prices live in settings, not in code. Sample values: tag 3,500 naira, delivery 1,000 naira.
-- ---------------------------------------------------------------------------
alter table public.settings
  add column qr_tag_price_kobo integer not null default 350000 check (qr_tag_price_kobo >= 0),
  add column qr_tag_delivery_kobo integer not null default 100000 check (qr_tag_delivery_kobo >= 0);

-- ---------------------------------------------------------------------------
-- Tag orders: pay first, then the team ships. The reference starts with pt_ and goes through Paystack.
-- ---------------------------------------------------------------------------
do $$
declare c text;
begin
  select conname into c
    from pg_constraint
   where conrelid = 'public.qr_tag_orders'::regclass and contype = 'c'
     and pg_get_constraintdef(oid) like '%status%';
  if c is not null then
    execute format('alter table public.qr_tag_orders drop constraint %I', c);
  end if;
end $$;

alter table public.qr_tag_orders
  add constraint qr_tag_orders_status_check
    check (status in ('pending_payment', 'paid', 'shipped', 'delivered', 'cancelled')),
  alter column status set default 'pending_payment',
  add column colour text not null default 'teal' check (colour in ('teal', 'black', 'orange')),
  add column address text not null default '',
  add column area text not null default '',
  add column price_kobo integer not null default 0 check (price_kobo >= 0),
  add column delivery_kobo integer not null default 0 check (delivery_kobo >= 0),
  add column paystack_reference text unique,
  add column paid_at timestamptz;

-- What the order screen shows. Anyone signed in may read the prices.
create function public.tag_prices() returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object('price_kobo', s.qr_tag_price_kobo, 'delivery_kobo', s.qr_tag_delivery_kobo)
    from public.settings s limit 1;
$$;
revoke all on function public.tag_prices() from public, anon;
grant execute on function public.tag_prices() to authenticated;

-- Places an order waiting for payment. The price comes from settings, never from the app.
create function public.create_tag_order(p_pet uuid, p_colour text, p_address text, p_area text) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  s public.settings;
  o public.qr_tag_orders;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not exists (select 1 from public.pets p where p.id = p_pet and p.owner_user_id = me) then
    raise exception 'That is not your pet' using errcode = '42501';
  end if;
  if p_colour not in ('teal', 'black', 'orange') then
    raise exception 'Pick a tag colour' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_address, ''))) < 5 or length(btrim(coalesce(p_address, ''))) > 200 then
    raise exception 'Enter the street address' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_area, ''))) < 2 or length(btrim(coalesce(p_area, ''))) > 80 then
    raise exception 'Enter the area' using errcode = '22023';
  end if;
  select * into s from public.settings limit 1;

  insert into public.qr_tag_orders
    (user_id, pet_id, colour, address, area, price_kobo, delivery_kobo, paystack_reference)
  values
    (me, p_pet, p_colour, btrim(p_address), btrim(p_area), s.qr_tag_price_kobo, s.qr_tag_delivery_kobo,
     'pt_' || replace(gen_random_uuid()::text, '-', ''))
  returning * into o;

  return jsonb_build_object(
    'order_id', o.id,
    'reference', o.paystack_reference,
    'total_kobo', o.price_kobo + o.delivery_kobo);
end;
$$;
revoke all on function public.create_tag_order(uuid, text, text, text) from public, anon;
grant execute on function public.create_tag_order(uuid, text, text, text) to authenticated;

-- Paystack says the money arrived. Safe to run twice. Server side only.
create function public.confirm_tag_payment(p_reference text, p_amount_kobo bigint) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare o public.qr_tag_orders;
begin
  select * into o from public.qr_tag_orders where paystack_reference = p_reference for update;
  if not found then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;
  if o.status in ('paid', 'shipped', 'delivered') then
    return jsonb_build_object('result', 'already_paid', 'order_id', o.id, 'order_status', o.status);
  end if;
  if o.status <> 'pending_payment' then
    raise exception 'This order is not waiting for payment' using errcode = 'P0001';
  end if;
  if p_amount_kobo <> (o.price_kobo + o.delivery_kobo) then
    raise exception 'The amount paid does not match this order' using errcode = 'P0001';
  end if;
  update public.qr_tag_orders set status = 'paid', paid_at = now() where id = o.id;
  return jsonb_build_object('result', 'paid', 'order_id', o.id, 'order_status', 'paid');
end;
$$;
revoke all on function public.confirm_tag_payment(text, bigint) from public, anon, authenticated;
grant execute on function public.confirm_tag_payment(text, bigint) to service_role;

-- The caller's own orders, newest first.
create function public.my_tag_orders() returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', o.id, 'pet_name', p.name, 'colour', o.colour, 'status', o.status,
           'total_kobo', o.price_kobo + o.delivery_kobo, 'created_at', o.created_at,
           'reference', o.paystack_reference) order by o.created_at desc), '[]'::jsonb)
    from public.qr_tag_orders o
    join public.pets p on p.id = o.pet_id
   where o.user_id = (select auth.uid());
$$;
revoke all on function public.my_tag_orders() from public, anon;
grant execute on function public.my_tag_orders() to authenticated;

-- The admin view lists only orders the team can act on (not ones still waiting for payment).
-- Same columns as before, in the same order; only the filter is new.
create or replace view public.admin_qr_v with (security_invoker = true) as
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
join public.pets pt on pt.id = o.pet_id
where o.status in ('paid', 'shipped', 'delivered');

-- ---------------------------------------------------------------------------
-- Privacy & sharing: what the owner is sharing right now, and who they have blocked.
-- ---------------------------------------------------------------------------
create function public.my_active_shares() returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'pet_id', p.id, 'pet_name', p.name,
           'with_name', pa.business_name, 'scopes', s.scopes, 'expires_at', s.expires_at)
           order by s.expires_at), '[]'::jsonb)
    from public.passport_shares s
    join public.pets p on p.id = s.pet_id
    left join public.partner_accounts pa on pa.id = s.partner_account_id
   where p.owner_user_id = (select auth.uid())
     and s.revoked_at is null
     and s.expires_at > now();
$$;
revoke all on function public.my_active_shares() from public, anon;
grant execute on function public.my_active_shares() to authenticated;

create function public.my_blocks() returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', b.id,
           'name', coalesce(nullif(btrim(pr.first_name), ''), 'A PawPass member'))
           order by b.created_at desc), '[]'::jsonb)
    from public.blocks b
    left join public.profiles pr on pr.user_id = b.blocked_user_id
   where b.user_id = (select auth.uid());
$$;
revoke all on function public.my_blocks() from public, anon;
grant execute on function public.my_blocks() to authenticated;

create function public.unblock(p_block uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  delete from public.blocks where id = p_block and user_id = (select auth.uid());
  if not found then
    raise exception 'Block not found' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.unblock(uuid) from public, anon;
grant execute on function public.unblock(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Partner calendar: visits and open times for a date range, and blocking open times.
-- A blocked time is an open slot that is removed, so owners can no longer book it.
-- ---------------------------------------------------------------------------
create function public.partner_calendar(p_from timestamptz, p_to timestamptz, p_partner uuid default null)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  pid uuid;
  a public.partner_accounts;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  pid := private.my_partner_id(p_partner);
  select * into a from public.partner_accounts where id = pid;
  if pid is null or a.status <> 'approved' or a.type not in ('vet', 'service') then
    raise exception 'Your partner account is not approved yet' using errcode = '42501';
  end if;
  if p_to <= p_from or p_to - p_from > interval '31 days' then
    raise exception 'Pick a range of up to 31 days' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'visits', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'booking_id', b.id, 'starts_at', b.starts_at, 'service', s.name, 'pet_name', p.name, 'pet_id', p.id,
               'breed', p.breed, 'owner_name', coalesce(nullif(btrim(op.first_name), ''), 'Owner'),
               'status', b.status, 'passport_shared', b.passport_share_id is not null) order by b.starts_at), '[]'::jsonb)
        from public.bookings b
        join public.services s on s.id = b.service_id
        join public.pets p on p.id = b.pet_id
        join public.profiles op on op.user_id = b.owner_user_id
       where b.partner_account_id = pid
         and b.status in ('confirmed', 'completed_awaiting_owner', 'completed')
         and b.starts_at >= p_from and b.starts_at < p_to),
    'open', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'slot_id', sl.id, 'starts_at', sl.starts_at, 'ends_at', sl.ends_at) order by sl.starts_at), '[]'::jsonb)
        from public.availability_slots sl
       where sl.partner_account_id = pid
         and sl.starts_at >= p_from and sl.starts_at < p_to
         and sl.capacity > private.slot_taken(pid, sl.starts_at)));
end;
$$;
revoke all on function public.partner_calendar(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.partner_calendar(timestamptz, timestamptz, uuid) to authenticated;

-- Removes the open times in a range. Times that already have a booking are left alone. Returns how many went.
create function public.partner_block_slots(p_from timestamptz, p_to timestamptz, p_partner uuid default null)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  pid uuid;
  a public.partner_accounts;
  n integer;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  pid := private.my_partner_id(p_partner);
  select * into a from public.partner_accounts where id = pid;
  if pid is null or a.status <> 'approved' or a.type not in ('vet', 'service') then
    raise exception 'Your partner account is not approved yet' using errcode = '42501';
  end if;
  if p_to <= p_from or p_to - p_from > interval '31 days' then
    raise exception 'Pick a range of up to 31 days' using errcode = '22023';
  end if;
  delete from public.availability_slots sl
   where sl.partner_account_id = pid
     and sl.starts_at >= p_from and sl.starts_at < p_to
     and private.slot_taken(pid, sl.starts_at) = 0;
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.partner_block_slots(timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.partner_block_slots(timestamptz, timestamptz, uuid) to authenticated;

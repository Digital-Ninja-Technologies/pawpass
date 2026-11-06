-- Trust (milestone 5): find a pet from a verified breeder or shelter, pay a deposit into escrow, hand over,
-- accept the passport, and the 72 hour vet check window. Adoption applications and free handovers too.
-- Money moves only through the escrow state machine from the services milestone.

-- ---------------------------------------------------------------------------
-- Puppy orders: one buyer, one listing, a deposit now and the balance at handover
-- ---------------------------------------------------------------------------
create table public.puppy_orders (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id),
  buyer_user_id uuid not null references auth.users (id),
  partner_account_id uuid not null references public.partner_accounts (id),
  pet_id uuid not null references public.pets (id),
  -- Copied when the order is made, so later edits to the listing never change what was agreed.
  price_kobo bigint not null check (price_kobo > 0),
  deposit_kobo bigint not null check (deposit_kobo > 0),
  protection_fee_kobo bigint not null check (protection_fee_kobo >= 0),
  balance_kobo bigint not null check (balance_kobo >= 0),
  deposit_reference text not null unique,
  balance_reference text unique,
  deposit_escrow_id uuid references public.escrow_transactions (id),
  balance_escrow_id uuid references public.escrow_transactions (id),
  status text not null default 'pending_deposit'
    check (status in ('pending_deposit', 'deposit_paid', 'balance_paid', 'handed_over', 'completed', 'disputed', 'cancelled')),
  handover_by timestamptz,
  handed_over_at timestamptz,
  vet_check_ends_at timestamptz,
  accepted_at timestamptz,
  cancelled_at timestamptz,
  cancel_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.puppy_orders (buyer_user_id);
create index on public.puppy_orders (partner_account_id, status);
create index on public.puppy_orders (listing_id);
-- Only one buyer can have paid for a listing.
create unique index puppy_orders_one_paid on public.puppy_orders (listing_id)
  where status in ('deposit_paid', 'balance_paid', 'handed_over', 'completed', 'disputed');

create trigger touch_updated_at before update on public.puppy_orders
  for each row execute function private.touch_updated_at();

alter table public.puppy_orders enable row level security;
create policy "buyer, seller or staff read an order" on public.puppy_orders for select to authenticated
  using (
    buyer_user_id = (select auth.uid())
    or private.owns_partner(partner_account_id)
    or private.is_staff(array['payouts_disputes', 'read_only'])
  );
revoke all on public.puppy_orders from anon, authenticated;
grant select on public.puppy_orders to authenticated;

alter table public.ownership_transfers
  add column kind text not null default 'sale' check (kind in ('sale', 'adoption')),
  add column order_id uuid references public.puppy_orders (id),
  add column application_id uuid references public.adoption_applications (id),
  add column handover_confirmed_at timestamptz;
create unique index ownership_transfers_one_open on public.ownership_transfers (pet_id) where completed_at is null;

-- ---------------------------------------------------------------------------
-- Money for an order: deposit is a fraction of the price, the protection fee is a percentage of the deposit,
-- the balance is the rest. Rounded to whole kobo.
-- ---------------------------------------------------------------------------
create function private.order_amounts(p_price bigint)
returns table (deposit_kobo bigint, fee_kobo bigint, balance_kobo bigint)
language sql stable
set search_path = ''
as $$
  select d, round(d * s.puppy_escrow_fee_bps / 10000.0)::bigint, p_price - d
    from public.settings s,
         lateral (select least(p_price, ceil(p_price * s.deposit_fraction)::bigint) as d) x;
$$;
revoke all on function private.order_amounts(bigint) from public, anon;
grant execute on function private.order_amounts(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Browsing
-- ---------------------------------------------------------------------------
create function public.adopt_listings(
  p_kind text default null,
  p_species text default null,
  p_query text default null,
  p_limit integer default 30
) returns table (
  listing_id uuid,
  kind text,
  price_kobo bigint,
  pet_id uuid,
  pet_name text,
  species text,
  breed text,
  sex text,
  born_on date,
  photo_path text,
  partner_id uuid,
  partner_name text,
  partner_type text,
  partner_area text,
  reserved boolean
)
language sql stable security definer
set search_path = ''
as $$
  select l.id, l.kind, l.price_kobo, p.id, p.name, p.species, p.breed, p.sex, p.date_of_birth, p.photo_path,
         a.id, a.business_name, a.type, a.area, l.status = 'reserved'
    from public.listings l
    join public.pets p on p.id = l.pet_id
    join public.partner_accounts a on a.id = l.partner_account_id and a.status = 'approved'
   where (select auth.uid()) is not null
     and l.status in ('live', 'reserved')
     and (p_kind is null or l.kind = p_kind)
     and (p_species is null or p.species = p_species)
     and (p_query is null or btrim(p_query) = ''
          or p.name ilike '%' || btrim(p_query) || '%'
          or p.breed ilike '%' || btrim(p_query) || '%'
          or a.business_name ilike '%' || btrim(p_query) || '%')
   order by (l.status = 'live') desc, l.created_at desc
   limit least(greatest(coalesce(p_limit, 30), 1), 60);
$$;
revoke all on function public.adopt_listings(text, text, text, integer) from public, anon;
grant execute on function public.adopt_listings(text, text, text, integer) to authenticated;

-- One listing in full: the pet, who sells it, what transfers, what it costs, and where the caller stands.
create function public.listing_detail(p_listing uuid) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  l public.listings;
  p public.pets;
  a public.partner_accounts;
  dep bigint;
  fee bigint;
  bal bigint;
  my_order public.puppy_orders;
  my_app public.adoption_applications;
  mother text;
  father text;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into l from public.listings where id = p_listing;
  select * into a from public.partner_accounts where id = l.partner_account_id;
  if not found or (l.status not in ('live', 'reserved') and not private.owns_partner(l.partner_account_id)
                   and not exists (select 1 from public.puppy_orders o where o.listing_id = l.id and o.buyer_user_id = me)
                   and not exists (select 1 from public.adoption_applications x where x.listing_id = l.id and x.applicant_user_id = me)) then
    raise exception 'Listing not found' using errcode = 'P0002';
  end if;
  if a.status <> 'approved' and not private.owns_partner(a.id) then
    raise exception 'Listing not found' using errcode = 'P0002';
  end if;
  select * into p from public.pets where id = l.pet_id;
  select m.name into mother from public.pets m where m.id = p.mother_pet_id;
  select f.name into father from public.pets f where f.id = p.father_pet_id;
  if l.kind = 'sale' then
    select o.deposit_kobo, o.fee_kobo, o.balance_kobo into dep, fee, bal from private.order_amounts(l.price_kobo) o;
  end if;
  select * into my_order from public.puppy_orders o
   where o.listing_id = l.id and o.buyer_user_id = me and o.status <> 'cancelled'
   order by o.created_at desc limit 1;
  select * into my_app from public.adoption_applications x where x.listing_id = l.id and x.applicant_user_id = me;

  return jsonb_build_object(
    'listing_id', l.id,
    'kind', l.kind,
    'status', l.status,
    'price_kobo', l.price_kobo,
    'handover_by', l.handover_by,
    'deposit_kobo', dep,
    'protection_fee_kobo', fee,
    'due_today_kobo', dep + fee,
    'balance_kobo', bal,
    'pet', jsonb_build_object(
      'id', p.id, 'name', p.name, 'species', p.species, 'breed', p.breed, 'sex', p.sex,
      'born_on', p.date_of_birth, 'colour', p.colour_markings, 'photo_path', p.photo_path),
    'partner', jsonb_build_object(
      'id', a.id, 'name', a.business_name, 'type', a.type, 'area', a.area,
      'verified', a.verified_at is not null),
    'mother_name', mother,
    'father_name', father,
    -- What the seller chose to show with the listing: type, name, date and whether a vet verified it. No notes or files.
    'records', coalesce((
      select jsonb_agg(jsonb_build_object(
               'type', r.type, 'name', r.name, 'given_on', r.given_on, 'verified', r.verified_by_partner_id is not null)
             order by r.given_on desc nulls last)
        from public.health_records r
       where r.pet_id = p.id and r.type in ('vaccine', 'deworming', 'vet_visit')
    ), '[]'::jsonb),
    'is_mine', private.owns_partner(a.id),
    'my_order_id', my_order.id,
    'my_order_status', my_order.status,
    'my_application_id', my_app.id,
    'my_application_status', my_app.status,
    'my_transfer_id', (select t.id from public.ownership_transfers t
                        where t.application_id = my_app.id and t.completed_at is null limit 1)
  );
end;
$$;
revoke all on function public.listing_detail(uuid) from public, anon;
grant execute on function public.listing_detail(uuid) to authenticated;

-- Message the seller about a listing.
create function public.open_listing_chat(p_listing uuid) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  l public.listings;
  owner uuid;
  conv uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into l from public.listings where id = p_listing and status in ('live', 'reserved');
  if not found then
    raise exception 'Listing not found' using errcode = 'P0002';
  end if;
  select a.owner_user_id into owner from public.partner_accounts a where a.id = l.partner_account_id and a.status = 'approved';
  if owner is null then
    raise exception 'Listing not found' using errcode = 'P0002';
  end if;
  if owner = me then
    raise exception 'This is your own listing' using errcode = '22023';
  end if;
  if private.is_blocked_between(owner, me) then
    raise exception 'Listing not found' using errcode = 'P0002';
  end if;
  select c.id into conv
    from public.conversations c
    join public.conversation_members m1 on m1.conversation_id = c.id and m1.user_id = me
    join public.conversation_members m2 on m2.conversation_id = c.id and m2.user_id = owner
   where c.context_type = 'listing' and c.context_id = p_listing
   limit 1;
  if conv is not null then
    return conv;
  end if;
  insert into public.conversations (context_type, context_id) values ('listing', p_listing) returning id into conv;
  insert into public.conversation_members (conversation_id, user_id) values (conv, me), (conv, owner);
  return conv;
end;
$$;
revoke all on function public.open_listing_chat(uuid) from public, anon;
grant execute on function public.open_listing_chat(uuid) to authenticated;

-- The inbox names listing chats after the pet.
create or replace function public.my_conversations()
returns table (
  conversation_id uuid,
  context_type text,
  context_id uuid,
  context_label text,
  other_user_id uuid,
  other_name text,
  last_body text,
  last_at timestamptz,
  unread integer
)
language sql stable security definer
set search_path = ''
as $$
  select c.id, c.context_type, c.context_id,
         case c.context_type
           when 'lost_alert' then 'Lost alert · ' || coalesce((
             select p.name from public.lost_alerts a join public.pets p on p.id = a.pet_id where a.id = c.context_id), 'a pet')
           when 'listing' then 'Listing · ' || coalesce((
             select p.name from public.listings l join public.pets p on p.id = l.pet_id where l.id = c.context_id), 'a pet')
           else initcap(replace(c.context_type, '_', ' '))
         end,
         o.user_id,
         coalesce(nullif(btrim(op.first_name), ''), 'Someone'),
         case when lm.location is not null and lm.body is null then 'Shared a location' else lm.body end,
         coalesce(lm.created_at, c.created_at),
         (select count(*)::integer from public.messages m
           where m.conversation_id = c.id and m.sender_user_id <> (select auth.uid())
             and (me.last_read_at is null or m.created_at > me.last_read_at))
    from public.conversations c
    join public.conversation_members me on me.conversation_id = c.id and me.user_id = (select auth.uid())
    join public.conversation_members o on o.conversation_id = c.id and o.user_id <> (select auth.uid())
    join public.profiles op on op.user_id = o.user_id
    left join lateral (
      select m.body, m.location, m.created_at from public.messages m
       where m.conversation_id = c.id order by m.created_at desc limit 1
    ) lm on true
   where not private.is_blocked_between(o.user_id, (select auth.uid()))
   order by coalesce(lm.created_at, c.created_at) desc;
$$;

-- ---------------------------------------------------------------------------
-- Buying: deposit into escrow
-- ---------------------------------------------------------------------------
create function public.create_puppy_order(p_listing uuid) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  l public.listings;
  a public.partner_accounts;
  p public.pets;
  st public.settings;
  amounts record;
  o public.puppy_orders;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into l from public.listings where id = p_listing;
  if not found or l.kind <> 'sale' then
    raise exception 'This pet is not for sale' using errcode = '22023';
  end if;
  if l.status <> 'live' then
    raise exception 'This pet is no longer available' using errcode = 'P0001';
  end if;
  select * into a from public.partner_accounts where id = l.partner_account_id and status = 'approved';
  if not found then
    raise exception 'This seller is not taking orders' using errcode = '22023';
  end if;
  if a.owner_user_id = me then
    raise exception 'You cannot buy your own listing' using errcode = '22023';
  end if;
  if private.is_blocked_between(a.owner_user_id, me) then
    raise exception 'Listing not found' using errcode = 'P0002';
  end if;
  select * into p from public.pets where id = l.pet_id;
  if p.owner_user_id <> a.owner_user_id then
    raise exception 'This listing is not available' using errcode = 'P0001';
  end if;
  if coalesce(l.price_kobo, 0) <= 0 then
    raise exception 'This listing has no price yet' using errcode = '22023';
  end if;
  select * into st from public.settings limit 1;
  select * into amounts from private.order_amounts(l.price_kobo);

  -- Coming back to pay reuses the unpaid order while its hold lasts.
  select * into o from public.puppy_orders x
   where x.listing_id = l.id and x.buyer_user_id = me and x.status = 'pending_deposit'
     and x.created_at > now() - make_interval(mins => st.booking_hold_minutes)
   order by x.created_at desc limit 1;
  if not found then
    insert into public.puppy_orders
      (listing_id, buyer_user_id, partner_account_id, pet_id, price_kobo, deposit_kobo, protection_fee_kobo, balance_kobo,
       deposit_reference, handover_by)
    values
      (l.id, me, a.id, p.id, l.price_kobo, amounts.deposit_kobo, amounts.fee_kobo, amounts.balance_kobo,
       'pd_' || replace(gen_random_uuid()::text, '-', ''), l.handover_by)
    returning * into o;
  end if;

  return jsonb_build_object(
    'order_id', o.id,
    'reference', o.deposit_reference,
    'amount_kobo', o.deposit_kobo + o.protection_fee_kobo,
    'price_kobo', o.price_kobo,
    'deposit_kobo', o.deposit_kobo,
    'protection_fee_kobo', o.protection_fee_kobo,
    'balance_kobo', o.balance_kobo,
    'pet_name', p.name,
    'partner_name', a.business_name
  );
end;
$$;
revoke all on function public.create_puppy_order(uuid) from public, anon;
grant execute on function public.create_puppy_order(uuid) to authenticated;

-- The balance is paid when the puppy is collected.
create function public.create_balance_payment(p_order uuid) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  o public.puppy_orders;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into o from public.puppy_orders where id = p_order and buyer_user_id = me for update;
  if not found then
    raise exception 'Order not found' using errcode = '42501';
  end if;
  if o.status <> 'deposit_paid' then
    raise exception 'The balance can be paid once the deposit is in and before handover' using errcode = 'P0001';
  end if;
  if o.balance_kobo <= 0 then
    raise exception 'There is no balance to pay' using errcode = 'P0001';
  end if;
  if o.balance_reference is null then
    update public.puppy_orders set balance_reference = 'pb_' || replace(gen_random_uuid()::text, '-', '')
     where id = o.id returning * into o;
  end if;
  return jsonb_build_object('order_id', o.id, 'reference', o.balance_reference, 'amount_kobo', o.balance_kobo);
end;
$$;
revoke all on function public.create_balance_payment(uuid) from public, anon;
grant execute on function public.create_balance_payment(uuid) to authenticated;

-- Payment received (deposit or balance). Called only by the payments function after it has checked
-- Paystack. Safe to call twice for the same reference.
create function public.confirm_order_payment(p_reference text, p_amount_kobo bigint) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  o public.puppy_orders;
  l public.listings;
  a public.partner_accounts;
  esc public.escrow_transactions;
  is_deposit boolean;
  expected bigint;
  late boolean;
  pet_name text;
begin
  select * into o from public.puppy_orders where deposit_reference = p_reference or balance_reference = p_reference for update;
  if not found then
    raise exception 'Unknown payment reference' using errcode = 'P0002';
  end if;
  is_deposit := o.deposit_reference = p_reference;
  if (is_deposit and o.deposit_escrow_id is not null) or (not is_deposit and o.balance_escrow_id is not null) then
    return jsonb_build_object('result', 'already_confirmed', 'order_id', o.id, 'order_status', o.status);
  end if;
  expected := case when is_deposit then o.deposit_kobo + o.protection_fee_kobo else o.balance_kobo end;
  if p_amount_kobo is distinct from expected then
    raise exception 'The amount paid does not match the order' using errcode = 'P0001';
  end if;
  select * into l from public.listings where id = o.listing_id for update;
  select * into a from public.partner_accounts where id = o.partner_account_id;
  select name into pet_name from public.pets where id = o.pet_id;

  if is_deposit then
    -- Too late if the order was cancelled, the listing was taken by someone else, or it is no longer for sale.
    late := o.status <> 'pending_deposit' or l.status <> 'live'
         or exists (select 1 from public.puppy_orders x
                     where x.listing_id = o.listing_id and x.id <> o.id
                       and x.status in ('deposit_paid', 'balance_paid', 'handed_over', 'completed', 'disputed'));
    insert into public.escrow_transactions (payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference)
    values (o.buyer_user_id, o.partner_account_id, 'puppy_deposit', expected, o.protection_fee_kobo, 'held', p_reference)
    returning * into esc;
    if late then
      update public.escrow_transactions set status = 'refunded' where id = esc.id;
      update public.puppy_orders
         set status = 'cancelled', deposit_escrow_id = esc.id, cancelled_at = coalesce(cancelled_at, now()),
             cancel_reason = coalesce(cancel_reason, 'listing_unavailable')
       where id = o.id;
      perform private.notify(o.buyer_user_id, 'booking', 'We could not reserve ' || pet_name,
        'Someone else reserved ' || pet_name || ' first. Your payment is being refunded in full.', '/orders/' || o.id, 'order-refund:' || o.id);
      return jsonb_build_object('result', 'refunded', 'order_id', o.id, 'order_status', 'cancelled');
    end if;
    update public.puppy_orders set status = 'deposit_paid', deposit_escrow_id = esc.id where id = o.id;
    update public.listings set status = 'reserved' where id = l.id;
    perform private.notify(o.buyer_user_id, 'booking', 'Deposit paid for ' || pet_name,
      'Your deposit is held in escrow. Arrange the pick up with ' || a.business_name || '.', '/orders/' || o.id, 'order-deposit:' || o.id);
    perform private.notify(a.owner_user_id, 'booking', pet_name || ' is reserved',
      'A buyer paid the deposit. Arrange the handover and confirm it in the app.', '/orders/' || o.id, 'order-deposit-p:' || o.id);
    return jsonb_build_object('result', 'confirmed', 'order_id', o.id, 'order_status', 'deposit_paid');
  end if;

  -- balance
  insert into public.escrow_transactions (payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference)
  values (o.buyer_user_id, o.partner_account_id, 'puppy_balance', expected, 0, 'held', p_reference)
  returning * into esc;
  if o.status <> 'deposit_paid' then
    update public.escrow_transactions set status = 'refunded' where id = esc.id;
    update public.puppy_orders set balance_escrow_id = esc.id where id = o.id;
    perform private.notify(o.buyer_user_id, 'booking', 'We returned your payment',
      'The order for ' || pet_name || ' was no longer open. Your payment is being refunded in full.', '/orders/' || o.id, 'order-balance-refund:' || o.id);
    return jsonb_build_object('result', 'refunded', 'order_id', o.id, 'order_status', o.status);
  end if;
  update public.puppy_orders set status = 'balance_paid', balance_escrow_id = esc.id where id = o.id;
  perform private.notify(a.owner_user_id, 'booking', 'Balance paid for ' || pet_name,
    'The buyer has paid the balance into escrow. Confirm the handover when you hand ' || pet_name || ' over.', '/orders/' || o.id, 'order-balance-p:' || o.id);
  return jsonb_build_object('result', 'confirmed', 'order_id', o.id, 'order_status', 'balance_paid');
end;
$$;
revoke all on function public.confirm_order_payment(text, bigint) from public, anon, authenticated;
grant execute on function public.confirm_order_payment(text, bigint) to service_role;

-- An unpaid order can be dropped.
create function public.cancel_unpaid_order(p_order uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.puppy_orders
     set status = 'cancelled', cancelled_at = now(), cancel_reason = 'buyer'
   where id = p_order and buyer_user_id = (select auth.uid()) and status = 'pending_deposit';
  if not found then
    raise exception 'This order cannot be cancelled' using errcode = 'P0001';
  end if;
end;
$$;
revoke all on function public.cancel_unpaid_order(uuid) from public, anon;
grant execute on function public.cancel_unpaid_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Handover and passport transfer
-- ---------------------------------------------------------------------------
-- The seller confirms the handover. The vet check window starts now; the buyer then accepts the passport.
create function public.partner_confirm_handover(p_order uuid) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  o public.puppy_orders;
  st public.settings;
  transfer uuid;
  pet_name text;
begin
  select * into o from public.puppy_orders where id = p_order for update;
  if not found or not private.owns_partner(o.partner_account_id) then
    raise exception 'Order not found' using errcode = '42501';
  end if;
  if o.status <> 'balance_paid' then
    raise exception 'Handover can be confirmed once the buyer has paid the balance' using errcode = 'P0001';
  end if;
  select * into st from public.settings limit 1;
  select name into pet_name from public.pets where id = o.pet_id;

  update public.puppy_orders
     set status = 'handed_over', handed_over_at = now(),
         vet_check_ends_at = now() + make_interval(hours => st.vet_check_hours)
   where id = o.id;
  update public.listings set status = 'sold' where id = o.listing_id;
  insert into public.ownership_transfers
    (pet_id, from_user_id, from_partner_id, to_user_id, escrow_transaction_id, kind, order_id, handover_confirmed_at)
  select o.pet_id, p.owner_user_id, o.partner_account_id, o.buyer_user_id, o.deposit_escrow_id, 'sale', o.id, now()
    from public.pets p where p.id = o.pet_id
  returning id into transfer;
  perform private.notify(o.buyer_user_id, 'booking', pet_name || ' is coming home',
    'The handover is confirmed. Accept ' || pet_name || '''s passport, and book a vet check within ' || st.vet_check_hours || ' hours.',
    '/orders/' || o.id, 'order-handover:' || o.id);
  return transfer;
end;
$$;
revoke all on function public.partner_confirm_handover(uuid) from public, anon;
grant execute on function public.partner_confirm_handover(uuid) to authenticated;

-- Moves the pet and its passport to the new owner. Shared by sales and adoptions.
create function private.complete_transfer(p_transfer uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  t public.ownership_transfers;
  new_channels text[];
begin
  select * into t from public.ownership_transfers where id = p_transfer for update;
  if t.completed_at is not null then
    return;
  end if;
  update public.pets set owner_user_id = t.to_user_id where id = t.pet_id;
  update public.ownership_transfers set completed_at = now() where id = t.id;
  -- The old owner's vet links and reminders must not carry over.
  update public.passport_shares set revoked_at = now() where pet_id = t.pet_id and revoked_at is null;
  select reminder_channels into new_channels from public.profiles where user_id = t.to_user_id;
  update public.reminders set channels = coalesce(new_channels, array['push'])
   where pet_id = t.pet_id and status in ('scheduled', 'snoozed');
  delete from public.follows where pet_id = t.pet_id and follower_user_id = t.to_user_id;
  if t.order_id is not null then
    update public.puppy_orders set accepted_at = now() where id = t.order_id;
  end if;
end;
$$;
revoke all on function private.complete_transfer(uuid) from public, anon, authenticated;

create function public.accept_passport(p_transfer uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  t public.ownership_transfers;
  pet_name text;
  partner_owner uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into t from public.ownership_transfers where id = p_transfer and to_user_id = me for update;
  if not found then
    raise exception 'Transfer not found' using errcode = '42501';
  end if;
  if t.completed_at is not null then
    raise exception 'This passport has already been accepted' using errcode = 'P0001';
  end if;
  if t.handover_confirmed_at is null then
    raise exception 'The handover has not been confirmed yet' using errcode = 'P0001';
  end if;
  if t.order_id is not null and (select status from public.puppy_orders where id = t.order_id) = 'disputed' then
    raise exception 'A problem report is open for this order' using errcode = 'P0001';
  end if;
  perform private.complete_transfer(t.id);
  select name into pet_name from public.pets where id = t.pet_id;
  select a.owner_user_id into partner_owner from public.partner_accounts a where a.id = t.from_partner_id;
  perform private.notify(partner_owner, 'booking', pet_name || '''s passport was accepted',
    'The passport moved to the new owner. You keep a read only record of the transfer.', '/orders', 'transfer-accepted:' || t.id);
end;
$$;
revoke all on function public.accept_passport(uuid) from public, anon;
grant execute on function public.accept_passport(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Problems inside the vet check window
-- ---------------------------------------------------------------------------
create function public.open_order_dispute(p_order uuid, p_reason text, p_details text default null) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  o public.puppy_orders;
  st public.settings;
  label text;
  main_escrow uuid;
  d uuid;
  pet_name text;
  partner_owner uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  label := case p_reason
    when 'health_problem' then 'A vet found a health problem'
    when 'not_as_described' then 'Not as described'
    when 'other' then 'Something else'
  end;
  if label is null then
    raise exception 'Choose what went wrong' using errcode = '22023';
  end if;
  if char_length(coalesce(p_details, '')) > 2000 then
    raise exception 'That report is too long' using errcode = '22023';
  end if;
  select * into o from public.puppy_orders where id = p_order and buyer_user_id = me for update;
  if not found then
    raise exception 'Order not found' using errcode = '42501';
  end if;
  if o.status <> 'handed_over' then
    raise exception 'A problem can be reported after the handover, during the vet check window' using errcode = 'P0001';
  end if;
  if now() > o.vet_check_ends_at then
    raise exception 'The vet check window has ended' using errcode = 'P0001';
  end if;

  update public.escrow_transactions set status = 'paused'
   where id in (o.deposit_escrow_id, o.balance_escrow_id) and status = 'held';
  main_escrow := coalesce(o.balance_escrow_id, o.deposit_escrow_id);
  select * into st from public.settings limit 1;
  insert into public.disputes (escrow_transaction_id, opened_by_user_id, reason, details, status, due_at)
  values (main_escrow, me, label, nullif(btrim(p_details), ''), 'open', now() + make_interval(hours => st.dispute_decision_hours))
  returning id into d;
  update public.puppy_orders set status = 'disputed' where id = o.id;

  select name into pet_name from public.pets where id = o.pet_id;
  select a.owner_user_id into partner_owner from public.partner_accounts a where a.id = o.partner_account_id;
  perform private.notify(partner_owner, 'booking', 'A problem was reported',
    pet_name || ' was reported. The payment is on hold while PawPass reviews both sides.', '/orders/' || o.id, 'order-disputed-p:' || o.id);
  perform private.notify(me, 'booking', 'We got your report',
    'The payment stays on hold. PawPass decides within ' || st.dispute_decision_hours || ' hours.', '/orders/' || o.id, 'order-disputed:' || o.id);
  return d;
end;
$$;
revoke all on function public.open_order_dispute(uuid, text, text) from public, anon;
grant execute on function public.open_order_dispute(uuid, text, text) to authenticated;

-- When the window passes with no problem, the seller is paid (in the next payout run) and the transfer is final.
create function public.release_due_orders() returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  o public.puppy_orders;
  t uuid;
  n integer := 0;
  pet_name text;
  partner_owner uuid;
begin
  for o in
    select * from public.puppy_orders
     where status = 'handed_over' and vet_check_ends_at < now()
     for update skip locked
  loop
    update public.escrow_transactions set status = 'ready'
     where id in (o.deposit_escrow_id, o.balance_escrow_id) and status = 'held';
    select id into t from public.ownership_transfers where order_id = o.id and completed_at is null;
    if t is not null then
      perform private.complete_transfer(t);
    end if;
    update public.puppy_orders set status = 'completed' where id = o.id;
    select name into pet_name from public.pets where id = o.pet_id;
    select a.owner_user_id into partner_owner from public.partner_accounts a where a.id = o.partner_account_id;
    perform private.notify(partner_owner, 'booking', 'Payment released for ' || pet_name,
      'The vet check window ended with no problem. The payment goes out in the next payout run.', '/orders/' || o.id, 'order-released:' || o.id);
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function public.release_due_orders() from public, anon, authenticated;
grant execute on function public.release_due_orders() to service_role;

-- A seller who cancels before handover always refunds everything the buyer paid.
create function public.partner_cancel_order(p_order uuid, p_reason text default null) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  o public.puppy_orders;
  pet_name text;
begin
  select * into o from public.puppy_orders where id = p_order for update;
  if not found or not private.owns_partner(o.partner_account_id) then
    raise exception 'Order not found' using errcode = '42501';
  end if;
  if o.status not in ('deposit_paid', 'balance_paid') then
    raise exception 'This order can no longer be cancelled' using errcode = 'P0001';
  end if;
  update public.escrow_transactions set status = 'refunded'
   where id in (o.deposit_escrow_id, o.balance_escrow_id) and status = 'held';
  update public.puppy_orders
     set status = 'cancelled', cancelled_at = now(), cancel_reason = coalesce(nullif(btrim(p_reason), ''), 'seller')
   where id = o.id;
  update public.listings set status = 'live' where id = o.listing_id and status = 'reserved';
  select name into pet_name from public.pets where id = o.pet_id;
  perform private.notify(o.buyer_user_id, 'booking', 'Your order was cancelled',
    'The seller cancelled the order for ' || pet_name || '. Everything you paid is being refunded in full.', '/orders/' || o.id, 'order-cancelled:' || o.id);
end;
$$;
revoke all on function public.partner_cancel_order(uuid, text) from public, anon;
grant execute on function public.partner_cancel_order(uuid, text) to authenticated;

-- Staff decide a problem. A puppy sale is decided as a full refund or a full release (no split), and both
-- payments of the order move together.
create or replace function public.admin_decide_dispute(p_dispute uuid, p_decision text, p_refund_kobo bigint default null, p_note text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  d public.disputes;
  e public.escrow_transactions;
  o public.puppy_orders;
  v_refund bigint;
  sibling uuid;
  pet_name text;
  partner_owner uuid;
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
  select * into o from public.puppy_orders x where x.deposit_escrow_id = e.id or x.balance_escrow_id = e.id;
  if found and p_decision = 'split' then
    raise exception 'A puppy sale is decided as a full refund or a full release' using errcode = '22023';
  end if;

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

  update public.escrow_transactions
     set status = case p_decision when 'refund' then 'refunded' when 'split' then 'partially_refunded' else 'ready' end,
         refund_kobo = case when p_decision = 'split' then v_refund else refund_kobo end
   where id = e.id;

  if o.id is not null then
    sibling := case when o.deposit_escrow_id = e.id then o.balance_escrow_id else o.deposit_escrow_id end;
    if sibling is not null then
      update public.escrow_transactions
         set status = case p_decision when 'refund' then 'refunded' else 'ready' end
       where id = sibling and status = 'paused';
    end if;
    update public.puppy_orders
       set status = case p_decision when 'refund' then 'cancelled' else 'completed' end,
           cancelled_at = case p_decision when 'refund' then now() else cancelled_at end,
           cancel_reason = case p_decision when 'refund' then 'dispute_refund' else cancel_reason end
     where id = o.id;
    select name into pet_name from public.pets where id = o.pet_id;
    select a.owner_user_id into partner_owner from public.partner_accounts a where a.id = o.partner_account_id;
    perform private.notify(o.buyer_user_id, 'booking', 'PawPass decided your report',
      case p_decision when 'refund' then 'Your payments for ' || pet_name || ' are being refunded in full.'
                      else 'The payments for ' || pet_name || ' go to the seller.' end,
      '/orders/' || o.id, 'order-decided:' || o.id);
    perform private.notify(partner_owner, 'booking', 'A reported sale was decided',
      case p_decision when 'refund' then 'The buyer is refunded in full.' else 'The payment goes to you.' end,
      '/orders/' || o.id, 'order-decided-p:' || o.id);
  end if;

  perform private.write_audit('dispute.' || p_decision, 'dispute', p_dispute,
    jsonb_build_object('escrow_id', e.id, 'amount_kobo', e.amount_kobo, 'refund_kobo', v_refund,
                       'note', nullif(btrim(p_note), '')));
end;
$$;

-- ---------------------------------------------------------------------------
-- Reading orders
-- ---------------------------------------------------------------------------
-- One order for the buyer or the seller: the steps, the money, and the next thing to do.
create function public.puppy_order_detail(p_order uuid) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  o public.puppy_orders;
  p public.pets;
  a public.partner_accounts;
  buyer_name text;
  t public.ownership_transfers;
  dis public.disputes;
  mine boolean;
  seller boolean;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into o from public.puppy_orders where id = p_order;
  mine := found and o.buyer_user_id = me;
  seller := found and private.owns_partner(o.partner_account_id);
  if not found or not (mine or seller) then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;
  select * into p from public.pets where id = o.pet_id;
  select * into a from public.partner_accounts where id = o.partner_account_id;
  select coalesce(nullif(btrim(first_name), ''), 'The buyer') into buyer_name from public.profiles where user_id = o.buyer_user_id;
  select * into t from public.ownership_transfers where order_id = o.id;
  select x.* into dis from public.disputes x
   where x.escrow_transaction_id in (o.deposit_escrow_id, o.balance_escrow_id) order by x.created_at desc limit 1;

  return jsonb_build_object(
    'order_id', o.id,
    'status', o.status,
    'is_buyer', mine,
    'is_seller', seller,
    'listing_id', o.listing_id,
    'pet_id', p.id,
    'pet_name', p.name,
    'species', p.species,
    'breed', p.breed,
    'photo_path', p.photo_path,
    'partner_id', a.id,
    'partner_name', a.business_name,
    'buyer_name', buyer_name,
    'price_kobo', o.price_kobo,
    'deposit_kobo', o.deposit_kobo,
    'protection_fee_kobo', o.protection_fee_kobo,
    'balance_kobo', o.balance_kobo,
    'deposit_paid', o.deposit_escrow_id is not null,
    'balance_paid', o.balance_escrow_id is not null,
    'handover_by', o.handover_by,
    'handed_over_at', o.handed_over_at,
    'vet_check_ends_at', o.vet_check_ends_at,
    'accepted_at', o.accepted_at,
    'transfer_id', t.id,
    'transfer_completed', t.completed_at is not null,
    'dispute_status', dis.status,
    'dispute_due_at', dis.due_at,
    'cancel_reason', o.cancel_reason,
    'created_at', o.created_at
  );
end;
$$;
revoke all on function public.puppy_order_detail(uuid) from public, anon;
grant execute on function public.puppy_order_detail(uuid) to authenticated;

create function public.my_orders()
returns table (order_id uuid, status text, pet_name text, partner_name text, price_kobo bigint, created_at timestamptz, is_buyer boolean)
language sql stable security definer
set search_path = ''
as $$
  select o.id, o.status, p.name, a.business_name, o.price_kobo, o.created_at, o.buyer_user_id = (select auth.uid())
    from public.puppy_orders o
    join public.pets p on p.id = o.pet_id
    join public.partner_accounts a on a.id = o.partner_account_id
   where o.status <> 'pending_deposit'
     and (o.buyer_user_id = (select auth.uid()) or private.owns_partner(o.partner_account_id))
   order by o.created_at desc;
$$;
revoke all on function public.my_orders() from public, anon;
grant execute on function public.my_orders() to authenticated;

-- ---------------------------------------------------------------------------
-- Adoption
-- ---------------------------------------------------------------------------
create function public.apply_to_adopt(p_listing uuid, p_answers jsonb) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  l public.listings;
  a public.partner_accounts;
  pet_name text;
  why text := btrim(coalesce(p_answers ->> 'why', ''));
  id uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into l from public.listings where listings.id = p_listing and kind = 'adoption' and status = 'live';
  if not found then
    raise exception 'This pet is no longer open for adoption' using errcode = 'P0001';
  end if;
  select * into a from public.partner_accounts where partner_accounts.id = l.partner_account_id and status = 'approved';
  if not found then
    raise exception 'This shelter is not taking applications' using errcode = '22023';
  end if;
  if a.owner_user_id = me then
    raise exception 'You cannot apply to your own listing' using errcode = '22023';
  end if;
  if private.is_blocked_between(a.owner_user_id, me) then
    raise exception 'Listing not found' using errcode = 'P0002';
  end if;
  if coalesce(p_answers ->> 'home_type', '') not in ('house', 'flat', 'other') then
    raise exception 'Tell us about your home' using errcode = '22023';
  end if;
  if char_length(why) < 10 then
    raise exception 'Tell the shelter a little about why you want to adopt (at least 10 characters)' using errcode = '22023';
  end if;
  if char_length(why) > 600 or char_length(coalesce(p_answers ->> 'daytime', '')) > 200
     or char_length(coalesce(p_answers ->> 'other_pets', '')) > 300 then
    raise exception 'One of your answers is too long' using errcode = '22023';
  end if;
  if coalesce((p_answers ->> 'agree_visit')::boolean, false) is not true then
    raise exception 'The shelter needs your agreement to a short home visit or video call' using errcode = '22023';
  end if;
  if exists (select 1 from public.adoption_applications x where x.listing_id = p_listing and x.applicant_user_id = me) then
    raise exception 'You have already applied for this pet' using errcode = 'P0001';
  end if;

  insert into public.adoption_applications (listing_id, applicant_user_id, answers)
  values (p_listing, me, jsonb_build_object(
    'home_type', p_answers ->> 'home_type',
    'other_pets', nullif(btrim(coalesce(p_answers ->> 'other_pets', '')), ''),
    'daytime', nullif(btrim(coalesce(p_answers ->> 'daytime', '')), ''),
    'why', why,
    'agree_visit', true))
  returning adoption_applications.id into id;

  select name into pet_name from public.pets where pets.id = l.pet_id;
  perform private.notify(a.owner_user_id, 'booking', 'New application for ' || pet_name,
    'Someone applied to adopt ' || pet_name || '. Review it and arrange a home visit.', '/applications/' || id, 'application:' || id);
  return id;
end;
$$;
revoke all on function public.apply_to_adopt(uuid, jsonb) from public, anon;
grant execute on function public.apply_to_adopt(uuid, jsonb) to authenticated;

create function public.my_applications()
returns table (application_id uuid, listing_id uuid, status text, pet_name text, partner_name text, created_at timestamptz, transfer_id uuid)
language sql stable security definer
set search_path = ''
as $$
  select x.id, x.listing_id, x.status, p.name, a.business_name, x.created_at,
         (select t.id from public.ownership_transfers t where t.application_id = x.id and t.completed_at is null limit 1)
    from public.adoption_applications x
    join public.listings l on l.id = x.listing_id
    join public.pets p on p.id = l.pet_id
    join public.partner_accounts a on a.id = l.partner_account_id
   where x.applicant_user_id = (select auth.uid())
   order by x.created_at desc;
$$;
revoke all on function public.my_applications() from public, anon;
grant execute on function public.my_applications() to authenticated;

-- The shelter hands over an approved adopter's pet. Free; the adopter then accepts the passport.
create function public.shelter_complete_adoption(p_application uuid) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  x public.adoption_applications;
  l public.listings;
  transfer uuid;
  pet_name text;
begin
  select * into x from public.adoption_applications where id = p_application for update;
  if not found then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  select * into l from public.listings where id = x.listing_id for update;
  if not private.owns_partner(l.partner_account_id) then
    raise exception 'Application not found' using errcode = '42501';
  end if;
  if x.status <> 'approved' then
    raise exception 'Approve the application before handing over' using errcode = 'P0001';
  end if;
  if l.status not in ('live', 'reserved') then
    raise exception 'This pet has already been handed over' using errcode = 'P0001';
  end if;
  update public.listings set status = 'adopted' where id = l.id;
  update public.adoption_applications set status = 'declined'
   where listing_id = l.id and id <> x.id and status in ('submitted', 'home_visit');
  insert into public.ownership_transfers (pet_id, from_user_id, from_partner_id, to_user_id, kind, application_id, handover_confirmed_at)
  select l.pet_id, p.owner_user_id, l.partner_account_id, x.applicant_user_id, 'adoption', x.id, now()
    from public.pets p where p.id = l.pet_id
  returning id into transfer;
  select name into pet_name from public.pets where id = l.pet_id;
  perform private.notify(x.applicant_user_id, 'booking', pet_name || ' is coming home',
    'The shelter confirmed the handover. Accept ' || pet_name || '''s passport.', '/transfer/' || transfer, 'adoption-handover:' || x.id);
  return transfer;
end;
$$;
revoke all on function public.shelter_complete_adoption(uuid) from public, anon;
grant execute on function public.shelter_complete_adoption(uuid) to authenticated;

-- What an adopter sees of a transfer (adoptions have no order).
create function public.transfer_detail(p_transfer uuid) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  t public.ownership_transfers;
  p public.pets;
  a public.partner_accounts;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into t from public.ownership_transfers where id = p_transfer and (to_user_id = me or from_user_id = me);
  if not found then
    raise exception 'Transfer not found' using errcode = 'P0002';
  end if;
  select * into p from public.pets where id = t.pet_id;
  select * into a from public.partner_accounts where id = t.from_partner_id;
  return jsonb_build_object(
    'transfer_id', t.id,
    'kind', t.kind,
    'pet_id', p.id,
    'pet_name', p.name,
    'species', p.species,
    'breed', p.breed,
    'partner_name', a.business_name,
    'handover_confirmed_at', t.handover_confirmed_at,
    'completed_at', t.completed_at,
    'is_receiver', t.to_user_id = me,
    'records', (select count(*) from public.health_records r where r.pet_id = p.id),
    'verified_records', (select count(*) from public.health_records r where r.pet_id = p.id and r.verified_by_partner_id is not null),
    'order_id', t.order_id
  );
end;
$$;
revoke all on function public.transfer_detail(uuid) from public, anon;
grant execute on function public.transfer_detail(uuid) to authenticated;

-- Payout sending (milestone 7): the weekly payout run is prepared on a schedule, reviewed and approved by staff,
-- and then sent to partners' bank accounts by the payout-run edge function.
--
-- The order of things matters for safety:
--   1. A run lists, per partner, exactly which escrow rows it will pay (payout_item_escrows).
--   2. When the function claims an item it first moves those escrows to "released" (money that is still ready or
--      a split's remainder). From then on a dispute can no longer pause them, and the amount is fixed.
--   3. Only then does it ask Paystack for the transfer. A failed transfer is retried (the same reference is reused, so
--      Paystack never pays twice); after three failures staff see it in the console.

-- ---------------------------------------------------------------------------
-- Columns and links
-- ---------------------------------------------------------------------------
alter table public.payout_items drop constraint payout_items_status_check;
alter table public.payout_items
  add constraint payout_items_status_check
    check (status in ('pending', 'held', 'sending', 'sent', 'failed')),
  add column note text,
  add column attempts integer not null default 0,
  add column attempted_at timestamptz,
  add column sent_at timestamptz;

-- The escrow rows an item pays. Filled when the run is prepared.
create table public.payout_item_escrows (
  payout_item_id uuid not null references public.payout_items (id) on delete cascade,
  escrow_id uuid not null references public.escrow_transactions (id),
  primary key (payout_item_id, escrow_id)
);
create index on public.payout_item_escrows (escrow_id);
alter table public.payout_item_escrows enable row level security;
create policy "finance staff read payout links" on public.payout_item_escrows
  for select to authenticated
  using (private.is_staff(array['payouts_disputes', 'read_only']));
revoke all on public.payout_item_escrows from anon, authenticated;
grant select on public.payout_item_escrows to authenticated;

-- Paystack's recipient for the partner's bank account, made on the first transfer and reused.
alter table public.partner_payout_accounts add column paystack_recipient_code text;

-- ---------------------------------------------------------------------------
-- Preparing a run (shared by the console button and the weekly schedule)
-- ---------------------------------------------------------------------------
-- What the partner receives from an escrow row: ready money net of the fee, or what is left of a split
-- after the refund (with the fee shared in proportion). Zero for anything else.
create function private.escrow_net(e public.escrow_transactions) returns bigint
language sql immutable
set search_path = ''
as $$
  select case
    when e.status = 'ready' then e.amount_kobo - e.fee_kobo
    when e.status = 'partially_refunded' and e.paid_out_at is null then
      (e.amount_kobo - e.refund_kobo)
        - round(e.fee_kobo * (e.amount_kobo - e.refund_kobo)::numeric / e.amount_kobo)::bigint
    else 0
  end;
$$;
revoke all on function private.escrow_net(public.escrow_transactions) from public, anon, authenticated;

create function private.prepare_payout_run(p_run_on date) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_run uuid;
  v_status text;
  v_total bigint;
begin
  select id, status into v_run, v_status from public.payout_runs where run_on = p_run_on for update;
  if v_run is not null and v_status <> 'draft' then
    raise exception 'The payout run for this date has already been %', v_status using errcode = 'P0001';
  end if;
  if v_run is null then
    insert into public.payout_runs (run_on) values (p_run_on) returning id into v_run;
  else
    delete from public.payout_items where payout_run_id = v_run;
  end if;

  -- One item per partner with something to pay. Money already promised to another approved run is left out.
  insert into public.payout_items (payout_run_id, partner_account_id, amount_kobo, status, note)
  select v_run, x.payee_partner_id, sum(x.net),
         case when exists (select 1 from public.partner_payout_accounts a where a.partner_account_id = x.payee_partner_id)
              then 'pending' else 'held' end,
         case when exists (select 1 from public.partner_payout_accounts a where a.partner_account_id = x.payee_partner_id)
              then null else 'No payout account on file. Ask the partner to add one.' end
    from (
      select e.payee_partner_id, private.escrow_net(e) as net
        from public.escrow_transactions e
       where e.status in ('ready', 'partially_refunded')
         and not exists (
           select 1 from public.payout_item_escrows l
             join public.payout_items i on i.id = l.payout_item_id
             join public.payout_runs r on r.id = i.payout_run_id
            where l.escrow_id = e.id and r.id <> v_run and r.status = 'approved')
    ) x
   where x.net > 0
   group by x.payee_partner_id;

  insert into public.payout_item_escrows (payout_item_id, escrow_id)
  select i.id, e.id
    from public.payout_items i
    join public.escrow_transactions e on e.payee_partner_id = i.partner_account_id
   where i.payout_run_id = v_run
     and private.escrow_net(e) > 0
     and not exists (
       select 1 from public.payout_item_escrows l
         join public.payout_items i2 on i2.id = l.payout_item_id
         join public.payout_runs r on r.id = i2.payout_run_id
        where l.escrow_id = e.id and r.id <> v_run and r.status = 'approved');

  select coalesce(sum(amount_kobo), 0) into v_total from public.payout_items where payout_run_id = v_run;
  update public.payout_runs set total_kobo = v_total where id = v_run;
  return v_run;
end;
$$;
revoke all on function private.prepare_payout_run(date) from public, anon, authenticated;

create or replace function public.admin_prepare_payout_run(p_run_on date) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_run uuid;
  v_total bigint;
begin
  perform private.require_staff(array['payouts_disputes']);
  v_run := private.prepare_payout_run(p_run_on);
  select total_kobo into v_total from public.payout_runs where id = v_run;
  perform private.write_audit('payout_run.prepare', 'payout_run', v_run,
    jsonb_build_object('run_on', p_run_on, 'total_kobo', v_total));
  return v_run;
end;
$$;

-- Run by the schedule: makes (or refreshes) the draft for the next payout day so staff find it ready to review.
-- A run that has been approved is never touched.
create function public.schedule_payout_run() returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Africa/Lagos')::date;
  wd integer;
  v_on date;
  v_status text;
begin
  select payout_weekday into wd from public.settings limit 1;
  wd := coalesce(wd, 1);
  v_on := today + ((wd - extract(isodow from today)::integer + 7) % 7);
  select status into v_status from public.payout_runs where run_on = v_on;
  if v_status is not null and v_status <> 'draft' then
    return null;
  end if;
  return private.prepare_payout_run(v_on);
end;
$$;
revoke all on function public.schedule_payout_run() from public, anon, authenticated;
grant execute on function public.schedule_payout_run() to service_role;

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------
-- Takes the next items of approved runs that are due. Pending items release their escrows first (see the top of this
-- file); failed items (under three attempts) and items stuck in "sending" are handed out again with the same amount.
create function public.claim_payout_items(p_limit integer default 20)
returns table (
  item_id uuid,
  partner_id uuid,
  amount_kobo bigint,
  bank_code text,
  account_number text,
  account_name text,
  recipient_code text,
  attempts integer
)
language plpgsql security definer
set search_path = ''
as $$
declare
  it public.payout_items;
  acct public.partner_payout_accounts;
  released bigint;
  today date := (now() at time zone 'Africa/Lagos')::date;
  n integer := 0;
begin
  for it in
    select i.* from public.payout_items i
      join public.payout_runs r on r.id = i.payout_run_id
     where r.status = 'approved' and r.run_on <= today
       and (i.status = 'pending'
            or (i.status = 'failed' and i.attempts < 3)
            or (i.status = 'sending' and i.attempted_at < now() - interval '15 minutes' and i.attempts < 3))
     order by r.run_on, i.created_at
     limit least(greatest(p_limit, 1), 100)
     for update of i skip locked
  loop
    select * into acct from public.partner_payout_accounts where partner_account_id = it.partner_account_id;
    if not found then
      update public.payout_items set status = 'held', note = 'No payout account on file. Ask the partner to add one.'
       where id = it.id;
      continue;
    end if;

    if it.status = 'pending' then
      -- Lock the rows, work out what is still payable (a dispute may have paused some since the run was prepared),
      -- then commit it: nothing can pause the money after this point.
      perform 1 from public.escrow_transactions e
       where e.id in (select l.escrow_id from public.payout_item_escrows l where l.payout_item_id = it.id)
       for update;
      select coalesce(sum(private.escrow_net(e)), 0) into released
        from public.escrow_transactions e
       where e.id in (select l.escrow_id from public.payout_item_escrows l where l.payout_item_id = it.id);
      update public.escrow_transactions e
         set status = case when e.status = 'ready' then 'released' else e.status end,
             paid_out_at = coalesce(e.paid_out_at, now())
       where e.id in (select l.escrow_id from public.payout_item_escrows l where l.payout_item_id = it.id)
         and private.escrow_net(e) > 0;
      if released <= 0 then
        update public.payout_items set status = 'held', note = 'Nothing was ready to pay any more.' where id = it.id;
        continue;
      end if;
      update public.payout_items set amount_kobo = least(it.amount_kobo, released) where id = it.id;
      it.amount_kobo := least(it.amount_kobo, released);
    end if;

    update public.payout_items pi
       set status = 'sending', attempts = pi.attempts + 1, attempted_at = now(), note = null
     where pi.id = it.id;

    item_id := it.id;
    partner_id := it.partner_account_id;
    amount_kobo := it.amount_kobo;
    bank_code := acct.bank_code;
    account_number := acct.account_number;
    account_name := acct.account_name;
    recipient_code := acct.paystack_recipient_code;
    attempts := it.attempts + 1;
    n := n + 1;
    return next;
  end loop;
  if n > 0 then
    perform private.refresh_payout_runs();
  end if;
end;
$$;
revoke all on function public.claim_payout_items(integer) from public, anon, authenticated;
grant execute on function public.claim_payout_items(integer) to service_role;

-- A run is "sent" when nothing is left to do, "failed" when something has run out of attempts.
create function private.refresh_payout_runs() returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.payout_runs r
     set status = case
           when exists (select 1 from public.payout_items i
                         where i.payout_run_id = r.id and i.status = 'failed' and i.attempts >= 3) then 'failed'
           else 'sent' end,
         total_kobo = (select coalesce(sum(i.amount_kobo), 0) from public.payout_items i
                        where i.payout_run_id = r.id and i.status in ('sent', 'sending', 'failed', 'pending'))
   where r.status = 'approved'
     and not exists (select 1 from public.payout_items i
                      where i.payout_run_id = r.id
                        and (i.status in ('pending', 'sending') or (i.status = 'failed' and i.attempts < 3)));
end;
$$;
revoke all on function private.refresh_payout_runs() from public, anon, authenticated;

create function public.finish_payout_item(
  p_item uuid,
  p_ok boolean,
  p_transfer_code text default null,
  p_error text default null,
  p_recipient_code text default null
) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  it public.payout_items;
  owner uuid;
begin
  select * into it from public.payout_items where id = p_item for update;
  if not found or it.status <> 'sending' then
    return;
  end if;
  if p_recipient_code is not null then
    update public.partner_payout_accounts set paystack_recipient_code = p_recipient_code
     where partner_account_id = it.partner_account_id;
  end if;
  if p_ok then
    update public.payout_items
       set status = 'sent', sent_at = now(), paystack_transfer_code = p_transfer_code, note = left(p_error, 300)
     where id = p_item;
    select a.owner_user_id into owner from public.partner_accounts a where a.id = it.partner_account_id;
    perform private.notify(owner, 'booking', 'Your payout is on its way',
      'We sent ' || to_char(it.amount_kobo / 100.0, 'FM999,999,999,990') || ' naira to your bank account.',
      '/partner/money', 'payout-sent:' || p_item);
  else
    update public.payout_items
       set status = 'failed', note = left(coalesce(p_error, 'The transfer failed'), 300)
     where id = p_item;
  end if;
  perform private.refresh_payout_runs();
end;
$$;
revoke all on function public.finish_payout_item(uuid, boolean, text, text, text) from public, anon, authenticated;
grant execute on function public.finish_payout_item(uuid, boolean, text, text, text) to service_role;

-- Paystack says a transfer it accepted has failed or was reversed. The money is back in the PawPass balance; staff
-- sort it out from the console, so the item is marked and no more attempts are made.
create function public.mark_transfer_failed(p_transfer_code text, p_reason text default null) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.payout_items
     set status = 'failed', attempts = 3, note = left('Paystack reported: ' || coalesce(p_reason, 'transfer failed'), 300)
   where paystack_transfer_code = p_transfer_code and status = 'sent';
  perform private.refresh_payout_runs();
end;
$$;
revoke all on function public.mark_transfer_failed(text, text) from public, anon, authenticated;
grant execute on function public.mark_transfer_failed(text, text) to service_role;

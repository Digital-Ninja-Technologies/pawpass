-- Fix: the readable reasons were added with `||`, which makes Postgres read the text as an array literal
-- ("malformed array literal") whenever something blocked a deletion. array_append adds the text as one item.
-- Replaces one function; safe to run more than once.

create or replace function private.deletion_blockers(p_user uuid) returns text[]
language plpgsql stable security definer
set search_path = ''
as $$
declare
  out text[] := '{}';
  pids uuid[];
begin
  if exists (select 1 from public.staff_members s where s.user_id = p_user) then
    out := array_append(out, 'You are on the PawPass team. Ask an admin to remove your access first.');
  end if;

  if exists (select 1 from public.bookings b
              where b.owner_user_id = p_user and b.status in ('confirmed', 'completed_awaiting_owner', 'disputed')) then
    out := array_append(out, 'You have a booking that is not finished. Confirm the visit or cancel it first.');
  end if;
  if exists (select 1 from public.puppy_orders o
              where o.buyer_user_id = p_user and o.status in ('deposit_paid', 'balance_paid', 'handed_over', 'disputed')) then
    out := array_append(out, 'You have a puppy purchase that is not finished. Wait until it is complete first.');
  end if;
  if exists (select 1 from public.escrow_transactions e
              where e.payer_user_id = p_user and e.status in ('held', 'ready', 'paused')) then
    out := array_append(out, 'Some of your payments are still held. They are released or refunded once the visit or sale is settled.');
  end if;
  if exists (select 1 from public.disputes d
              where d.opened_by_user_id = p_user and d.status <> 'decided') then
    out := array_append(out, 'You have a problem report that has not been decided yet.');
  end if;
  if exists (select 1 from public.ownership_transfers t
              where t.completed_at is null and (t.from_user_id = p_user or t.to_user_id = p_user)) then
    out := array_append(out, 'A pet passport transfer is still waiting to be finished.');
  end if;

  select array_agg(a.id) into pids from public.partner_accounts a where a.owner_user_id = p_user;
  if pids is not null then
    if exists (select 1 from public.escrow_transactions e
                where e.payee_partner_id = any(pids)
                  and (e.status in ('held', 'ready', 'paused') or (e.status = 'released' and e.paid_out_at is null))) then
      out := array_append(out, 'Your business is still owed money. Wait for the next payout, then try again.');
    end if;
    if exists (select 1 from public.bookings b
                where b.partner_account_id = any(pids) and b.status in ('confirmed', 'completed_awaiting_owner', 'disputed')) then
      out := array_append(out, 'Your business has bookings that are not finished.');
    end if;
    if exists (select 1 from public.puppy_orders o
                where o.partner_account_id = any(pids) and o.status in ('deposit_paid', 'balance_paid', 'handed_over', 'disputed')) then
      out := array_append(out, 'Your business has pet sales that are not finished.');
    end if;
  end if;
  return out;
end;
$$;
revoke all on function private.deletion_blockers(uuid) from public, anon, authenticated;

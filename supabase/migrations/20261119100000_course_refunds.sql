-- Refunding a course purchase.
--
-- Staff with the Payouts & disputes role (and full admins) refund a paid purchase from the admin console, with a reason.
-- The buyer loses the course at once (access needs a purchase that is 'paid'), and the money goes back to them on
-- Paystack through the same scheduled job that sends other refunds: it claims queued refunds, sends them, and says how
-- each went (a failure is retried, and shows in the console after five tries). A refund is always the full amount.
-- A refunded person can buy the course again. Every step is written to the audit log.

alter table public.course_purchases drop constraint course_purchases_status_check;
alter table public.course_purchases
  add constraint course_purchases_status_check
  check (status in ('pending_payment', 'paid', 'refund_queued', 'refunded'));

alter table public.course_purchases
  add column refund_reason text check (refund_reason is null or char_length(refund_reason) <= 300),
  add column refund_requested_at timestamptz,
  add column refund_requested_by uuid references public.staff_members (id) on delete set null,
  add column refund_claimed_at timestamptz,
  add column refund_attempts integer not null default 0,
  add column refund_error text,
  add column refunded_at timestamptz,
  add column refund_reference text;

create index on public.course_purchases (refund_requested_at) where status = 'refund_queued';

-- A late or repeated "payment succeeded" message from Paystack must never give the course back after a refund.
create or replace function public.confirm_course_payment(p_reference text, p_amount_kobo bigint) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare p public.course_purchases;
begin
  select * into p from public.course_purchases where paystack_reference = p_reference for update;
  if not found then
    raise exception 'Purchase not found' using errcode = 'P0002';
  end if;
  if p.status = 'paid' then
    return jsonb_build_object('result', 'already_paid', 'order_id', p.id, 'order_status', p.status);
  end if;
  if p.status in ('refund_queued', 'refunded') then
    return jsonb_build_object('result', 'refunded', 'order_id', p.id, 'order_status', p.status);
  end if;
  if p_amount_kobo <> p.amount_kobo then
    raise exception 'The amount paid does not match this purchase' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.course_purchases x
              where x.user_id = p.user_id and x.course_id = p.course_id and x.status = 'paid' and x.id <> p.id) then
    update public.course_purchases set status = 'paid', paid_at = now(), course_id = null where id = p.id;
    return jsonb_build_object('result', 'paid', 'order_id', p.id, 'order_status', 'paid');
  end if;
  update public.course_purchases set status = 'paid', paid_at = now() where id = p.id;
  return jsonb_build_object('result', 'paid', 'order_id', p.id, 'order_status', 'paid');
end;
$$;

-- ---------------------------------------------------------------------------
-- Staff: see who bought a course, refund a purchase, try a stuck refund again
-- ---------------------------------------------------------------------------
create function public.admin_course_purchases(p_course uuid)
returns table (
  id uuid, buyer_name text, amount_kobo bigint, status text, paid_at timestamptz, created_at timestamptz,
  refund_reason text, refund_requested_at timestamptz, refunded_at timestamptz, refund_error text, refund_attempts integer
)
language plpgsql stable security definer
set search_path = ''
as $$
begin
  perform private.require_staff(array['payouts_disputes', 'read_only']);
  return query
  select p.id,
         coalesce(nullif(btrim(pr.first_name || ' ' || coalesce(left(pr.last_name, 1), '') ||
                                case when pr.last_name <> '' then '.' else '' end), ''), 'Deleted user'),
         p.amount_kobo, p.status, p.paid_at, p.created_at,
         p.refund_reason, p.refund_requested_at, p.refunded_at, p.refund_error, p.refund_attempts
    from public.course_purchases p
    left join public.profiles pr on pr.user_id = p.user_id
   where p.course_id = p_course and p.status <> 'pending_payment'
   order by coalesce(p.paid_at, p.created_at) desc
   limit 200;
end;
$$;

create function public.admin_refund_course_purchase(p_purchase uuid, p_reason text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_staff uuid;
  v_reason text := btrim(coalesce(p_reason, ''));
  p public.course_purchases;
begin
  v_staff := private.require_staff(array['payouts_disputes']);
  if char_length(v_reason) not between 3 and 300 then
    raise exception 'Give a reason of 3 to 300 characters' using errcode = '22023';
  end if;
  select * into p from public.course_purchases where id = p_purchase for update;
  if not found then
    raise exception 'Purchase not found' using errcode = 'P0002';
  end if;
  if p.status in ('refund_queued', 'refunded') then
    raise exception 'This purchase has already been refunded' using errcode = 'P0001';
  end if;
  if p.status <> 'paid' then
    raise exception 'Only a paid purchase can be refunded' using errcode = 'P0001';
  end if;
  update public.course_purchases
     set status = 'refund_queued', refund_reason = v_reason, refund_requested_at = now(), refund_requested_by = v_staff,
         refund_claimed_at = null, refund_attempts = 0, refund_error = null
   where id = p.id;
  perform private.write_audit('course.refund', 'course_purchase', p.id,
    jsonb_build_object('course', p.course_title, 'amount_kobo', p.amount_kobo, 'reason', v_reason));
end;
$$;

-- A refund Paystack kept refusing (shown as needing attention after five tries) can be sent again once the cause is fixed.
create function public.admin_retry_course_refund(p_purchase uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare p public.course_purchases;
begin
  perform private.require_staff(array['payouts_disputes']);
  select * into p from public.course_purchases where id = p_purchase for update;
  if not found then
    raise exception 'Purchase not found' using errcode = 'P0002';
  end if;
  if p.status <> 'refund_queued' then
    raise exception 'There is no refund waiting for this purchase' using errcode = 'P0001';
  end if;
  update public.course_purchases set refund_attempts = 0, refund_claimed_at = null where id = p.id;
  perform private.write_audit('course.refund_retry', 'course_purchase', p.id,
    jsonb_build_object('course', p.course_title, 'amount_kobo', p.amount_kobo));
end;
$$;

-- ---------------------------------------------------------------------------
-- The scheduled job: claim what is queued, send it to Paystack, say how it went.
-- ---------------------------------------------------------------------------
create function public.claim_course_refunds(p_limit integer default 20)
returns table (purchase_id uuid, paystack_reference text, refund_kobo bigint)
language plpgsql security definer
set search_path = ''
as $$
begin
  return query
  with picked as (
    select p.id from public.course_purchases p
     where p.status = 'refund_queued'
       and p.refund_attempts < 5
       and (p.refund_claimed_at is null or p.refund_claimed_at < now() - interval '15 minutes')
     order by p.refund_requested_at
     limit greatest(coalesce(p_limit, 20), 1)
       for update skip locked
  )
  update public.course_purchases p
     set refund_claimed_at = now(), refund_attempts = p.refund_attempts + 1
    from picked
   where p.id = picked.id
  returning p.id, p.paystack_reference, p.amount_kobo;
end;
$$;

create function public.finish_course_refund(p_purchase uuid, p_ok boolean, p_refund_reference text, p_error text)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if p_ok then
    update public.course_purchases
       set status = 'refunded', refunded_at = now(), refund_reference = p_refund_reference, refund_error = null
     where id = p_purchase and status = 'refund_queued';
    if found then
      perform private.write_audit('course.refunded', 'course_purchase', p_purchase,
        jsonb_build_object('refund_reference', p_refund_reference));
    end if;
  else
    update public.course_purchases
       set refund_claimed_at = null, refund_error = left(coalesce(p_error, 'Paystack refused the refund'), 300)
     where id = p_purchase and status = 'refund_queued';
  end if;
end;
$$;

revoke all on function public.admin_course_purchases(uuid), public.admin_refund_course_purchase(uuid, text),
  public.admin_retry_course_refund(uuid) from public, anon;
grant execute on function public.admin_course_purchases(uuid), public.admin_refund_course_purchase(uuid, text),
  public.admin_retry_course_refund(uuid) to authenticated;
revoke all on function public.claim_course_refunds(integer), public.finish_course_refund(uuid, boolean, text, text)
  from public, anon, authenticated;
grant execute on function public.claim_course_refunds(integer), public.finish_course_refund(uuid, boolean, text, text)
  to service_role;
revoke all on function public.confirm_course_payment(text, bigint) from public, anon, authenticated;
grant execute on function public.confirm_course_payment(text, bigint) to service_role;

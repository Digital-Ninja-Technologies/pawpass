-- Dashboard numbers for the admin Overview. SECURITY INVOKER: every figure respects the
-- caller's row level security, so a role that cannot read escrow sees zeros there.
create function public.admin_overview(p_days integer default 30) returns jsonb
language sql stable security invoker
set search_path = ''
as $$
  with w as (
    select now() - make_interval(days => p_days) as since,
           now() - make_interval(days => 2 * p_days) as prev_since
  ),
  weeks as (
    select g::date as week_start
      from generate_series(date_trunc('week', now())::date - 77, date_trunc('week', now())::date, interval '7 days') g
  )
  select jsonb_build_object(
    'active_pets', (select count(*) from public.pets),
    'bookings_completed', (select count(*) from public.bookings b, w where b.status = 'completed' and b.starts_at >= w.since),
    'bookings_completed_prev', (select count(*) from public.bookings b, w
                                 where b.status = 'completed' and b.starts_at >= w.prev_since and b.starts_at < w.since),
    'payments_kobo', (select coalesce(sum(e.amount_kobo), 0) from public.escrow_transactions e, w
                       where e.created_at >= w.since and e.status <> 'refunded'),
    'payments_prev_kobo', (select coalesce(sum(e.amount_kobo), 0) from public.escrow_transactions e, w
                            where e.created_at >= w.prev_since and e.created_at < w.since and e.status <> 'refunded'),
    'held_kobo', (select coalesce(sum(amount_kobo), 0) from public.escrow_transactions where status in ('held', 'paused')),
    'held_count', (select count(*) from public.escrow_transactions where status in ('held', 'paused')),
    'ready_kobo', (select coalesce(sum(amount_kobo - fee_kobo), 0) from public.escrow_transactions where status = 'ready'),
    'ready_partners', (select count(distinct payee_partner_id) from public.escrow_transactions where status = 'ready'),
    'paused_kobo', (select coalesce(sum(amount_kobo), 0) from public.escrow_transactions where status = 'paused'),
    'paused_count', (select count(*) from public.escrow_transactions where status = 'paused'),
    'partners', (select coalesce(jsonb_object_agg(type, n), '{}'::jsonb)
                   from (select type, count(*) as n from public.partner_accounts where status = 'approved' group by type) t),
    'weekly', (select jsonb_agg(jsonb_build_object(
                  'week_start', wk.week_start,
                  'count', (select count(*) from public.bookings b
                             where b.status = 'completed' and b.starts_at >= wk.week_start and b.starts_at < wk.week_start + 7))
                  order by wk.week_start)
                 from weeks wk),
    'kyc_waiting', (select count(*) from public.partner_accounts where status = 'submitted'),
    'kyc_oldest', (select min(submitted_at) from public.partner_accounts where status = 'submitted'),
    'disputes_open', (select count(*) from public.disputes where status <> 'decided'),
    'disputes_open_kobo', (select coalesce(sum(e.amount_kobo), 0) from public.disputes d
                             join public.escrow_transactions e on e.id = d.escrow_transaction_id where d.status <> 'decided'),
    'disputes_due_today', (select count(*) from public.disputes where status <> 'decided' and due_at < now() + interval '1 day'),
    'reports_open', (select count(*) from (select 1 from public.reports where status = 'open' group by target_type, target_id) r)
  );
$$;

revoke all on function public.admin_overview(integer) from public, anon;
grant execute on function public.admin_overview(integer) to authenticated;

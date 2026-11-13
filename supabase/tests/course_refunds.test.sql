-- Course refunds: who may refund, what a refund does (access goes, money is queued and sent), retries,
-- a late "paid" message from Paystack, buying again, sales figures and the audit trail.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/course_refunds.test.sql
-- Needs seed.sql and migrations 20261118100000 and 20261119100000. Runs in one transaction that is rolled back.
-- Prints "Course refund tests passed" on success.

\set QUIET on
\set tolu    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set kemi    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set admin   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set finance 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f1'', true); end $$; set local role authenticated;'
\set support 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f2'', true); end $$; set local role authenticated;'
\set viewer  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f4'', true); end $$; set local role authenticated;'
\set anon    'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server  'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated;
create function test_helpers.state(q text) returns text
language plpgsql as $$
begin
  execute q;
  return 'ok';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated;

:server
insert into auth.users (id, email, aud, role, email_confirmed_at, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-0000000000f1', 'finance@pawpass.example', 'authenticated', 'authenticated', now(), '{"first_name":"Tunde","last_name":"K"}'),
  ('a0000000-0000-0000-0000-0000000000f2', 'support@pawpass.example', 'authenticated', 'authenticated', now(), '{"first_name":"Halima","last_name":"S"}'),
  ('a0000000-0000-0000-0000-0000000000f4', 'viewer@pawpass.example',  'authenticated', 'authenticated', now(), '{"first_name":"Read","last_name":"Only"}');
insert into public.staff_members (user_id, role) values
  ('a0000000-0000-0000-0000-0000000000f1', 'payouts_disputes'),
  ('a0000000-0000-0000-0000-0000000000f2', 'support_reports'),
  ('a0000000-0000-0000-0000-0000000000f4', 'read_only');

-- The paid starter course goes live, and Tolu and Kemi buy it.
:admin
do $$
begin
  perform public.admin_set_course_status((select id from public.courses where slug = 'first-year'), 'published');
  perform set_config('test.fy', (select id::text from public.courses where slug = 'first-year'), true);
  perform set_config('test.fy2', (select l.id::text from public.course_lessons l join public.courses c on c.id = l.course_id where c.slug = 'first-year' and l.position = 2), true);
end $$;
:tolu
do $$ begin perform set_config('test.tolu_ref', public.create_course_purchase(current_setting('test.fy')::uuid) ->> 'reference', true); end $$;
:kemi
do $$ begin perform set_config('test.kemi_ref', public.create_course_purchase(current_setting('test.fy')::uuid) ->> 'reference', true); end $$;
:server
do $$
begin
  perform public.confirm_course_payment(current_setting('test.tolu_ref'), 250000);
  perform public.confirm_course_payment(current_setting('test.kemi_ref'), 250000);
  perform set_config('test.tolu_p', (select id::text from public.course_purchases where paystack_reference = current_setting('test.tolu_ref')), true);
  perform set_config('test.kemi_p', (select id::text from public.course_purchases where paystack_reference = current_setting('test.kemi_ref')), true);
end $$;

-- ---------------------------------------------------------------------------
-- Who may refund
-- ---------------------------------------------------------------------------
:tolu
do $$
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = current_setting('test.fy')::uuid) = 6, 'Tolu has the whole course';
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, 'I want my money back') $q$, current_setting('test.tolu_p'))) = '42501', 'a buyer cannot refund themselves';
  assert test_helpers.state(format($q$ select public.admin_course_purchases(%L) $q$, current_setting('test.fy'))) = '42501', 'or list buyers';
  assert test_helpers.state($q$ select public.claim_course_refunds(5) $q$) = '42501', 'or run the refund job';
  assert test_helpers.state(format($q$ select public.finish_course_refund(%L, true, 'x', null) $q$, current_setting('test.tolu_p'))) = '42501', 'or say a refund went through';
  assert test_helpers.state(format($q$ update public.course_purchases set status = 'refunded' where id = %L $q$, current_setting('test.tolu_p'))) = '42501', 'or edit a purchase';
end $$;
:anon
do $$
begin
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, 'No access') $q$, current_setting('test.tolu_p'))) = '42501', 'signed out people cannot refund';
end $$;
:support
do $$
begin
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, 'Not my job') $q$, current_setting('test.tolu_p'))) = '42501', 'support cannot refund';
  assert test_helpers.state(format($q$ select public.admin_course_purchases(%L) $q$, current_setting('test.fy'))) = '42501', 'or see who bought';
end $$;
:viewer
do $$
begin
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, 'Read only') $q$, current_setting('test.tolu_p'))) = '42501', 'read only cannot refund';
  assert (select count(*) from public.admin_course_purchases(current_setting('test.fy')::uuid)) = 2, 'but can see the buyers';
  assert (select buyer_name from public.admin_course_purchases(current_setting('test.fy')::uuid) where id = current_setting('test.tolu_p')::uuid) = 'Tolu A.', 'by first name and last initial only';
  assert (select count(*) from public.admin_course_purchases(current_setting('test.fy')::uuid) where status = 'paid') = 2, 'with their status';
end $$;

-- ---------------------------------------------------------------------------
-- Refunding
-- ---------------------------------------------------------------------------
:finance
do $$
declare
  p uuid := current_setting('test.tolu_p')::uuid;
begin
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, '') $q$, p)) = '22023', 'a reason is needed';
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, 'ab') $q$, p)) = '22023', 'a real one';
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, %L) $q$, p, repeat('x', 301))) = '22023', 'not too long';
  assert test_helpers.state($q$ select public.admin_refund_course_purchase('00000000-0000-0000-0000-00000000dead', 'Unknown one') $q$) = 'P0002', 'an unknown purchase is not found';

  perform public.admin_refund_course_purchase(p, 'Bought by mistake, asked within a day');
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, 'Again please') $q$, p)) = 'P0001', 'it cannot be refunded twice';
end $$;

:server
do $$
declare
  p uuid := current_setting('test.tolu_p')::uuid;
begin
  assert (select status from public.course_purchases where id = p) = 'refund_queued', 'the refund is queued';
  assert (select refund_reason from public.course_purchases where id = p) = 'Bought by mistake, asked within a day', 'with its reason';
  assert (select refund_requested_by from public.course_purchases where id = p) = (select id from public.staff_members where user_id = 'a0000000-0000-0000-0000-0000000000f1'), 'and who asked';
  assert (select details ->> 'reason' from public.audit_log where action = 'course.refund' and target_id = p) = 'Bought by mistake, asked within a day', 'the audit log has the reason';
  assert (select (details ->> 'amount_kobo')::bigint from public.audit_log where action = 'course.refund' and target_id = p) = 250000, 'and the amount';
end $$;

-- The buyer loses the course at once; the other buyer keeps theirs.
:tolu
do $$
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = current_setting('test.fy')::uuid) = 1, 'after a refund only the free preview is left';
  assert test_helpers.state(format($q$ select public.set_lesson_done(%L, true) $q$, current_setting('test.fy2'))) = 'P0001', 'a locked lesson cannot be ticked again';
  assert (select count(*) from public.course_purchases where status = 'paid') = 0, 'and the purchase no longer counts as paid';
end $$;
:kemi
do $$
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = current_setting('test.fy')::uuid) = 6, 'someone else who bought it is not affected';
end $$;

-- Sales figures only count money that stays.
:admin
do $$
begin
  assert (select buyers from public.admin_course_v where id = current_setting('test.fy')::uuid) = 1, 'sales show one buyer left';
  assert (select revenue_kobo from public.admin_course_v where id = current_setting('test.fy')::uuid) = 250000, 'and N2,500';
  assert (select status from public.admin_course_purchases(current_setting('test.fy')::uuid) where id = current_setting('test.tolu_p')::uuid) = 'refund_queued', 'the list shows the refund waiting';
end $$;

-- ---------------------------------------------------------------------------
-- A late "payment succeeded" message must not give the course back
-- ---------------------------------------------------------------------------
:server
do $$
declare
  p uuid := current_setting('test.tolu_p')::uuid;
begin
  assert public.confirm_course_payment(current_setting('test.tolu_ref'), 250000) ->> 'result' = 'refunded', 'a repeat from Paystack says refunded';
  assert (select status from public.course_purchases where id = p) = 'refund_queued', 'and changes nothing';
  assert test_helpers.state(format($q$ select public.confirm_course_payment(%L, 1) $q$, current_setting('test.tolu_ref'))) = 'ok', 'not even with a wrong amount';
end $$;

-- ---------------------------------------------------------------------------
-- The scheduled job
-- ---------------------------------------------------------------------------
do $$
declare
  p uuid := current_setting('test.tolu_p')::uuid;
  n integer;
begin
  select count(*) into n from public.claim_course_refunds(10);
  assert n = 1, 'the job claims the one queued refund';
  assert (select refund_attempts from public.course_purchases where id = p) = 1, 'and counts the try';
  select count(*) into n from public.claim_course_refunds(10);
  assert n = 0, 'a refund being sent is not claimed again';

  -- It failed: back in the queue with the reason, and claimable again.
  perform public.finish_course_refund(p, false, null, 'Paystack: insufficient balance');
  assert (select refund_error from public.course_purchases where id = p) = 'Paystack: insufficient balance', 'the failure is kept';
  assert (select status from public.course_purchases where id = p) = 'refund_queued', 'and it stays queued';
  select count(*) into n from public.claim_course_refunds(10);
  assert n = 1, 'so the next run tries again';

  -- Five tries and it needs a person; a retry from the console starts it over.
  update public.course_purchases set refund_attempts = 5, refund_claimed_at = null where id = p;
  select count(*) into n from public.claim_course_refunds(10);
  assert n = 0, 'after five tries the job stops';
end $$;

:support
do $$
begin
  assert test_helpers.state(format($q$ select public.admin_retry_course_refund(%L) $q$, current_setting('test.tolu_p'))) = '42501', 'support cannot retry';
end $$;
:finance
do $$
begin
  assert test_helpers.state(format($q$ select public.admin_retry_course_refund(%L) $q$, current_setting('test.kemi_p'))) = 'P0001', 'only a queued refund can be retried';
  perform public.admin_retry_course_refund(current_setting('test.tolu_p')::uuid);
end $$;
:server
do $$
declare
  p uuid := current_setting('test.tolu_p')::uuid;
  n integer;
  r record;
begin
  assert (select count(*) from public.audit_log where action = 'course.refund_retry' and target_id = p) = 1, 'the retry is audited';
  select * into r from public.claim_course_refunds(10);
  assert r.purchase_id = p and r.paystack_reference = current_setting('test.tolu_ref') and r.refund_kobo = 250000, 'the job gets the reference and the full amount';
  perform public.finish_course_refund(p, true, '4455', null);
  assert (select status from public.course_purchases where id = p) = 'refunded', 'once Paystack accepts it, it is refunded';
  assert (select refund_reference from public.course_purchases where id = p) = '4455', 'with Paystack''s reference';
  assert (select refunded_at from public.course_purchases where id = p) is not null, 'and the time';
  assert (select refund_error from public.course_purchases where id = p) is null, 'the old error is cleared';
  assert (select count(*) from public.audit_log where action = 'course.refunded' and target_id = p) = 1, 'it is audited';
  select count(*) into n from public.claim_course_refunds(10);
  assert n = 0, 'nothing is left to send';
  perform public.finish_course_refund(p, true, 'again', null);
  assert (select refund_reference from public.course_purchases where id = p) = '4455', 'saying it twice changes nothing';
  assert (select count(*) from public.audit_log where action = 'course.refunded' and target_id = p) = 1, 'and is not audited twice';
end $$;

:finance
do $$
begin
  assert test_helpers.state(format($q$ select public.admin_refund_course_purchase(%L, 'Once more') $q$, current_setting('test.tolu_p'))) = 'P0001', 'a refunded purchase cannot be refunded again';
  assert test_helpers.state(format($q$ select public.admin_retry_course_refund(%L) $q$, current_setting('test.tolu_p'))) = 'P0001', 'or retried';
end $$;

-- ---------------------------------------------------------------------------
-- Buying again after a refund, and deleting
-- ---------------------------------------------------------------------------
:tolu
do $$
declare
  r jsonb;
begin
  r := public.create_course_purchase(current_setting('test.fy')::uuid);
  assert r ->> 'reference' <> current_setting('test.tolu_ref'), 'after a refund Tolu can buy it again with a new payment';
  assert (select count(*) from public.course_purchases) = 2, 'both records are kept';
end $$;

:admin
do $$
begin
  assert test_helpers.state(format($q$ select public.admin_delete_course(%L) $q$, current_setting('test.fy'))) = 'P0001', 'Kemi still owns it, so it cannot be deleted';
end $$;

do $$ begin raise notice 'Course refund tests passed'; end $$;
rollback;

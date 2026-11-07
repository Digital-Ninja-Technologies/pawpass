-- Schedules the two background jobs on the hosted project. Run once in the Supabase SQL editor.
-- 1. Replace PASTE_SERVICE_ROLE_KEY_HERE with the secret key (Project Settings > API Keys). Not the publishable key.
-- 2. Run the whole script.
-- DO NOT COMMIT this file after the key is filled in.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- The key lives in Vault, not in the job text.
select vault.create_secret('PASTE_SERVICE_ROLE_KEY_HERE', 'service_role_key');

select cron.schedule('process-refunds', '*/5 * * * *', $$
  select net.http_post(
    url := 'https://ieslnhmxlfiymkqelbsl.supabase.co/functions/v1/process-refunds',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')),
    body := '{}'::jsonb)
$$);

select cron.schedule('payout-run', '0 * * * *', $$
  select net.http_post(
    url := 'https://ieslnhmxlfiymkqelbsl.supabase.co/functions/v1/payout-run',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')),
    body := '{}'::jsonb)
$$);

-- Check 1: both jobs listed and active.
select jobname, schedule, active from cron.job order by jobname;

-- Check 2 (after about 5 minutes): the runs should say 'succeeded'.
select j.jobname, d.status, d.return_message, d.start_time
  from cron.job_run_details d join cron.job j using (jobid)
 order by d.start_time desc limit 10;

-- Check 3: what the functions answered (200 is good, 401 means the key is wrong).
select id, status_code, left(content, 120) as answer, created from net._http_response order by created desc limit 10;

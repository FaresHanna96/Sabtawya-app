-- The monthly attendance report is emailed to the admins on the 1st of the month
-- (see supabase/functions/monthly-report). Same secret and URL as the weekly
-- backup, its own job.
--
-- pg_cron runs in UTC and Cairo is UTC+2 or UTC+3, so the job fires at 06:00 and
-- 07:00 UTC on the 1st and the function acts only in Cairo's 9 AM hour: the
-- report is sent once, whichever offset is in force. p_force is for trying it
-- by hand (select public.run_monthly_report(true)).

create or replace function public.run_monthly_report(p_force boolean default false)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_url    text;
  v_secret text;
  v_now    timestamp := now() at time zone 'Africa/Cairo';
begin
  if not p_force and (extract(day from v_now) <> 1 or extract(hour from v_now) <> 9) then
    return;
  end if;
  select value into v_url from public.app_config where key = 'functions_url';
  select value into v_secret from public.app_config where key = 'backup_secret';
  if v_url is null or v_secret is null then
    return; -- not configured in this environment
  end if;
  perform net.http_post(
    url := v_url || '/monthly-report',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-backup-secret', v_secret),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
end;
$$;

revoke all on function public.run_monthly_report(boolean) from public, anon, authenticated;

select cron.unschedule('monthly-report')
where exists (select 1 from cron.job where jobname = 'monthly-report');

select cron.schedule('monthly-report', '0 6,7 1 * *', 'select public.run_monthly_report()');

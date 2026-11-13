-- Weekly backup emailed to the owner (see supabase/functions/weekly-backup).
--
-- The function runs without sign-in (pg_cron calls it), so it checks a
-- secret header against app_config.backup_secret, which clients cannot read
-- (app_config has no policies). The secret is made here, once.

insert into public.app_config (key, value)
values ('backup_secret', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (key) do nothing;

create or replace function public.run_weekly_backup()
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_url    text;
  v_secret text;
begin
  select value into v_url from public.app_config where key = 'functions_url';
  select value into v_secret from public.app_config where key = 'backup_secret';
  if v_url is null or v_secret is null then
    return; -- not configured in this environment
  end if;
  perform net.http_post(
    url := v_url || '/weekly-backup',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-backup-secret', v_secret),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
end;
$$;

revoke all on function public.run_weekly_backup() from public, anon, authenticated;

select cron.unschedule('weekly-backup')
where exists (select 1 from cron.job where jobname = 'weekly-backup');

-- Fridays 02:00 UTC (4-5 AM in Cairo), before the weekend's attendance.
select cron.schedule('weekly-backup', '0 2 * * 5', 'select public.run_weekly_backup()');

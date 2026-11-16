-- The weekly backup now has a second call for the photos (see
-- supabase/functions/weekly-backup). Same secret and URL as run_weekly_backup;
-- its own job, half an hour after the data, so neither waits for the other.

create or replace function public.run_weekly_photo_backup()
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
    body := '{"part":"photos"}'::jsonb,
    timeout_milliseconds := 150000
  );
end;
$$;

revoke all on function public.run_weekly_photo_backup() from public, anon, authenticated;

select cron.unschedule('weekly-backup-photos')
where exists (select 1 from cron.job where jobname = 'weekly-backup-photos');

select cron.schedule('weekly-backup-photos', '30 2 * * 5', 'select public.run_weekly_photo_backup()');

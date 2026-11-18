-- A weekly reminder to install the latest version, after each release.
--
-- Every release (send_update_push.ps1) records the version in app_config:
--   latest_app_version     e.g. '1.0.44'
--   update_reminder_until  a date, four weeks after the release
-- Until that date, every Friday at 5 PM Cairo time (the evening before the Saturday
-- service) each active person with a registered device gets a push and a bell entry
-- ("install version x"), at most one every six days. After the date, or when either
-- key is empty, nothing is sent. Clear 'update_reminder_until' to stop it sooner.
--
-- pg_cron runs in UTC and Cairo is UTC+2 or UTC+3, so the job runs at 14:00 and 15:00 UTC
-- on Fridays and acts only in Cairo's 5 PM hour. p_force is for trying it by hand.
--
-- The rows go into `notifications`, which the existing trigger pushes to the phones.

insert into public.app_config (key, value) values ('latest_app_version', '')
on conflict (key) do nothing;
insert into public.app_config (key, value) values ('update_reminder_until', '')
on conflict (key) do nothing;

create or replace function public.notify_update_reminder(p_force boolean default false)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now     timestamp := now() at time zone 'Africa/Cairo';
  v_version text;
  v_until   date;
  v_sent    integer := 0;
begin
  if not p_force and (extract(isodow from v_now) <> 5 or extract(hour from v_now) <> 17) then
    return 0;
  end if;

  select nullif(value, '') into v_version from public.app_config where key = 'latest_app_version';
  select nullif(value, '')::date into v_until from public.app_config where key = 'update_reminder_until';
  if v_version is null or v_until is null or v_now::date > v_until then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body)
  select p.id,
         'app_update',
         'تذكير: حدّث سبتاوية دلوقتي',
         'التطبيق مش هيشتغل غير بعد تثبيت النسخة ' || v_version || '. اضغط لفتح التطبيق وتحديثه.'
  from public.profiles p
  where p.is_active and not p.is_hidden
    and exists (select 1 from public.device_tokens d where d.user_id = p.id)
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id and n.kind = 'app_update'
        and n.created_at > now() - interval '6 days'
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$$;

revoke all on function public.notify_update_reminder(boolean) from public, anon, authenticated;

select cron.unschedule('friday-update-reminder')
where exists (select 1 from cron.job where jobname = 'friday-update-reminder');

select cron.schedule('friday-update-reminder', '0 14,15 * * 5',
                     'select public.notify_update_reminder()');

-- The weekly update reminder goes out every Friday at 9 PM Cairo time (it was 5 PM).
--
-- pg_cron runs in UTC and Cairo is UTC+2 or UTC+3, so 9 PM Cairo is 19:00 or 18:00 UTC. The job
-- fires at both and notify_update_reminder() acts only in Cairo's 9 PM hour, so it is sent once.

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
  if not p_force and (extract(isodow from v_now) <> 5 or extract(hour from v_now) <> 21) then
    return 0;
  end if;

  select nullif(value, '') into v_version from public.app_config where key = 'latest_app_version';
  select nullif(value, '')::date into v_until from public.app_config where key = 'update_reminder_until';
  if v_version is null or v_until is null or v_now::date > v_until then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body)
  select p.id,
         'app_update_reminder',
         'تذكير: حدّث سبتاوية دلوقتي',
         'التطبيق مش هيشتغل غير بعد تثبيت النسخة ' || v_version || '. اضغط لفتح التطبيق وتحديثه.'
  from public.profiles p
  where p.is_active and not p.is_hidden
    and exists (select 1 from public.device_tokens d where d.user_id = p.id)
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id
        and n.kind in ('app_update', 'app_update_reminder')
        and n.created_at > now() - interval '1 day'
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$$;

revoke all on function public.notify_update_reminder(boolean) from public, anon, authenticated;

select cron.unschedule('friday-update-reminder')
where exists (select 1 from cron.job where jobname = 'friday-update-reminder');

select cron.schedule('friday-update-reminder', '0 18,19 * * 5',
                     'select public.notify_update_reminder()');

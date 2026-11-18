-- The weekly reminder runs every Friday (Cairo 5 PM) until its end date, with no week skipped.
--
-- It used to hold back for six days after any update notice, so a release notice sent on a
-- Wednesday swallowed that same week's Friday reminder. The only repeat to guard against is
-- the job firing twice in the same hour (it is scheduled at 14:00 and 15:00 UTC and acts in
-- one of them), so the hold-back is one day.

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

-- Two kinds of update notice, so they can be told apart (and later styled or counted apart):
--
--   'app_update'            sent once per release by send_update_push.ps1
--                           («تحديث جديد لسبتاوية», "install version x")
--   'app_update_reminder'   sent by the weekly job notify_update_reminder()
--                           («تذكير: حدّث سبتاوية دلوقتي»)
--
-- The weekly job used to write the release kind. It now writes its own, and still holds back
-- for six days after any update notice of either kind, so nobody gets a release notice and a
-- reminder in the same week.

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
        and n.created_at > now() - interval '6 days'
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$$;

revoke all on function public.notify_update_reminder(boolean) from public, anon, authenticated;

-- The reminder sent by hand on 18 Nov was written as a release notice; mark it as the reminder it was.
update public.notifications
   set kind = 'app_update_reminder'
 where kind = 'app_update' and title = 'تذكير: حدّث سبتاوية دلوقتي';

-- The weekly reminder goes to every active person of every role (admin, servant, general
-- servant), not only people with a registered device, and says what fits what they use:
--
--   Android app          install the new version (open the app, update screen)
--   web / iPhone         open the app from the Home Screen icon, it updates by itself
--   no device on record  both ways, spelled out, as a bell entry
--
-- Same schedule as before (every Friday 9 PM Cairo, until update_reminder_until) and the same
-- one-day hold-back after any update notice.

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
         case
           when d.android then
             'التطبيق مش هيشتغل غير بعد تثبيت النسخة ' || v_version || '. اضغط لفتح التطبيق وتحديثه.'
           when d.web then
             'افتح سبتاوية من أيقونتها على الشاشة الرئيسية وهتتحدّث لوحدها للنسخة ' || v_version || '. لو مش مثبّتة، أضفها من متصفح سفاري.'
           else
             'حدّث سبتاوية للنسخة ' || v_version || ': على أندرويد ثبّت التطبيق من sabtawya.vercel.app/apk.html، ومن الآيفون افتح الموقع وأضفه للشاشة الرئيسية.'
         end
  from public.profiles p
  left join lateral (
    select coalesce(bool_or(t.platform = 'android'), false) as android,
           coalesce(bool_or(t.platform <> 'android'), false) as web
    from public.device_tokens t
    where t.user_id = p.id
  ) d on true
  where p.is_active and not p.is_hidden
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

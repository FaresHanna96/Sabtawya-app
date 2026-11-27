-- The weekly Friday reminder goes to every active user who is not on the latest build yet.
-- A release notice no longer cancels it: until now anyone who got an 'app_update' in the past
-- day was skipped, so a release shortly before Friday meant nobody was reminded. The one-day
-- check that remains only stops the reminder itself being sent twice.
-- Everything else is as in 20261126006; the cron job is unchanged.

CREATE OR REPLACE FUNCTION public.notify_update_reminder(p_force boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_now     timestamp := now() at time zone 'Africa/Cairo';
  v_version text;
  v_build   integer;
  v_until   date;
  v_sent    integer := 0;
begin
  if not p_force and (extract(isodow from v_now) <> 5 or extract(hour from v_now) <> 19) then
    return 0;
  end if;

  select nullif(value, '') into v_version from public.app_config where key = 'latest_app_version';
  select nullif(value, '')::date into v_until from public.app_config where key = 'update_reminder_until';
  select nullif(value, '')::integer into v_build from public.app_config where key = 'latest_app_build';
  if v_version is null or v_until is null or v_now::date > v_until then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body)
  select p.id,
         'app_update_reminder',
         'فكّرناك: حدّث سبتاوية 🔔',
         case
           when d.android then
             'نزّل النسخة ' || v_version || ' عشان التطبيق يفضل شغال. دوس هنا وحدّثه.'
           when d.web then
             'افتح سبتاوية من أيقونتها على الشاشة الرئيسية وهتتحدّث لوحدها للنسخة ' || v_version || '. لو مش عندك، ضيفها من سفاري.'
           else
             'حدّث سبتاوية للنسخة ' || v_version || ': أندرويد من sabtawya.vercel.app/apk.html، وآيفون افتح الموقع وضيفه للشاشة الرئيسية.'
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
      select 1 from public.user_app_builds b
      where b.user_id = p.id and v_build is not null and b.build >= v_build
    )
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id
        and n.kind = 'app_update_reminder'
        and n.created_at > now() - interval '1 day'
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$function$;

revoke all on function public.notify_update_reminder(boolean) from public, anon, authenticated;

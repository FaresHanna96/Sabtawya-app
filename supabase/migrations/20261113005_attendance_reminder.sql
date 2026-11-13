-- Saturday 7 PM (Cairo): the servants of a class that has nothing recorded
-- for today's Saturday get a reminder to take attendance.
--
-- Skipped on a Saturday that has a lesson break (no lesson that day). Kind
-- 'attendance_missing' carries the class id, so tapping it opens that
-- class's attendance (app 1.0.4+; older apps just mark it read).
--
-- pg_cron runs in UTC; Cairo is UTC+2 or UTC+3, so the job runs at 16:00 and
-- 17:00 UTC on Saturdays and acts only in Cairo's 7 PM hour. One reminder
-- per class per servant per day.

create or replace function public.notify_missing_attendance(p_force boolean default false)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now   timestamp := now() at time zone 'Africa/Cairo';
  v_today date := v_now::date;
  v_sent  integer;
begin
  if not p_force and (extract(isodow from v_now) <> 6 or extract(hour from v_now) <> 19) then
    return 0;
  end if;
  if exists (select 1 from public.lesson_breaks where break_date = v_today) then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id,
         'attendance_missing',
         'لم يُسجّل حضور اليوم',
         'لم يُسجّل حضور فصل ' || c.name || ' اليوم. سجّله قبل ما تنسى',
         c.id
  from public.attendance_sessions s
  join public.classes c on c.id = s.class_id and c.is_active
  join public.class_servants cs on cs.class_id = c.id
  join public.profiles p on p.id = cs.servant_id and p.is_active and not p.is_hidden
  where s.session_date = v_today
    and not exists (select 1 from public.attendance_records r where r.session_id = s.id)
    and not exists (
      select 1 from public.notifications n
      where n.user_id = cs.servant_id and n.kind = 'attendance_missing'
        and n.ref_id = c.id
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$$;

revoke all on function public.notify_missing_attendance(boolean) from public, anon, authenticated;

select cron.unschedule('saturday-attendance-reminder')
where exists (select 1 from cron.job where jobname = 'saturday-attendance-reminder');

select cron.schedule('saturday-attendance-reminder', '0 16,17 * * 6',
                     'select public.notify_missing_attendance()');

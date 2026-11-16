-- Sunday 5 PM (Cairo): the day after the Saturday attendance, tell the servants
-- which of their children have missed two Saturdays or more in a row, so they
-- can be visited that week. The app's screen متابعة الغياب stays as it is; this
-- only pushes the same list to the servants.
--
--   a servant gets one entry per class of theirs that has such children, with
--   the count and the first three names (the longest absences first);
--   an admin or the general servant gets the count for the whole service.
--
-- "Absent in a row" is the app's own rule: v_child_attendance_streak
-- (a Saturday counts only once somebody took attendance for that class) in the
-- current year. Kind 'absence_followup' opens متابعة الغياب (app 1.0.27+; older
-- apps just mark it read).
--
-- pg_cron runs in UTC and Cairo is UTC+2 or UTC+3, so the job runs at 14:00 and
-- 15:00 UTC on Sundays and acts only in Cairo's 5 PM hour. One entry per
-- person per class per day. p_force is for trying it by hand.

create or replace function public.notify_absence_followup(p_force boolean default false)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now   timestamp := now() at time zone 'Africa/Cairo';
  v_today date := v_now::date;
  v_year  uuid;
  v_sent  integer := 0;
  v_part  integer;
begin
  if not p_force and (extract(isodow from v_now) <> 7 or extract(hour from v_now) <> 17) then
    return 0;
  end if;

  select id into v_year from public.attendance_years where is_current limit 1;
  if v_year is null then
    return 0;
  end if;

  create temporary table if not exists _absent (
    class_id uuid, absent bigint, names text[]
  ) on commit drop;
  truncate _absent;

  insert into _absent
  select s.class_id,
         count(*),
         (array_agg(s.child_name order by s.absent_streak desc, s.child_name))[1:3]
  from public.v_child_attendance_streak s
  where s.year_id = v_year and s.absent_streak >= 2
  group by s.class_id;

  -- A servant: each class of theirs with absent children.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id,
         'absence_followup',
         'محتاجين افتقاد',
         'فصل ' || cl.name || ': ' ||
           case when a.absent = 1 then 'مخدوم واحد غايب'
                when a.absent = 2 then 'مخدومين غايبين'
                when a.absent <= 10 then a.absent || ' مخدومين غايبين'
                else a.absent || ' مخدوم غايبين'
           end || ' سبتين أو أكتر ورا بعض (' || array_to_string(a.names, '، ') ||
           case when a.absent > 3 then ' وغيرهم' else '' end || '). افتقدهم الأسبوع ده.',
         cl.id
  from public.class_servants cs
  join public.classes cl on cl.id = cs.class_id and cl.is_active
  join _absent a on a.class_id = cl.id
  join public.profiles p
    on p.id = cs.servant_id and p.is_active and not p.is_hidden
       and p.role = 'servant'
  where not exists (
    select 1 from public.notifications n
    where n.user_id = cs.servant_id and n.kind = 'absence_followup'
      and n.ref_id = cl.id
      and (n.created_at at time zone 'Africa/Cairo')::date = v_today
  );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  -- An admin or the general servant: the whole service.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id,
         'absence_followup',
         'محتاجين افتقاد',
         'في الخدمة ' ||
           case when t.absent = 1 then 'مخدوم واحد غايب'
                when t.absent = 2 then 'مخدومين غايبين'
                when t.absent <= 10 then t.absent || ' مخدومين غايبين'
                else t.absent || ' مخدوم غايبين'
           end || ' سبتين أو أكتر ورا بعض.',
         null
  from public.profiles p
  cross join (select coalesce(sum(absent), 0) as absent from _absent) t
  where p.is_active and not p.is_hidden
    and p.role in ('admin', 'general_servant')
    and t.absent > 0
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id and n.kind = 'absence_followup'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  return v_sent;
end;
$$;

revoke all on function public.notify_absence_followup(boolean) from public, anon, authenticated;

select cron.unschedule('sunday-absence-followup')
where exists (select 1 from cron.job where jobname = 'sunday-absence-followup');

select cron.schedule('sunday-absence-followup', '0 14,15 * * 0',
                     'select public.notify_absence_followup()');

-- How often each child came to each activity this year: Sunday school,
-- vespers, mass and confession, against the Saturdays held so far (like the
-- other year views since 20261112003). Feeds the reports' "الأنشطة" tab.
create or replace view public.v_child_activity_rates
with (security_invoker = true) as
with held as (
  select s.year_id, count(distinct s.session_date)::int as held
  from public.attendance_sessions s
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by s.year_id
),
came as (
  select r.child_id, s.year_id,
         count(distinct s.session_date) filter (where r.sunday_school)::int as sunday_school,
         count(distinct s.session_date) filter (where r.vespers)::int       as vespers,
         count(distinct s.session_date) filter (where r.mass)::int          as mass,
         count(distinct s.session_date) filter (where r.confession)::int    as confession
  from public.attendance_records r
  join public.attendance_sessions s on s.id = r.session_id
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by r.child_id, s.year_id
)
select
  ch.id         as child_id,
  ch.full_name  as child_name,
  ch.class_id,
  c.name        as class_name,
  ch.is_active  as child_is_active,
  h.year_id,
  h.held,
  coalesce(k.sunday_school, 0) as sunday_school,
  coalesce(k.vespers, 0)       as vespers,
  coalesce(k.mass, 0)          as mass,
  coalesce(k.confession, 0)    as confession
from public.children ch
join public.classes c on c.id = ch.class_id
cross join held h
left join came k on k.child_id = ch.id and k.year_id = h.year_id;

grant select on public.v_child_activity_rates to authenticated;

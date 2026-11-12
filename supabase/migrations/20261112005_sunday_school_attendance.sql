-- Sunday school (مدارس الأحد) attendance per child for a year, against the
-- Saturdays held so far. Feeds the dashboard's low-attendance list, which
-- looks at Sunday school only, not at total points (vespers, mass and
-- confession are left out).
--
-- Column names match v_child_year_report so the app reads it with the same
-- model: points = Saturdays the child came to Sunday school, max_points =
-- Saturdays held so far, percentage = points / max_points.
create or replace view public.v_child_sunday_school
with (security_invoker = true) as
with held as (
  select s.year_id, count(distinct s.session_date)::int as held
  from public.attendance_sessions s
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by s.year_id
),
came as (
  select r.child_id, s.year_id,
         count(distinct s.session_date)::int as came
  from public.attendance_records r
  join public.attendance_sessions s on s.id = r.session_id
  where r.sunday_school
    and s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by r.child_id, s.year_id
)
select
  ch.id                     as child_id,
  ch.full_name              as child_name,
  ch.gender,
  ch.is_active              as child_is_active,
  ch.class_id,
  c.name                    as class_name,
  h.year_id,
  h.held                    as sessions_total,
  coalesce(k.came, 0)       as sessions_attended,
  coalesce(k.came, 0)       as points,
  h.held                    as max_points,
  case when h.held > 0
       then round(coalesce(k.came, 0)::numeric * 100 / h.held, 1)
       else 0 end           as percentage
from public.children ch
join public.classes c on c.id = ch.class_id
cross join held h
left join came k on k.child_id = ch.id and k.year_id = h.year_id;

grant select on public.v_child_sunday_school to authenticated;

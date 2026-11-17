-- Attendance trend per child: how often the child came in the last four
-- Saturdays compared with the four before, in the current year, so a servant
-- can notice a child who still comes but less and less (before the streak of
-- absences even starts).
--
-- Same rules as v_child_attendance_streak: a Saturday counts only once the class
-- has at least one record for it, "present" is a score above zero, only active
-- children, and the view is security_invoker (a servant sees only their classes).
-- A child needs two full windows (8 counted Saturdays) to get a row.
create or replace view public.v_child_attendance_trend
with (security_invoker = true) as
with taken as (
  select s.id as session_id, s.class_id, s.year_id, s.session_date
  from public.attendance_sessions s
  where s.session_date <= current_date
    and exists (select 1 from public.attendance_records r where r.session_id = s.id)
),
marked as (
  select
    ch.id as child_id,
    t.year_id,
    t.session_date,
    coalesce(r.score, 0) > 0 as present
  from public.children ch
  join taken t on t.class_id = ch.class_id
  left join public.attendance_records r
         on r.session_id = t.session_id and r.child_id = ch.id
  where ch.is_active
),
ranked as (
  select
    m.*,
    row_number() over (
      partition by m.child_id, m.year_id order by m.session_date desc
    ) as position
  from marked m
),
agg as (
  select
    r.child_id,
    r.year_id,
    count(*) filter (where r.position <= 4)                     as recent_held,
    count(*) filter (where r.position <= 4 and r.present)       as recent_present,
    count(*) filter (where r.position between 5 and 8)          as previous_held,
    count(*) filter (where r.position between 5 and 8 and r.present) as previous_present
  from ranked r
  where r.position <= 8
  group by r.child_id, r.year_id
)
select
  a.child_id,
  ch.full_name as child_name,
  ch.class_id,
  c.name as class_name,
  a.year_id,
  a.recent_present,
  a.previous_present,
  round(a.recent_present   * 100.0 / a.recent_held)   as recent_rate,
  round(a.previous_present * 100.0 / a.previous_held) as previous_rate,
  round(a.previous_present * 100.0 / a.previous_held)
    - round(a.recent_present * 100.0 / a.recent_held)  as drop_points,
  (a.previous_present * 100.0 / a.previous_held
     - a.recent_present * 100.0 / a.recent_held) >= 25 as is_declining
from agg a
join public.children ch on ch.id = a.child_id
join public.classes  c  on c.id  = ch.class_id
where a.recent_held = 4 and a.previous_held = 4;

revoke all on public.v_child_attendance_trend from anon;
grant select on public.v_child_attendance_trend to authenticated;

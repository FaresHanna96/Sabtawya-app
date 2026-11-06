-- Attendance runs per child: how many Saturdays in a row absent / present,
-- counting back from the most recent Saturday whose attendance was taken.
--
-- A Saturday only counts once the class has at least one attendance record for
-- it. A Saturday nobody took attendance for must not turn every child absent.
-- "Present" means a score above zero, the same rule as v_child_commitment.
create or replace view public.v_child_attendance_streak
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
    max(r.position) as sessions,
    min(r.position) filter (where r.present)     as first_present,
    min(r.position) filter (where not r.present) as first_absent,
    max(r.session_date) filter (where r.present) as last_present_date
  from ranked r
  group by r.child_id, r.year_id
)
select
  a.child_id,
  ch.full_name as child_name,
  ch.gender,
  ch.photo_path,
  ch.class_id,
  c.name as class_name,
  a.year_id,
  coalesce(a.first_present - 1, a.sessions)::int as absent_streak,
  coalesce(a.first_absent  - 1, a.sessions)::int as present_streak,
  a.last_present_date
from agg a
join public.children ch on ch.id = a.child_id
join public.classes  c  on c.id  = ch.class_id;

revoke all on public.v_child_attendance_streak from anon;
grant select on public.v_child_attendance_streak to authenticated;

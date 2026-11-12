-- Year totals measured against the Saturdays held so far, not the whole year.
--
-- v_child_year_scores summed every month of the year, so max_points and
-- sessions_total counted Saturdays still to come: in November a child who
-- attended every Saturday showed about 10%, and "low attendance" (< 60%)
-- caught nearly everyone. Now only sessions dated up to today (Cairo) count.
--
-- v_child_year_report and v_class_year_scores read this view, so the reports,
-- the class ranking and the low-attendance list follow. The monthly views are
-- unchanged: a month is still measured against all its Saturdays.
--
-- Same columns and types as before, so dependent views stay valid.
create or replace view public.v_child_year_scores
with (security_invoker = true) as
with held as (
  select
    s.year_id,
    count(distinct s.session_date)                             as sessions_total,
    count(distinct s.session_date) * ay.max_points_per_session as max_points
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by s.year_id, ay.max_points_per_session
),
earned as (
  select
    r.child_id,
    s.year_id,
    sum(r.score)::int                   as points,
    count(*) filter (where r.score > 0) as sessions_attended
  from public.attendance_records r
  join public.attendance_sessions s on s.id = r.session_id
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by r.child_id, s.year_id
)
select
  ch.id                                 as child_id,
  ch.class_id,
  h.year_id,
  h.sessions_total::int                 as sessions_total,
  coalesce(e.sessions_attended, 0)::int as sessions_attended,
  coalesce(e.points, 0)::int            as points,
  h.max_points::int                     as max_points,
  case
    when h.max_points > 0
      then round(coalesce(e.points, 0)::numeric * 100 / h.max_points, 1)
    else 0
  end                                   as percentage
from public.children ch
cross join held h
left join earned e
       on e.child_id = ch.id
      and e.year_id  = h.year_id;

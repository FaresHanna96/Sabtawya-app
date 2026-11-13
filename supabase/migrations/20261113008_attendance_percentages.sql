-- Every report's percentage is attendance: Saturdays the child came out of
-- the Saturdays held so far (owner's choice, 2026-11-13). Points stay as
-- their own columns. Also fixes the monthly view, which counted the month's
-- Saturdays still to come (November showed 4 held on the 13th, and a child
-- who came to the only Saturday so far showed 6.3%).
--
-- Column lists are unchanged (create or replace), except two sums appended
-- to v_class_year_scores so the app can rank classes by attendance.

create or replace view public.v_child_monthly_scores
with (security_invoker = true) as
with calendar as (
  select s.year_id,
         date_trunc('month', s.session_date)::date as month_start,
         count(distinct s.session_date) as sessions_total,
         count(distinct s.session_date) * ay.max_points_per_session as max_points
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by s.year_id, date_trunc('month', s.session_date), ay.max_points_per_session
),
earned as (
  select r.child_id, s.year_id,
         date_trunc('month', s.session_date)::date as month_start,
         sum(r.score)::integer as points,
         count(*) filter (where r.score > 0) as sessions_attended
  from public.attendance_records r
  join public.attendance_sessions s on s.id = r.session_id
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by r.child_id, s.year_id, date_trunc('month', s.session_date)
)
select
  ch.id as child_id,
  ch.class_id,
  cal.year_id,
  cal.month_start,
  cal.sessions_total::integer as sessions_total,
  cal.max_points::integer as max_points,
  coalesce(e.points, 0) as points,
  coalesce(e.sessions_attended, 0)::integer as sessions_attended,
  case when cal.sessions_total > 0
       then round(coalesce(e.sessions_attended, 0)::numeric * 100 / cal.sessions_total, 1)
       else 0::numeric end as percentage
from public.children ch
cross join calendar cal
left join earned e
  on e.child_id = ch.id and e.year_id = cal.year_id and e.month_start = cal.month_start;

create or replace view public.v_child_year_scores
with (security_invoker = true) as
with held as (
  select s.year_id,
         count(distinct s.session_date) as sessions_total,
         count(distinct s.session_date) * ay.max_points_per_session as max_points
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by s.year_id, ay.max_points_per_session
),
earned as (
  select r.child_id, s.year_id,
         sum(r.score)::integer as points,
         count(*) filter (where r.score > 0) as sessions_attended
  from public.attendance_records r
  join public.attendance_sessions s on s.id = r.session_id
  where s.session_date <= (now() at time zone 'Africa/Cairo')::date
  group by r.child_id, s.year_id
)
select
  ch.id as child_id,
  ch.class_id,
  h.year_id,
  h.sessions_total::integer as sessions_total,
  coalesce(e.sessions_attended, 0)::integer as sessions_attended,
  coalesce(e.points, 0) as points,
  h.max_points::integer as max_points,
  case when h.sessions_total > 0
       then round(coalesce(e.sessions_attended, 0)::numeric * 100 / h.sessions_total, 1)
       else 0::numeric end as percentage
from public.children ch
cross join held h
left join earned e on e.child_id = ch.id and e.year_id = h.year_id;

create or replace view public.v_class_year_scores
with (security_invoker = true) as
select
  y.class_id,
  c.name as class_name,
  y.year_id,
  count(*)::integer as children,
  sum(y.points)::integer as points,
  sum(y.max_points)::integer as max_points,
  case when sum(y.sessions_total) > 0
       then round(sum(y.sessions_attended)::numeric * 100 / sum(y.sessions_total), 1)
       else 0::numeric end as percentage,
  sum(y.sessions_attended)::integer as sessions_attended,
  sum(y.sessions_total)::integer as sessions_total
from public.v_child_year_scores y
join public.children ch on ch.id = y.child_id
join public.classes c on c.id = y.class_id
where ch.is_active
group by y.class_id, c.name, y.year_id;

-- =============================================================================
-- 03 - Reporting views
-- =============================================================================
-- Every view uses security_invoker so the caller's RLS policies still apply.
-- A servant querying these sees only their own classes.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Class overview: powers both dashboards and the classes list
-- -----------------------------------------------------------------------------
create or replace view public.v_class_overview
with (security_invoker = true) as
select
  c.id          as class_id,
  c.name        as class_name,
  c.description,
  c.sort_order,
  c.is_active,
  (select count(*)
     from public.children ch
    where ch.class_id = c.id and ch.is_active)           as active_children,
  (select count(*)
     from public.children ch
    where ch.class_id = c.id and ch.is_active and ch.gender = 'boy')  as boys_count,
  (select count(*)
     from public.children ch
    where ch.class_id = c.id and ch.is_active and ch.gender = 'girl') as girls_count,
  (select count(*)
     from public.class_servants cs
    where cs.class_id = c.id)                            as servants_count,
  (select min(s.session_date)
     from public.attendance_sessions s
    where s.class_id = c.id and s.session_date >= current_date) as next_session_date,
  (select max(s.session_date)
     from public.attendance_sessions s
    where s.class_id = c.id and s.session_date <= current_date) as last_session_date
from public.classes c;

-- -----------------------------------------------------------------------------
-- Servant assignments, flattened for display
-- -----------------------------------------------------------------------------
create or replace view public.v_class_servants
with (security_invoker = true) as
select
  cs.id         as assignment_id,
  cs.class_id,
  c.name        as class_name,
  cs.servant_id,
  p.full_name   as servant_name,
  p.email       as servant_email,
  p.mobile      as servant_mobile,
  p.is_active   as servant_is_active,
  cs.assigned_at
from public.class_servants cs
join public.profiles p on p.id = cs.servant_id
join public.classes  c on c.id = cs.class_id;

-- -----------------------------------------------------------------------------
-- One row per child per attendance day, with the class it was taken in
-- -----------------------------------------------------------------------------
create or replace view public.v_session_scores
with (security_invoker = true) as
select
  r.id          as record_id,
  s.id          as session_id,
  s.year_id,
  s.class_id,
  c.name        as class_name,
  s.session_date,
  s.is_locked,
  ch.id         as child_id,
  ch.full_name  as child_name,
  ch.gender,
  ch.is_active  as child_is_active,
  r.sunday_school,
  r.vespers,
  r.mass,
  r.score,
  r.max_score,
  r.updated_at,
  r.updated_by,
  p.full_name   as updated_by_name
from public.attendance_records r
join public.attendance_sessions s on s.id = r.session_id
join public.classes            c on c.id = s.class_id
join public.children          ch on ch.id = r.child_id
left join public.profiles      p on p.id = r.updated_by;

-- -----------------------------------------------------------------------------
-- Per-class progress for one attendance day, used by the history screen
-- -----------------------------------------------------------------------------
create or replace view public.v_class_session_summary
with (security_invoker = true) as
select
  s.id           as session_id,
  s.year_id,
  s.class_id,
  s.session_date,
  s.is_locked,
  s.notes,
  count(r.id)                                      as recorded_count,
  count(r.id) filter (where r.score > 0)           as present_count,
  coalesce(sum(r.score), 0)::int                   as points,
  coalesce(sum(r.max_score), 0)::int               as max_points,
  (select count(*)
     from public.children ch
    where ch.class_id = s.class_id and ch.is_active) as active_children
from public.attendance_sessions s
left join public.attendance_records r on r.session_id = s.id
group by s.id, s.year_id, s.class_id, s.session_date, s.is_locked, s.notes;

-- -----------------------------------------------------------------------------
-- Monthly rollup
-- -----------------------------------------------------------------------------
-- The maximum comes from the attendance calendar, not from the rows a servant
-- happened to save, so a month with no data still reports the right ceiling.
-- Earned points come from the child's own records regardless of which class the
-- session belonged to, so moving a child never loses history.
create or replace view public.v_child_monthly_scores
with (security_invoker = true) as
with calendar as (
  select
    s.year_id,
    date_trunc('month', s.session_date)::date                  as month_start,
    count(distinct s.session_date)                             as sessions_total,
    count(distinct s.session_date) * ay.max_points_per_session as max_points
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  group by s.year_id, date_trunc('month', s.session_date), ay.max_points_per_session
),
earned as (
  select
    r.child_id,
    s.year_id,
    date_trunc('month', s.session_date)::date  as month_start,
    sum(r.score)::int                          as points,
    count(*) filter (where r.score > 0)        as sessions_attended
  from public.attendance_records r
  join public.attendance_sessions s on s.id = r.session_id
  group by r.child_id, s.year_id, date_trunc('month', s.session_date)
)
select
  ch.id                                  as child_id,
  ch.class_id,
  cal.year_id,
  cal.month_start,
  cal.sessions_total::int                as sessions_total,
  cal.max_points::int                    as max_points,
  coalesce(e.points, 0)::int             as points,
  coalesce(e.sessions_attended, 0)::int  as sessions_attended,
  case
    when cal.max_points > 0
      then round(coalesce(e.points, 0)::numeric * 100 / cal.max_points, 1)
    else 0
  end                                    as percentage
from public.children ch
cross join calendar cal
left join earned e
       on e.child_id    = ch.id
      and e.year_id     = cal.year_id
      and e.month_start = cal.month_start;

-- -----------------------------------------------------------------------------
-- Yearly rollup
-- -----------------------------------------------------------------------------
create or replace view public.v_child_year_scores
with (security_invoker = true) as
select
  m.child_id,
  m.class_id,
  m.year_id,
  sum(m.sessions_total)::int    as sessions_total,
  sum(m.sessions_attended)::int as sessions_attended,
  sum(m.points)::int            as points,
  sum(m.max_points)::int        as max_points,
  case
    when sum(m.max_points) > 0
      then round(sum(m.points)::numeric * 100 / sum(m.max_points), 1)
    else 0
  end                           as percentage
from public.v_child_monthly_scores m
group by m.child_id, m.class_id, m.year_id;

-- -----------------------------------------------------------------------------
-- Report-ready projections that carry names, so exports need no extra joins
-- -----------------------------------------------------------------------------
create or replace view public.v_child_year_report
with (security_invoker = true) as
select
  y.child_id,
  ch.full_name as child_name,
  ch.gender,
  ch.birth_date,
  ch.code      as child_code,
  ch.mobile    as child_mobile,
  ch.school,
  ch.is_active as child_is_active,
  y.class_id,
  c.name       as class_name,
  y.year_id,
  ay.name      as year_name,
  y.sessions_total,
  y.sessions_attended,
  y.points,
  y.max_points,
  y.percentage
from public.v_child_year_scores y
join public.children         ch on ch.id = y.child_id
join public.classes           c on c.id  = y.class_id
join public.attendance_years ay on ay.id = y.year_id;

create or replace view public.v_child_monthly_report
with (security_invoker = true) as
select
  m.child_id,
  ch.full_name as child_name,
  ch.gender,
  ch.is_active as child_is_active,
  m.class_id,
  c.name       as class_name,
  m.year_id,
  m.month_start,
  m.sessions_total,
  m.sessions_attended,
  m.points,
  m.max_points,
  m.percentage
from public.v_child_monthly_scores m
join public.children ch on ch.id = m.child_id
join public.classes   c on c.id  = m.class_id;

-- -----------------------------------------------------------------------------
-- Class standing for a year
-- -----------------------------------------------------------------------------
create or replace view public.v_class_year_scores
with (security_invoker = true) as
select
  y.class_id,
  c.name                  as class_name,
  y.year_id,
  count(*)::int           as children,
  sum(y.points)::int      as points,
  sum(y.max_points)::int  as max_points,
  case
    when sum(y.max_points) > 0
      then round(sum(y.points)::numeric * 100 / sum(y.max_points), 1)
    else 0
  end                     as percentage
from public.v_child_year_scores y
join public.children ch on ch.id = y.child_id
join public.classes   c on c.id  = y.class_id
where ch.is_active
group by y.class_id, c.name, y.year_id;

-- -----------------------------------------------------------------------------
-- Admin dashboard counters
-- -----------------------------------------------------------------------------
create or replace view public.v_admin_stats
with (security_invoker = true) as
select
  (select count(*) from public.classes  where is_active)                        as classes_count,
  (select count(*) from public.profiles where is_active and role = 'servant')   as servants_count,
  (select count(*) from public.profiles where is_active and role = 'admin')     as admins_count,
  (select count(*) from public.children where is_active)                        as children_count,
  (select count(*) from public.children where is_active and gender = 'boy')     as boys_count,
  (select count(*) from public.children where is_active and gender = 'girl')    as girls_count,
  (select min(session_date) from public.attendance_sessions
    where session_date >= current_date)                                         as next_session_date,
  (select coalesce(sum(score), 0)::int from public.attendance_records)          as total_points;

-- -----------------------------------------------------------------------------
-- Grants
-- -----------------------------------------------------------------------------
grant select on public.v_class_overview        to authenticated;
grant select on public.v_class_servants        to authenticated;
grant select on public.v_session_scores        to authenticated;
grant select on public.v_class_session_summary to authenticated;
grant select on public.v_child_monthly_scores  to authenticated;
grant select on public.v_child_year_scores     to authenticated;
grant select on public.v_child_year_report     to authenticated;
grant select on public.v_child_monthly_report  to authenticated;
grant select on public.v_class_year_scores     to authenticated;
grant select on public.v_admin_stats           to authenticated;

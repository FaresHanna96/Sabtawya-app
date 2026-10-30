-- =============================================================================
-- 09 - The dashboards point at the Saturday being recorded
-- =============================================================================
-- next_session_date answered "which Saturday is coming", but attendance is
-- taken for the Saturday that has just passed: on a Sunday the dashboards
-- advertised the Saturday six days away while the attendance editor opened on
-- yesterday's. Both now agree on the most recent Saturday.
--
-- last_session_date falls back to the first Saturday of the year, so before the
-- year starts the dashboards still name a real day instead of nothing.
-- =============================================================================

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
  coalesce(
    (select max(s.session_date)
       from public.attendance_sessions s
      where s.class_id = c.id and s.session_date <= current_date),
    (select min(s.session_date)
       from public.attendance_sessions s
      where s.class_id = c.id)
  )                                                      as last_session_date
from public.classes c;

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
  (select coalesce(sum(score), 0)::int from public.attendance_records)          as total_points,
  coalesce(
    (select max(session_date) from public.attendance_sessions
      where session_date <= current_date),
    (select min(session_date) from public.attendance_sessions)
  )                                                                             as last_session_date;

revoke all on public.v_class_overview from anon;
revoke all on public.v_admin_stats    from anon;
grant select on public.v_class_overview to authenticated;
grant select on public.v_admin_stats    to authenticated;

-- =============================================================================
-- 12 - Per-child insights: last time for each activity, and who is committed
-- =============================================================================
-- Both views are security_invoker, so a servant sees only the children of the
-- classes they serve and an admin sees everyone, with no extra filtering in the
-- app.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- The last Saturday a child did each of the four activities
-- -----------------------------------------------------------------------------
-- A child with no record at all still appears, with nulls, so the profile can
-- say "لم يحضر بعد" instead of showing nothing.
create or replace view public.v_child_last_activity
with (security_invoker = true) as
select
  ch.id                                              as child_id,
  ch.class_id,
  max(s.session_date) filter (where r.sunday_school)  as last_sunday_school,
  max(s.session_date) filter (where r.vespers)        as last_vespers,
  max(s.session_date) filter (where r.mass)           as last_mass,
  max(s.session_date) filter (where r.confession)     as last_confession,
  max(s.session_date) filter (where r.score > 0)      as last_present,
  max(s.session_date)                                 as last_recorded
from public.children ch
left join public.attendance_records  r on r.child_id = ch.id
left join public.attendance_sessions s on s.id = r.session_id
group by ch.id, ch.class_id;

revoke all on public.v_child_last_activity from anon;
grant select on public.v_child_last_activity to authenticated;

-- -----------------------------------------------------------------------------
-- Commitment: measured against the Saturdays that have already happened
-- -----------------------------------------------------------------------------
-- Rates are deliberately not taken over the whole year: in October a child who
-- attended every Saturday so far should read 100%, not 4%.
--
-- current_streak counts back from the most recent Saturday and stops at the
-- first one the child missed, which is what makes a child "ملتزم" rather than
-- simply high-scoring.
create or replace view public.v_child_commitment
with (security_invoker = true) as
with held as (
  select s.id as session_id, s.class_id, s.year_id, s.session_date
  from public.attendance_sessions s
  where s.session_date <= current_date
),
marked as (
  select
    ch.id              as child_id,
    ch.class_id,
    h.year_id,
    h.session_date,
    coalesce(r.score, 0) as score,
    coalesce(r.score, 0) > 0 as present
  from public.children ch
  join held h on h.class_id = ch.class_id
  left join public.attendance_records r
         on r.session_id = h.session_id and r.child_id = ch.id
  where ch.is_active
),
totals as (
  select
    m.child_id,
    m.class_id,
    m.year_id,
    count(*)                                   as sessions_held,
    count(*) filter (where m.present)          as sessions_attended,
    sum(m.score)::int                          as points,
    (count(*) * ay.max_points_per_session)::int as max_points
  from marked m
  join public.attendance_years ay on ay.id = m.year_id
  group by m.child_id, m.class_id, m.year_id, ay.max_points_per_session
),
ranked as (
  select
    m.child_id,
    m.year_id,
    m.present,
    row_number() over (
      partition by m.child_id, m.year_id order by m.session_date desc
    ) as position
  from marked m
),
streaks as (
  select
    r.child_id,
    r.year_id,
    coalesce(min(r.position) filter (where not r.present) - 1, max(r.position))
      as current_streak
  from ranked r
  group by r.child_id, r.year_id
)
select
  t.child_id,
  ch.full_name  as child_name,
  ch.gender,
  ch.photo_path,
  t.class_id,
  c.name        as class_name,
  t.year_id,
  t.sessions_held,
  t.sessions_attended,
  t.points,
  t.max_points,
  coalesce(s.current_streak, 0)::int as current_streak,
  case
    when t.max_points > 0
      then round(t.points::numeric * 100 / t.max_points, 1)
    else 0
  end as points_percentage,
  case
    when t.sessions_held > 0
      then round(t.sessions_attended::numeric * 100 / t.sessions_held, 1)
    else 0
  end as attendance_percentage
from totals t
join public.children ch on ch.id = t.child_id
join public.classes   c on c.id  = t.class_id
left join streaks     s on s.child_id = t.child_id and s.year_id = t.year_id;

revoke all on public.v_child_commitment from anon;
grant select on public.v_child_commitment to authenticated;

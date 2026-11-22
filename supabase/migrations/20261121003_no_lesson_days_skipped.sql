-- A Saturday with no lesson (إجازة / نشاط ترفيهي, in lesson_breaks) stays in
-- place, with anything already saved on it, but is marked and left out of
-- every calculation: percentages, points, ملتزمين, the trend, absence alerts,
-- class health, the weekly chart, last / next Saturday. New attendance cannot
-- be saved on it.
--
-- attendance_sessions.is_break carries the mark, kept in step with
-- lesson_breaks by triggers, so every view filters on one column. The views
-- below are their current definitions with only that filter added.

-- ── the mark ───────────────────────────────────────────────────────────────
alter table public.attendance_sessions
  add column if not exists is_break boolean not null default false;

update public.attendance_sessions s
set is_break = exists (select 1 from public.lesson_breaks b
                       where b.break_date = s.session_date)
where s.is_break is distinct from exists (select 1 from public.lesson_breaks b
                                          where b.break_date = s.session_date);

-- A new session (new year, new class) is marked when its day has no lesson.
create or replace function public.attendance_sessions_mark_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.is_break := exists (select 1 from public.lesson_breaks b
                          where b.break_date = new.session_date);
  return new;
end;
$$;

drop trigger if exists attendance_sessions_mark_break on public.attendance_sessions;
create trigger attendance_sessions_mark_break
  before insert or update of session_date on public.attendance_sessions
  for each row execute function public.attendance_sessions_mark_break();

-- Marking or clearing a no-lesson day marks every class's session that day.
create or replace function public.lesson_breaks_sync_sessions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op in ('DELETE', 'UPDATE') then
    update public.attendance_sessions set is_break = false
    where session_date = old.break_date and is_break;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    update public.attendance_sessions set is_break = true
    where session_date = new.break_date and not is_break;
  end if;
  return null;
end;
$$;

drop trigger if exists lesson_breaks_sync_sessions on public.lesson_breaks;
create trigger lesson_breaks_sync_sessions
  after insert or update or delete on public.lesson_breaks
  for each row execute function public.lesson_breaks_sync_sessions();

-- No new attendance on a no-lesson day (what was saved before stays, ignored).
create or replace function public.attendance_records_no_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (select 1 from public.attendance_sessions s
             where s.id = new.session_id and s.is_break) then
    raise exception 'هذا السبت إجازة أو نشاط ترفيهي: لا يُسجَّل فيه حضور'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists attendance_records_no_break on public.attendance_records;
create trigger attendance_records_no_break
  before insert or update on public.attendance_records
  for each row execute function public.attendance_records_no_break();

-- ── the views: no-lesson Saturdays left out ──────────────────────────────────

create or replace view public.v_admin_stats
with (security_invoker = true) as
SELECT ( SELECT count(*) AS count
           FROM classes
          WHERE classes.is_active) AS classes_count,
    ( SELECT count(*) AS count
           FROM profiles
          WHERE profiles.is_active AND profiles.role = 'servant'::app_role) AS servants_count,
    ( SELECT count(*) AS count
           FROM profiles
          WHERE profiles.is_active AND profiles.role = 'admin'::app_role) AS admins_count,
    ( SELECT count(*) AS count
           FROM children
          WHERE children.is_active) AS children_count,
    ( SELECT count(*) AS count
           FROM children
          WHERE children.is_active AND children.gender = 'boy'::person_gender) AS boys_count,
    ( SELECT count(*) AS count
           FROM children
          WHERE children.is_active AND children.gender = 'girl'::person_gender) AS girls_count,
    ( SELECT min(attendance_sessions.session_date) AS min
           FROM attendance_sessions
          WHERE NOT attendance_sessions.is_break AND attendance_sessions.session_date >= CURRENT_DATE) AS next_session_date,
    ( SELECT COALESCE(sum(attendance_records.score), 0::bigint)::integer AS "coalesce"
           FROM attendance_records
             JOIN attendance_sessions bs ON bs.id = attendance_records.session_id
          WHERE NOT bs.is_break) AS total_points,
    COALESCE(( SELECT max(attendance_sessions.session_date) AS max
           FROM attendance_sessions
          WHERE NOT attendance_sessions.is_break AND attendance_sessions.session_date <= CURRENT_DATE), ( SELECT min(attendance_sessions.session_date) AS min
           FROM attendance_sessions
          WHERE NOT attendance_sessions.is_break)) AS last_session_date;

create or replace view public.v_child_activity_rates
with (security_invoker = true) as
WITH held AS (
         SELECT s.year_id,
            count(DISTINCT s.session_date)::integer AS held
           FROM attendance_sessions s
          WHERE NOT s.is_break AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id
        ), came AS (
         SELECT r.child_id,
            s.year_id,
            count(DISTINCT s.session_date) FILTER (WHERE r.sunday_school)::integer AS sunday_school,
            count(DISTINCT s.session_date) FILTER (WHERE r.vespers)::integer AS vespers,
            count(DISTINCT s.session_date) FILTER (WHERE r.mass)::integer AS mass,
            count(DISTINCT s.session_date) FILTER (WHERE r.confession)::integer AS confession
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.is_break
          WHERE s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY r.child_id, s.year_id
        )
 SELECT ch.id AS child_id,
    ch.full_name AS child_name,
    ch.class_id,
    c.name AS class_name,
    ch.is_active AS child_is_active,
    h.year_id,
    h.held,
    COALESCE(k.sunday_school, 0) AS sunday_school,
    COALESCE(k.vespers, 0) AS vespers,
    COALESCE(k.mass, 0) AS mass,
    COALESCE(k.confession, 0) AS confession
   FROM children ch
     JOIN classes c ON c.id = ch.class_id
     CROSS JOIN held h
     LEFT JOIN came k ON k.child_id = ch.id AND k.year_id = h.year_id;

create or replace view public.v_child_commitment
with (security_invoker = true) as
WITH held AS (
         SELECT s_1.id AS session_id,
            s_1.class_id,
            s_1.year_id,
            s_1.session_date
           FROM attendance_sessions s_1
          WHERE NOT s_1.is_break AND s_1.session_date <= CURRENT_DATE
        ), marked AS (
         SELECT ch_1.id AS child_id,
            ch_1.class_id,
            h.year_id,
            h.session_date,
            COALESCE(r.score, 0) AS score,
            COALESCE(r.score, 0) > 0 AS present
           FROM children ch_1
             JOIN held h ON h.class_id = ch_1.class_id
             LEFT JOIN attendance_records r ON r.session_id = h.session_id AND r.child_id = ch_1.id
          WHERE ch_1.is_active
        ), totals AS (
         SELECT m.child_id,
            m.class_id,
            m.year_id,
            count(*) AS sessions_held,
            count(*) FILTER (WHERE m.present) AS sessions_attended,
            sum(m.score)::integer AS points,
            (count(*) * ay.max_points_per_session)::integer AS max_points
           FROM marked m
             JOIN attendance_years ay ON ay.id = m.year_id
          GROUP BY m.child_id, m.class_id, m.year_id, ay.max_points_per_session
        ), ranked AS (
         SELECT m.child_id,
            m.year_id,
            m.present,
            row_number() OVER (PARTITION BY m.child_id, m.year_id ORDER BY m.session_date DESC) AS "position"
           FROM marked m
        ), streaks AS (
         SELECT r.child_id,
            r.year_id,
            COALESCE(min(r."position") FILTER (WHERE NOT r.present) - 1, max(r."position")) AS current_streak
           FROM ranked r
          GROUP BY r.child_id, r.year_id
        )
 SELECT t.child_id,
    ch.full_name AS child_name,
    ch.gender,
    ch.photo_path,
    t.class_id,
    c.name AS class_name,
    t.year_id,
    t.sessions_held,
    t.sessions_attended,
    t.points,
    t.max_points,
    COALESCE(s.current_streak, 0::bigint)::integer AS current_streak,
        CASE
            WHEN t.max_points > 0 THEN round(t.points::numeric * 100::numeric / t.max_points::numeric, 1)
            ELSE 0::numeric
        END AS points_percentage,
        CASE
            WHEN t.sessions_held > 0 THEN round(t.sessions_attended::numeric * 100::numeric / t.sessions_held::numeric, 1)
            ELSE 0::numeric
        END AS attendance_percentage
   FROM totals t
     JOIN children ch ON ch.id = t.child_id
     JOIN classes c ON c.id = t.class_id
     LEFT JOIN streaks s ON s.child_id = t.child_id AND s.year_id = t.year_id;

create or replace view public.v_child_last_activity
with (security_invoker = true) as
SELECT ch.id AS child_id,
    ch.class_id,
    max(s.session_date) FILTER (WHERE r.sunday_school) AS last_sunday_school,
    max(s.session_date) FILTER (WHERE r.vespers) AS last_vespers,
    max(s.session_date) FILTER (WHERE r.mass) AS last_mass,
    max(s.session_date) FILTER (WHERE r.confession) AS last_confession,
    max(s.session_date) FILTER (WHERE r.score > 0) AS last_present,
    max(s.session_date) AS last_recorded
   FROM children ch
     LEFT JOIN attendance_records r ON r.child_id = ch.id
     LEFT JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.is_break
  GROUP BY ch.id, ch.class_id;

create or replace view public.v_child_monthly_scores
with (security_invoker = true) as
WITH calendar AS (
         SELECT s.year_id,
            date_trunc('month'::text, s.session_date::timestamp with time zone)::date AS month_start,
            count(DISTINCT s.session_date) AS sessions_total,
            count(DISTINCT s.session_date) * ay.max_points_per_session AS max_points
           FROM attendance_sessions s
             JOIN attendance_years ay ON ay.id = s.year_id
          WHERE NOT s.is_break AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id, (date_trunc('month'::text, s.session_date::timestamp with time zone)), ay.max_points_per_session
        ), earned AS (
         SELECT r.child_id,
            s.year_id,
            date_trunc('month'::text, s.session_date::timestamp with time zone)::date AS month_start,
            sum(r.score)::integer AS points,
            count(*) FILTER (WHERE r.score > 0) AS sessions_attended
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.is_break
          WHERE s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY r.child_id, s.year_id, (date_trunc('month'::text, s.session_date::timestamp with time zone))
        )
 SELECT ch.id AS child_id,
    ch.class_id,
    cal.year_id,
    cal.month_start,
    cal.sessions_total::integer AS sessions_total,
    cal.max_points::integer AS max_points,
    COALESCE(e.points, 0) AS points,
    COALESCE(e.sessions_attended, 0::bigint)::integer AS sessions_attended,
        CASE
            WHEN cal.sessions_total > 0 THEN round(COALESCE(e.sessions_attended, 0::bigint)::numeric * 100::numeric / cal.sessions_total::numeric, 1)
            ELSE 0::numeric
        END AS percentage
   FROM children ch
     CROSS JOIN calendar cal
     LEFT JOIN earned e ON e.child_id = ch.id AND e.year_id = cal.year_id AND e.month_start = cal.month_start;

create or replace view public.v_child_sunday_school
with (security_invoker = true) as
WITH held AS (
         SELECT s.year_id,
            count(DISTINCT s.session_date)::integer AS held
           FROM attendance_sessions s
          WHERE NOT s.is_break AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id
        ), came AS (
         SELECT r.child_id,
            s.year_id,
            count(DISTINCT s.session_date)::integer AS came
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.is_break
          WHERE r.sunday_school AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY r.child_id, s.year_id
        )
 SELECT ch.id AS child_id,
    ch.full_name AS child_name,
    ch.gender,
    ch.is_active AS child_is_active,
    ch.class_id,
    c.name AS class_name,
    h.year_id,
    h.held AS sessions_total,
    COALESCE(k.came, 0) AS sessions_attended,
    COALESCE(k.came, 0) AS points,
    h.held AS max_points,
        CASE
            WHEN h.held > 0 THEN round(COALESCE(k.came, 0)::numeric * 100::numeric / h.held::numeric, 1)
            ELSE 0::numeric
        END AS percentage
   FROM children ch
     JOIN classes c ON c.id = ch.class_id
     CROSS JOIN held h
     LEFT JOIN came k ON k.child_id = ch.id AND k.year_id = h.year_id;

create or replace view public.v_child_year_scores
with (security_invoker = true) as
WITH held AS (
         SELECT s.year_id,
            count(DISTINCT s.session_date) AS sessions_total,
            count(DISTINCT s.session_date) * ay.max_points_per_session AS max_points
           FROM attendance_sessions s
             JOIN attendance_years ay ON ay.id = s.year_id
          WHERE NOT s.is_break AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id, ay.max_points_per_session
        ), earned AS (
         SELECT r.child_id,
            s.year_id,
            sum(r.score)::integer AS points,
            count(*) FILTER (WHERE r.score > 0) AS sessions_attended
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.is_break
          WHERE s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY r.child_id, s.year_id
        )
 SELECT ch.id AS child_id,
    ch.class_id,
    h.year_id,
    h.sessions_total::integer AS sessions_total,
    COALESCE(e.sessions_attended, 0::bigint)::integer AS sessions_attended,
    COALESCE(e.points, 0) AS points,
    h.max_points::integer AS max_points,
        CASE
            WHEN h.sessions_total > 0 THEN round(COALESCE(e.sessions_attended, 0::bigint)::numeric * 100::numeric / h.sessions_total::numeric, 1)
            ELSE 0::numeric
        END AS percentage
   FROM children ch
     CROSS JOIN held h
     LEFT JOIN earned e ON e.child_id = ch.id AND e.year_id = h.year_id;

create or replace view public.v_class_overview
with (security_invoker = true) as
SELECT id AS class_id,
    name AS class_name,
    description,
    sort_order,
    is_active,
    ( SELECT count(*) AS count
           FROM children ch
          WHERE ch.class_id = c.id AND ch.is_active) AS active_children,
    ( SELECT count(*) AS count
           FROM children ch
          WHERE ch.class_id = c.id AND ch.is_active AND ch.gender = 'boy'::person_gender) AS boys_count,
    ( SELECT count(*) AS count
           FROM children ch
          WHERE ch.class_id = c.id AND ch.is_active AND ch.gender = 'girl'::person_gender) AS girls_count,
    ( SELECT count(*) AS count
           FROM class_servants cs
          WHERE cs.class_id = c.id) AS servants_count,
    ( SELECT min(s.session_date) AS min
           FROM attendance_sessions s
          WHERE NOT s.is_break AND s.class_id = c.id AND s.session_date >= CURRENT_DATE) AS next_session_date,
    COALESCE(( SELECT max(s.session_date) AS max
           FROM attendance_sessions s
          WHERE NOT s.is_break AND s.class_id = c.id AND s.session_date <= CURRENT_DATE), ( SELECT min(s.session_date) AS min
           FROM attendance_sessions s
          WHERE NOT s.is_break AND s.class_id = c.id)) AS last_session_date,
    patron_name,
    patron_photo_path
   FROM classes c;

create or replace view public.v_class_session_summary
with (security_invoker = true) as
SELECT s.id AS session_id,
    s.year_id,
    s.class_id,
    s.session_date,
    s.is_locked,
    s.notes,
    count(r.id) AS recorded_count,
    count(r.id) FILTER (WHERE r.score > 0) AS present_count,
    COALESCE(sum(r.score), 0::bigint)::integer AS points,
    COALESCE(sum(r.max_score), 0::bigint)::integer AS max_points,
    ( SELECT count(*) AS count
           FROM children ch
          WHERE ch.class_id = s.class_id AND ch.is_active) AS active_children
   FROM attendance_sessions s
     LEFT JOIN attendance_records r ON r.session_id = s.id
  WHERE NOT s.is_break
  GROUP BY s.id, s.year_id, s.class_id, s.session_date, s.is_locked, s.notes;

create or replace view public.v_session_scores
with (security_invoker = true) as
SELECT r.id AS record_id,
    s.id AS session_id,
    s.year_id,
    s.class_id,
    c.name AS class_name,
    s.session_date,
    s.is_locked,
    ch.id AS child_id,
    ch.full_name AS child_name,
    ch.gender,
    ch.is_active AS child_is_active,
    r.sunday_school,
    r.vespers,
    r.mass,
    r.confession,
    r.score,
    r.max_score,
    r.updated_at,
    r.updated_by,
    p.full_name AS updated_by_name,
    s.is_break
   FROM attendance_records r
     JOIN attendance_sessions s ON s.id = r.session_id
     JOIN classes c ON c.id = s.class_id
     JOIN children ch ON ch.id = r.child_id
     LEFT JOIN profiles p ON p.id = r.updated_by;

-- ── the functions ──────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.class_health(p_year uuid)
 RETURNS TABLE(class_id uuid, class_name text, servants_count integer, active_children integer, held integer, taken integer, taken_late integer, present_pct numeric, prep_expected integer, prep_submitted integer, prep_accepted integer, absent_2plus integer, absent_followed integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
declare
  v_today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if public.auth_role() is null then
    raise exception 'sign in to read class health' using errcode = '42501';
  end if;

  return query
  with sess as (
    select s.id, s.class_id, s.session_date,
           exists (select 1 from public.lesson_breaks b
                   where b.break_date = s.session_date) as is_break,
           (select min(r.created_at) from public.attendance_records r
             where r.session_id = s.id) as first_saved
    from public.attendance_sessions s
    where s.year_id = p_year
      and s.session_date <= v_today
  ),
  counted as (
    select * from sess where not is_break
  ),
  marks as (
    select s.class_id,
           count(r.id)                                 as marked,
           count(r.id) filter (where r.score > 0)      as present
    from counted s
    join public.attendance_records r on r.session_id = s.id
    group by s.class_id
  ),
  servants as (
    select cs.class_id, array_agg(cs.servant_id) as ids
    from public.class_servants cs
    join public.profiles p on p.id = cs.servant_id and p.is_active and not p.is_hidden
    group by cs.class_id
  ),
  preps as (
    select s.class_id,
           count(*)                                        as submitted,
           count(*) filter (where lp.status = 'accepted')  as accepted
    from counted s
    join public.servant_lesson_preps lp on lp.session_id = s.id
    join servants sv on sv.class_id = s.class_id and lp.servant_id = any (sv.ids)
    group by s.class_id
  ),
  absent as (
    select st.class_id,
           count(*) as runs,
           count(*) filter (where exists (
             select 1 from public.child_visit_logs v
             where v.child_id = st.child_id
               and v.visit_date >= coalesce(st.last_present_date, date '1900-01-01')
           )) as followed
    from public.v_child_attendance_streak st
    where st.year_id = p_year and st.absent_streak >= 2
    group by st.class_id
  )
  select
    c.id,
    c.name,
    coalesce(cardinality(sv.ids), 0)::int,
    (select count(*) from public.children ch
      where ch.class_id = c.id and ch.is_active)::int,
    (select count(*) from counted k where k.class_id = c.id)::int,
    (select count(*) from counted k
      where k.class_id = c.id and k.first_saved is not null)::int,
    (select count(*) from counted k
      where k.class_id = c.id
        and (k.first_saved at time zone 'Africa/Cairo')::date > k.session_date + 1)::int,
    case when coalesce(m.marked, 0) = 0 then null
         else round(100.0 * m.present / m.marked, 1) end,
    (coalesce(cardinality(sv.ids), 0)
      * (select count(*) from counted k
          where k.class_id = c.id and not k.is_break))::int,
    coalesce(pr.submitted, 0)::int,
    coalesce(pr.accepted, 0)::int,
    coalesce(a.runs, 0)::int,
    coalesce(a.followed, 0)::int
  from public.classes c
  left join servants sv on sv.class_id = c.id
  left join marks    m  on m.class_id  = c.id
  left join preps    pr on pr.class_id = c.id
  left join absent   a  on a.class_id  = c.id
  where c.is_active
    and (public.is_admin() or public.is_general_servant()
         or public.serves_class(c.id))
  order by c.sort_order, c.name;
end;
$function$;

CREATE OR REPLACE FUNCTION public.check_absence_alerts(p_session_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_class  uuid;
  v_year   uuid;
  v_date   date;
  v_latest date;
  v_levels integer[];
  v_actor  uuid := auth.uid();
  v_class_name text;
  v_sent   integer := 0;
  v_new    integer;
  r        record;
begin
  select s.class_id, s.year_id, s.session_date
    into v_class, v_year, v_date
  from public.attendance_sessions s
  where s.id = p_session_id;
  if v_class is null then
    return 0;
  end if;
  -- A Saturday with no lesson never raises an absence alert.
  if exists (select 1 from public.attendance_sessions s
             where s.id = p_session_id and s.is_break) then
    return 0;
  end if;
  if not (public.can_access_class(v_class) or public.is_general_servant()) then
    return 0;
  end if;

  -- Only the newest taken Saturday of the class.
  select max(s.session_date) into v_latest
  from public.attendance_sessions s
  where s.class_id = v_class
    and s.session_date <= current_date
    and not s.is_break
    and exists (select 1 from public.attendance_records r where r.session_id = s.id);
  if v_latest is distinct from v_date then
    return 0;
  end if;

  select array_agg(distinct trim(x)::integer)
    into v_levels
  from public.app_config c, unnest(string_to_array(c.value, ',')) x
  where c.key = 'absence_alert_levels' and trim(x) ~ '^\d{1,2}$';
  if v_levels is null or cardinality(v_levels) = 0 then
    v_levels := array[2, 3];
  end if;

  select name into v_class_name from public.classes where id = v_class;

  for r in
    select s.child_id, s.child_name, s.absent_streak
    from public.v_child_attendance_streak s
    where s.class_id = v_class
      and s.year_id = v_year
      and s.absent_streak = any (v_levels)
  loop
    insert into public.absence_alerts (child_id, year_id, level, last_absent_date)
    values (r.child_id, v_year, r.absent_streak, v_date)
    on conflict do nothing;
    get diagnostics v_new = row_count;
    if v_new = 0 then
      continue;
    end if;

    insert into public.notifications (user_id, kind, title, body, ref_id, child_id)
    select cs.servant_id,
           'absence_child',
           'مخدوم غايب',
           r.child_name || ' غاب ' ||
             case when r.absent_streak = 2 then 'سبتين'
                  else r.absent_streak || ' سبوت' end ||
             ' ورا بعض (فصل ' || coalesce(v_class_name, '') || '). كلّمه أو افتقده.',
           v_class,
           r.child_id
    from public.class_servants cs
    join public.profiles p
      on p.id = cs.servant_id and p.is_active and not p.is_hidden
    where cs.class_id = v_class
      and cs.servant_id is distinct from v_actor;
    v_sent := v_sent + 1;
  end loop;

  return v_sent;
end;
$function$;

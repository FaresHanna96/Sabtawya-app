-- «نشاط ترفيهي» with the children's attendance TAKEN.
--
-- Until now every no-lesson Saturday (lesson_breaks: إجازة or نشاط ترفيهي) was cut out of the
-- children's numbers and took no attendance. For a نشاط ترفيهي (a party, a trip) the admin can
-- now say the children's attendance IS taken: that day then counts for the children like a
-- normal day (طايو, levels, badges, streaks, ranking, reports) and accepts attendance.
-- إجازة never changes. The servants' numbers (servant attendance %, preps, reminders about
-- the lesson) still skip the day: there is no lesson and no prep.
--
--  * lesson_breaks.attendance_taken: only for kind 'activity', false by default.
--  * attendance_sessions.children_off: the day is out of the CHILDREN's numbers; is_break
--    keeps its meaning «no lesson» (servants, lesson programme).
--  * everything about the children now filters on children_off, or on lesson_breaks
--    except a counted activity day; the servants' objects are untouched.

-- ── the choice ───────────────────────────────────────────────────────────────
alter table public.lesson_breaks
  add column if not exists attendance_taken boolean not null default false;

alter table public.lesson_breaks
  drop constraint if exists lesson_breaks_attendance_taken_check;
alter table public.lesson_breaks
  add constraint lesson_breaks_attendance_taken_check
  check (kind = 'activity' or not attendance_taken);

-- ── the mark on the sessions ─────────────────────────────────────────────────
alter table public.attendance_sessions
  add column if not exists children_off boolean not null default false;

update public.attendance_sessions s
set children_off = exists (select 1 from public.lesson_breaks b
                           where b.break_date = s.session_date
                             and not (b.kind = 'activity' and b.attendance_taken))
where s.children_off is distinct from exists (select 1 from public.lesson_breaks b
                                              where b.break_date = s.session_date
                                                and not (b.kind = 'activity' and b.attendance_taken));

create or replace function public.attendance_sessions_mark_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.is_break := exists (select 1 from public.lesson_breaks b
                          where b.break_date = new.session_date);
  new.children_off := exists (select 1 from public.lesson_breaks b
                              where b.break_date = new.session_date
                                and not (b.kind = 'activity' and b.attendance_taken));
  return new;
end;
$$;

create or replace function public.lesson_breaks_sync_sessions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op in ('DELETE', 'UPDATE') then
    update public.attendance_sessions set is_break = false, children_off = false
    where session_date = old.break_date and (is_break or children_off);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    update public.attendance_sessions
       set is_break = true,
           children_off = not (new.kind = 'activity' and new.attendance_taken)
     where session_date = new.break_date;
  end if;
  return null;
end;
$$;

-- Attendance is refused only on a day that is out of the children's numbers.
create or replace function public.attendance_records_no_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (select 1 from public.attendance_sessions s
             where s.id = new.session_id and s.children_off) then
    raise exception 'هذا السبت إجازة أو نشاط ترفيهي: لا يُسجَّل فيه حضور'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

-- ── the children's views and functions ───────────────────────────────────────

create or replace view public.v_admin_stats with (security_invoker=true) as
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
          WHERE NOT attendance_sessions.children_off AND attendance_sessions.session_date >= CURRENT_DATE) AS next_session_date,
    ( SELECT COALESCE(sum(attendance_records.score), 0::bigint)::integer AS "coalesce"
           FROM attendance_records
             JOIN attendance_sessions bs ON bs.id = attendance_records.session_id
          WHERE NOT bs.children_off) AS total_points,
    COALESCE(( SELECT max(attendance_sessions.session_date) AS max
           FROM attendance_sessions
          WHERE NOT attendance_sessions.children_off AND attendance_sessions.session_date <= CURRENT_DATE), ( SELECT min(attendance_sessions.session_date) AS min
           FROM attendance_sessions
          WHERE NOT attendance_sessions.children_off)) AS last_session_date;

create or replace view public.v_child_activity_rates with (security_invoker=true) as
 WITH held AS (
         SELECT s.year_id,
            count(DISTINCT s.session_date)::integer AS held
           FROM attendance_sessions s
          WHERE NOT s.children_off AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id
        ), came AS (
         SELECT r.child_id,
            s.year_id,
            count(DISTINCT s.session_date) FILTER (WHERE r.sunday_school)::integer AS sunday_school,
            count(DISTINCT s.session_date) FILTER (WHERE r.vespers)::integer AS vespers,
            count(DISTINCT s.session_date) FILTER (WHERE r.mass)::integer AS mass,
            count(DISTINCT s.session_date) FILTER (WHERE r.confession)::integer AS confession
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.children_off
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

create or replace view public.v_child_attendance_streak with (security_invoker=true) as
 WITH taken AS (
         SELECT s.id AS session_id,
            s.class_id,
            s.year_id,
            s.session_date
           FROM attendance_sessions s
          WHERE s.session_date <= CURRENT_DATE AND (EXISTS ( SELECT 1
                   FROM attendance_records r
                  WHERE r.session_id = s.id)) AND NOT (EXISTS ( SELECT 1
                   FROM lesson_breaks b
                  WHERE b.break_date = s.session_date and not (b.kind = 'activity' and b.attendance_taken)))
        ), marked AS (
         SELECT ch_1.id AS child_id,
            t.year_id,
            t.session_date,
            COALESCE(r.score, 0) > 0 AS present
           FROM children ch_1
             JOIN taken t ON t.class_id = ch_1.class_id
             LEFT JOIN attendance_records r ON r.session_id = t.session_id AND r.child_id = ch_1.id
          WHERE ch_1.is_active
        ), ranked AS (
         SELECT m.child_id,
            m.year_id,
            m.session_date,
            m.present,
            row_number() OVER (PARTITION BY m.child_id, m.year_id ORDER BY m.session_date DESC) AS "position"
           FROM marked m
        ), agg AS (
         SELECT r.child_id,
            r.year_id,
            max(r."position") AS sessions,
            min(r."position") FILTER (WHERE r.present) AS first_present,
            min(r."position") FILTER (WHERE NOT r.present) AS first_absent,
            max(r.session_date) FILTER (WHERE r.present) AS last_present_date
           FROM ranked r
          GROUP BY r.child_id, r.year_id
        )
 SELECT a.child_id,
    ch.full_name AS child_name,
    ch.gender,
    ch.photo_path,
    ch.class_id,
    c.name AS class_name,
    a.year_id,
    COALESCE(a.first_present - 1, a.sessions)::integer AS absent_streak,
    COALESCE(a.first_absent - 1, a.sessions)::integer AS present_streak,
    a.last_present_date
   FROM agg a
     JOIN children ch ON ch.id = a.child_id
     JOIN classes c ON c.id = ch.class_id;

create or replace view public.v_child_attendance_trend with (security_invoker=true) as
 WITH taken AS (
         SELECT s.id AS session_id,
            s.class_id,
            s.year_id,
            s.session_date
           FROM attendance_sessions s
          WHERE s.session_date <= CURRENT_DATE AND (EXISTS ( SELECT 1
                   FROM attendance_records r
                  WHERE r.session_id = s.id)) AND NOT (EXISTS ( SELECT 1
                   FROM lesson_breaks b
                  WHERE b.break_date = s.session_date and not (b.kind = 'activity' and b.attendance_taken)))
        ), marked AS (
         SELECT ch_1.id AS child_id,
            t.year_id,
            t.session_date,
            COALESCE(r.score, 0) > 0 AS present
           FROM children ch_1
             JOIN taken t ON t.class_id = ch_1.class_id
             LEFT JOIN attendance_records r ON r.session_id = t.session_id AND r.child_id = ch_1.id
          WHERE ch_1.is_active
        ), ranked AS (
         SELECT m.child_id,
            m.year_id,
            m.session_date,
            m.present,
            row_number() OVER (PARTITION BY m.child_id, m.year_id ORDER BY m.session_date DESC) AS "position"
           FROM marked m
        ), agg AS (
         SELECT r.child_id,
            r.year_id,
            count(*) FILTER (WHERE r."position" <= 4) AS recent_held,
            count(*) FILTER (WHERE r."position" <= 4 AND r.present) AS recent_present,
            count(*) FILTER (WHERE r."position" >= 5 AND r."position" <= 8) AS previous_held,
            count(*) FILTER (WHERE r."position" >= 5 AND r."position" <= 8 AND r.present) AS previous_present
           FROM ranked r
          WHERE r."position" <= 8
          GROUP BY r.child_id, r.year_id
        )
 SELECT a.child_id,
    ch.full_name AS child_name,
    ch.class_id,
    c.name AS class_name,
    a.year_id,
    a.recent_present,
    a.previous_present,
    round(a.recent_present::numeric * 100.0 / a.recent_held::numeric) AS recent_rate,
    round(a.previous_present::numeric * 100.0 / a.previous_held::numeric) AS previous_rate,
    round(a.previous_present::numeric * 100.0 / a.previous_held::numeric) - round(a.recent_present::numeric * 100.0 / a.recent_held::numeric) AS drop_points,
    (a.previous_present::numeric * 100.0 / a.previous_held::numeric - a.recent_present::numeric * 100.0 / a.recent_held::numeric) >= 25::numeric AS is_declining
   FROM agg a
     JOIN children ch ON ch.id = a.child_id
     JOIN classes c ON c.id = ch.class_id
  WHERE a.recent_held = 4 AND a.previous_held = 4;

create or replace view public.v_child_commitment with (security_invoker=true) as
 WITH held AS (
         SELECT s_1.id AS session_id,
            s_1.class_id,
            s_1.year_id,
            s_1.session_date
           FROM attendance_sessions s_1
          WHERE NOT s_1.children_off AND s_1.session_date <= CURRENT_DATE
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

create or replace view public.v_child_last_activity with (security_invoker=true) as
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
     LEFT JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.children_off
  GROUP BY ch.id, ch.class_id;

create or replace view public.v_child_monthly_scores with (security_invoker=true) as
 WITH calendar AS (
         SELECT s.year_id,
            date_trunc('month'::text, s.session_date::timestamp with time zone)::date AS month_start,
            count(DISTINCT s.session_date) AS sessions_total,
            count(DISTINCT s.session_date) * ay.max_points_per_session AS max_points
           FROM attendance_sessions s
             JOIN attendance_years ay ON ay.id = s.year_id
          WHERE NOT s.children_off AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id, (date_trunc('month'::text, s.session_date::timestamp with time zone)), ay.max_points_per_session
        ), earned AS (
         SELECT r.child_id,
            s.year_id,
            date_trunc('month'::text, s.session_date::timestamp with time zone)::date AS month_start,
            sum(r.score)::integer AS points,
            count(*) FILTER (WHERE r.score > 0) AS sessions_attended
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.children_off
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

create or replace view public.v_child_sunday_school with (security_invoker=true) as
 WITH held AS (
         SELECT s.year_id,
            count(DISTINCT s.session_date)::integer AS held
           FROM attendance_sessions s
          WHERE NOT s.children_off AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id
        ), came AS (
         SELECT r.child_id,
            s.year_id,
            count(DISTINCT s.session_date)::integer AS came
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.children_off
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

create or replace view public.v_child_year_scores with (security_invoker=true) as
 WITH held AS (
         SELECT s.year_id,
            count(DISTINCT s.session_date) AS sessions_total,
            count(DISTINCT s.session_date) * ay.max_points_per_session AS max_points
           FROM attendance_sessions s
             JOIN attendance_years ay ON ay.id = s.year_id
          WHERE NOT s.children_off AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
          GROUP BY s.year_id, ay.max_points_per_session
        ), earned AS (
         SELECT r.child_id,
            s.year_id,
            sum(r.score)::integer AS points,
            count(*) FILTER (WHERE r.score > 0) AS sessions_attended
           FROM attendance_records r
             JOIN attendance_sessions s ON s.id = r.session_id AND NOT s.children_off
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

create or replace view public.v_class_overview with (security_invoker=true) as
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
          WHERE NOT s.children_off AND s.class_id = c.id AND s.session_date >= CURRENT_DATE) AS next_session_date,
    COALESCE(( SELECT max(s.session_date) AS max
           FROM attendance_sessions s
          WHERE NOT s.children_off AND s.class_id = c.id AND s.session_date <= CURRENT_DATE), ( SELECT min(s.session_date) AS min
           FROM attendance_sessions s
          WHERE NOT s.children_off AND s.class_id = c.id)) AS last_session_date,
    patron_name,
    patron_photo_path
   FROM classes c;

create or replace view public.v_class_session_summary with (security_invoker=true) as
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
  WHERE NOT s.children_off
  GROUP BY s.id, s.year_id, s.class_id, s.session_date, s.is_locked, s.notes;

create or replace view public.v_session_scores with (security_invoker=true) as
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
    s.children_off AS is_break
   FROM attendance_records r
     JOIN attendance_sessions s ON s.id = r.session_id
     JOIN classes c ON c.id = s.class_id
     JOIN children ch ON ch.id = r.child_id
     LEFT JOIN profiles p ON p.id = r.updated_by;

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
             where s.id = p_session_id and s.children_off) then
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
    and not s.children_off
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

CREATE OR REPLACE FUNCTION public.child_badges(p_year uuid, p_class uuid DEFAULT NULL::uuid, p_child uuid DEFAULT NULL::uuid)
 RETURNS TABLE(child_id uuid, class_id uuid, badge text, earned_on date, progress integer, target integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
with taken as (
  select s.id as session_id, s.class_id, s.session_date,
         date_trunc('month', s.session_date)::date as month
    from public.attendance_sessions s
   where s.year_id = p_year
     and (p_class is null or s.class_id = p_class)
     and s.session_date <= current_date
     and exists (select 1 from public.attendance_records r where r.session_id = s.id)
     and not exists (select 1 from public.lesson_breaks b where b.break_date = s.session_date and not (b.kind = 'activity' and b.attendance_taken))
),
kids as (
  select ch.id as child_id, ch.class_id
    from public.children ch
   where ch.is_active
     and (p_class is null or ch.class_id = p_class)
     and (p_child is null or ch.id = p_child)
),
marks as (
  select k.child_id, k.class_id, t.session_date, t.month,
         coalesce(r.score, 0) > 0              as present,
         coalesce(r.score, 0)                  as score,
         coalesce(r.mass, false)               as mass,
         coalesce(r.vespers, false)            as vespers,
         coalesce(r.confession, false)         as confession,
         coalesce(r.sunday_school and r.vespers and r.mass, false)
                                               as full_day,
         row_number() over (partition by k.child_id order by t.session_date) as n
    from kids k
    join taken t on t.class_id = k.class_id
    left join public.attendance_records r
           on r.session_id = t.session_id and r.child_id = k.child_id
),
-- The taken Saturdays newest first, to find the day a run reached 4 or 12.
recent as (
  select m.child_id, m.session_date,
         row_number() over (partition by m.child_id order by m.session_date desc) as pos
    from marks m
),
-- ملتزم / ملتزم ذهبي ARE the ملتزمين list: the run still going, read from
-- the same view (v_child_attendance_streak), so the two never disagree. The
-- badge is held while the run lasts and goes when it breaks.
streaks as (
  select k.child_id,
         coalesce(v.present_streak, 0) as current_run,
         case when v.present_streak >= 4 then
           (select r.session_date from recent r
             where r.child_id = k.child_id and r.pos = v.present_streak - 3)
         end as streak4_on,
         case when v.present_streak >= 12 then
           (select r.session_date from recent r
             where r.child_id = k.child_id and r.pos = v.present_streak - 15)
         end as streak16_on
    from kids k
    left join public.v_child_attendance_streak v
           on v.child_id = k.child_id and v.year_id = p_year
),
full_days as (
  select f.child_id,
         min(f.session_date) filter (where f.k = 5) as full_on,
         count(*)::int                              as full_count
    from (select m.child_id, m.session_date,
                 row_number() over (partition by m.child_id order by m.session_date) as k
            from marks m where m.full_day) f
   group by f.child_id
),
-- Per child and month the class met.
months as (
  select m.child_id, m.class_id, m.month,
         count(*)::int                            as saturdays,
         count(*) filter (where m.mass)::int      as masses,
         count(*) filter (where m.vespers)::int   as vesperses,
         bool_or(m.confession)                    as confessed,
         sum(m.score)::int                        as points,
         max(m.session_date)                      as last_date,
         min(m.session_date) filter (where m.confession) as first_confession,
         -- 1, 2, 3 … over the months the class met, so a month with no
         -- confession breaks a run but a summer with no Saturdays does not.
         dense_rank() over (partition by m.child_id order by m.month)::int
                                                  as month_idx
    from marks m
   group by m.child_id, m.class_id, m.month
),
-- قداسي كامل: a FINISHED month of at least three Saturdays, mass at all.
mass_months as (
  select mo.child_id,
         min(mo.last_date) filter (
           where mo.saturdays >= 3 and mo.masses = mo.saturdays
             and mo.month < date_trunc('month', current_date)::date) as mass_on
    from months mo
   group by mo.child_id
),
-- عشية: the same, with vespers instead of mass.
vespers_months as (
  select mo.child_id,
         min(mo.last_date) filter (
           where mo.saturdays >= 3 and mo.vesperses = mo.saturdays
             and mo.month < date_trunc('month', current_date)::date) as vespers_on
    from months mo
   group by mo.child_id
),
this_month as (
  select mo.child_id, mo.saturdays, mo.masses, mo.vesperses
    from months mo
   where mo.month = date_trunc('month', current_date)::date
),
-- قلب نقي: confession in three of the class's months in a row.
confession_runs as (
  select mo.child_id, mo.month, mo.first_confession,
         mo.month_idx
           - row_number() over (partition by mo.child_id order by mo.month) as island
    from months mo
   where mo.confessed
),
confession_counted as (
  select c.child_id, c.month, c.first_confession,
         row_number() over (partition by c.child_id, c.island order by c.month) as run_pos
    from confession_runs c
),
confessions as (
  select k.child_id,
         (select min(cc.first_confession) from confession_counted cc
           where cc.child_id = k.child_id and cc.run_pos = 3) as confession_on,
         -- The run still going: it reaches this month or the one before.
         coalesce((select max(cc.run_pos) from confession_counted cc
                    where cc.child_id = k.child_id
                      and cc.month >= (date_trunc('month', current_date) - interval '1 month')::date), 0)::int
                                                              as confession_run
    from kids k
),
-- نجم الشهر: the most points in the class over a FINISHED month (ties all win).
stars as (
  select mo.child_id, min(mo.last_date) as star_on
    from months mo
   where mo.month < date_trunc('month', current_date)::date
     and mo.points > 0
     and mo.points = (select max(o.points) from months o
                       where o.class_id = mo.class_id and o.month = mo.month)
   group by mo.child_id
),
-- نجم السنة: the most points in the class over the whole year, once the
-- year has ended (ties all win).
year_totals as (
  select mo.child_id, mo.class_id, sum(mo.points)::int as points,
         max(mo.last_date) as last_date
    from months mo
   group by mo.child_id, mo.class_id
),
year_stars as (
  select yt.child_id, yt.last_date as year_star_on
    from year_totals yt
   where (select y.end_date from public.attendance_years y where y.id = p_year)
           < current_date
     and yt.points > 0
     and yt.points = (select max(o.points) from year_totals o
                       where o.class_id = yt.class_id)
)
select k.child_id, k.class_id, b.badge,
       case b.badge
         when 'streak4'     then st.streak4_on
         when 'streak16'    then st.streak16_on
         when 'mass_month'  then mm.mass_on
         when 'vespers_month' then vm.vespers_on
         when 'full_day'    then fd.full_on
         when 'confession3' then cf.confession_on
         when 'star_month'  then sr.star_on
         when 'star_year'   then ys.year_star_on
         when 'star_school' then ss.earned_on
       end as earned_on,
       least(b.target, case b.badge
         when 'streak4'     then st.current_run
         when 'streak16'    then st.current_run
         when 'mass_month'  then coalesce(tm.masses, 0)
         when 'vespers_month' then coalesce(tm.vesperses, 0)
         when 'full_day'    then coalesce(fd.full_count, 0)
         when 'confession3' then cf.confession_run
         else 0
       end)::int as progress,
       case b.badge
         when 'mass_month' then greatest(coalesce(tm.saturdays, 0), 3)
         when 'vespers_month' then greatest(coalesce(tm.saturdays, 0), 3)
         else b.target
       end::int as target
  from kids k
 cross join (values ('streak4', 4), ('mass_month', 3), ('vespers_month', 3),
                    ('full_day', 5),
                    ('confession3', 3), ('star_month', 1), ('star_year', 1), ('star_school', 1),
                    ('streak16', 12))
        as b(badge, target)
  left join streaks      st on st.child_id = k.child_id
  left join full_days    fd on fd.child_id = k.child_id
  left join mass_months  mm on mm.child_id = k.child_id
  left join vespers_months vm on vm.child_id = k.child_id
  left join this_month   tm on tm.child_id = k.child_id
  left join confessions  cf on cf.child_id = k.child_id
  left join stars        sr on sr.child_id = k.child_id
  left join year_stars   ys on ys.child_id = k.child_id
  left join public.year_school_stars(p_year) ss on ss.child_id = k.child_id;
$function$;

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
                   where b.break_date = s.session_date and not (b.kind = 'activity' and b.attendance_taken)) as is_break,
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

CREATE OR REPLACE FUNCTION public.class_leaderboard(p_year uuid, p_class uuid, p_from date DEFAULT NULL::date)
 RETURNS TABLE(child_id uuid, child_name text, attendance_points integer, badges_earned integer, game_points integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
with pts as (
  select r.child_id, sum(r.score)::int as points
    from public.attendance_records r
    join public.attendance_sessions s on s.id = r.session_id
   where s.year_id = p_year
     and s.class_id = p_class
     and s.session_date <= current_date
     and (p_from is null or s.session_date >= p_from)
     and not exists (select 1 from public.lesson_breaks b
                      where b.break_date = s.session_date and not (b.kind = 'activity' and b.attendance_taken))
   group by r.child_id
),
won as (
  select b.child_id, count(*)::int as badges
    from public.child_badges(p_year, p_class) b
   where b.earned_on is not null
     and (p_from is null or b.earned_on >= p_from)
   group by b.child_id
)
select ch.id, ch.full_name,
       coalesce(p.points, 0),
       coalesce(w.badges, 0),
       coalesce(p.points, 0) + 10 * coalesce(w.badges, 0)
  from public.children ch
  left join pts p on p.child_id = ch.id
  left join won w on w.child_id = ch.id
 where ch.class_id = p_class
   and ch.is_active
 order by 5 desc, ch.full_name;
$function$;

CREATE OR REPLACE FUNCTION public.notify_missing_attendance(p_force boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_now   timestamp := now() at time zone 'Africa/Cairo';
  v_today date := v_now::date;
  v_sent  integer;
begin
  if not p_force and (extract(isodow from v_now) <> 6 or extract(hour from v_now) <> 19) then
    return 0;
  end if;
  if exists (select 1 from public.lesson_breaks where break_date = v_today and not (kind = 'activity' and attendance_taken)) then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id,
         'attendance_missing',
         'لم يُسجّل حضور اليوم',
         'لم يُسجّل حضور فصل ' || c.name || ' اليوم. سجّله قبل ما تنسى',
         c.id
  from public.attendance_sessions s
  join public.classes c on c.id = s.class_id and c.is_active
  join public.class_servants cs on cs.class_id = c.id
  join public.profiles p on p.id = cs.servant_id and p.is_active and not p.is_hidden
  where s.session_date = v_today
    and not exists (select 1 from public.attendance_records r where r.session_id = s.id)
    and not exists (
      select 1 from public.notifications n
      where n.user_id = cs.servant_id and n.kind = 'attendance_missing'
        and n.ref_id = c.id
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$function$;

CREATE OR REPLACE FUNCTION public.year_school_stars(p_year uuid)
 RETURNS TABLE(child_id uuid, earned_on date)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with totals as (
    select r.child_id, sum(coalesce(r.score, 0))::int as points,
           max(s.session_date) as last_date
      from public.attendance_sessions s
      join public.attendance_records r on r.session_id = s.id
      join public.children ch on ch.id = r.child_id and ch.is_active
     where s.year_id = p_year
       and s.session_date <= current_date
       and not exists (select 1 from public.lesson_breaks b
                        where b.break_date = s.session_date and not (b.kind = 'activity' and b.attendance_taken))
     group by r.child_id
  )
  select t.child_id, t.last_date
    from totals t
   where (select y.end_date from public.attendance_years y where y.id = p_year)
           < current_date
     and t.points > 0
     and t.points = (select max(o.points) from totals o);
$function$;

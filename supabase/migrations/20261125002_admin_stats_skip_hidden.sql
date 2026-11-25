-- The home's «الخدام» and «أمناء» counts must not include hidden accounts (a
-- test admin kept on production, see 20261112004_profiles_hidden): they are
-- already left out of the servants lists, but this view counted them.
create or replace view public.v_admin_stats with (security_invoker=true) as
 SELECT ( SELECT count(*) AS count
           FROM classes
          WHERE classes.is_active) AS classes_count,
    ( SELECT count(*) AS count
           FROM profiles
          WHERE profiles.is_active AND NOT profiles.is_hidden AND profiles.role = 'servant'::app_role) AS servants_count,
    ( SELECT count(*) AS count
           FROM profiles
          WHERE profiles.is_active AND NOT profiles.is_hidden AND profiles.role = 'admin'::app_role) AS admins_count,
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

-- «آخر مرة» of each practice must not look past today: attendance marked ahead
-- of time for a coming Saturday used to read as «اليوم».
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
     LEFT JOIN attendance_sessions s ON s.id = r.session_id
       AND NOT s.children_off
       AND s.session_date <= (now() AT TIME ZONE 'Africa/Cairo'::text)::date
  GROUP BY ch.id, ch.class_id;

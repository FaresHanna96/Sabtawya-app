-- check_absence_alerts failed with «record "r" is not assigned yet»: a subquery used the alias
-- r, which is also the loop record, so no absent-child alert was ever sent. Only the alias
-- changes; the rest of the function is as in 20261126006.

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
    and exists (select 1 from public.attendance_records rec where rec.session_id = s.id);
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
           'وحشنا ' || r.child_name,
           r.child_name || ' غاب ' ||
             case when r.absent_streak = 2 then 'سبتين'
                  else r.absent_streak || ' سبوت' end ||
             ' ورا بعض (فصل ' || coalesce(v_class_name, '') || '). كلّمه واطمن عليه ❤️',
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

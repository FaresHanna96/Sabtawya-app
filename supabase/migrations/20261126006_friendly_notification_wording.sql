-- Friendly Egyptian wording for every notification the database writes. Each function is
-- the one that was live on production on 26 Nov 2026 with only its Arabic text changed
-- (notify_prep_reviewed also words «accepted» and «commented» separately).
-- Recipients, times and triggers are as before.

CREATE OR REPLACE FUNCTION public.lesson_break_summary(p_kind text, p_shift boolean, p_attendance_taken boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select concat_ws(E'\n',
    case when p_shift
           then '• الدرس اتأجل أسبوع، واللي بعده كله هيتأخر أسبوع.'
         when p_kind = 'activity'
           then '• الدرس اتلغى، وباقي الدروس زي ما هي.'
         else '• باقي الدروس زي ما هي.' end,
    case when p_kind <> 'activity'
           then '• مفيش حضور.'
         when p_attendance_taken
           then '• هناخد حضور الأولاد وهيتحسب، وحضور الخدام كمان.'
         else '• مش هناخد حضور الأولاد، بس حضور الخدام هيتسجّل.' end);
$function$;

CREATE OR REPLACE FUNCTION public.notify_lesson_prep(p_force boolean DEFAULT false, p_today date DEFAULT NULL::date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_now       timestamp := now() at time zone 'Africa/Cairo';
  v_today     date := coalesce(p_today, v_now::date);
  v_sat       date;
  v_year      int;
  v_newyear   date;
  v_start     date;
  v_weeks     int;
  v_lesson    int;
  v_month     int;
  v_week      int;
  v_sent      integer;
  v_shift     boolean;
  v_kind      text;
  v_taken     boolean;
begin
  if not p_force and (extract(isodow from v_now) <> 5 or extract(hour from v_now) <> 17) then
    return 0;
  end if;

  v_sat := v_today + 1;
  if extract(isodow from v_sat) <> 6 then
    return 0;
  end if;
  -- Postponed or cancelled: no lesson tomorrow, so no prep reminder. The servants of
  -- the classes are told instead, once, so nobody comes in or prepares for nothing.
  select b.shift, b.kind, b.attendance_taken into v_shift, v_kind, v_taken from public.lesson_breaks b where b.break_date = v_sat;
  if found then
    insert into public.notifications (user_id, kind, title, body)
    select distinct cs.servant_id,
           'lesson_changed',
           case when v_shift then 'درس بكرة اتأجل' else 'مفيش درس بكرة' end,
           'بكرة ' || case when v_kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end
             || '، يعني مفيش تحضير النهارده 😊' || E'\n'
             || public.lesson_break_summary(v_kind, v_shift, v_taken)
    from public.class_servants cs
    join public.classes c on c.id = cs.class_id and c.is_active
    join public.profiles p on p.id = cs.servant_id and p.is_active and not p.is_hidden
    where not exists (
      select 1 from public.notifications n
      where n.user_id = cs.servant_id and n.kind = 'lesson_changed'
        and n.title = case when v_shift then 'درس بكرة اتأجل' else 'مفيش درس بكرة' end
        and n.created_at > now() - interval '20 hours'
    );
    get diagnostics v_sent = row_count;
    return v_sent;
  end if;

  v_year := extract(year from v_sat)::int;
  v_newyear := make_date(v_year, 9,
    case when (v_year + 1) % 4 = 0 and ((v_year + 1) % 100 <> 0 or (v_year + 1) % 400 = 0)
         then 12 else 11 end);
  if v_sat < v_newyear then
    v_year := v_year - 1;
    v_newyear := make_date(v_year, 9,
      case when (v_year + 1) % 4 = 0 and ((v_year + 1) % 100 <> 0 or (v_year + 1) % 400 = 0)
           then 12 else 11 end);
  end if;
  v_start := v_newyear;
  while extract(isodow from v_start) <> 6 loop
    v_start := v_start + 1;
  end loop;
  if v_sat < v_start then
    return 0;
  end if;

  v_weeks := (v_sat - v_start) / 7;
  v_lesson := v_weeks - (select count(*) from public.lesson_breaks b
                         where b.shift and b.break_date >= v_start and b.break_date < v_sat);
  if v_lesson < 0 or v_lesson >= 48 then
    return 0;
  end if;
  v_month := v_lesson / 4 + 1;
  v_week  := v_lesson % 4 + 1;

  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id,
         'lesson_prep_reminder',
         'حضّر درس بكرة 📖',
         'يلا نحضّر درس فصل ' || c.name || ': ' || l.title
           || case when l.page is not null then ' (ص ' || l.page || ')' else '' end
           || ' قبل خدمة بكرة. ربنا يبارك تعبك',
         c.id
  from public.classes c
  join public.lessons l
    on l.coptic_month = v_month and l.week = v_week
   and l.grade::text = substring(c.name from '^\s*([3-6])')
  join public.class_servants cs on cs.class_id = c.id
  join public.profiles p on p.id = cs.servant_id and p.is_active and not p.is_hidden
  where c.is_active
    and not exists (
      select 1
      from public.servant_lesson_preps sp
      join public.attendance_sessions s on s.id = sp.session_id
      where sp.servant_id = cs.servant_id and s.class_id = c.id and s.session_date = v_sat
    )
    and not exists (
      select 1 from public.notifications n
      where n.user_id = cs.servant_id and n.kind = 'lesson_prep_reminder'
        and n.ref_id = c.id
        and n.created_at > now() - interval '20 hours'
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_lesson_break()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_reason text := case when new.kind = 'activity' then 'نشاط ترفيهي 🎉' else 'إجازة 🏖️' end;
begin
  perform public.notify_servants(
    'lesson_changed',
    v_reason || ' يوم ' || to_char(new.break_date, 'YYYY-MM-DD'),
    public.lesson_break_summary(new.kind, new.shift, new.attendance_taken));
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_lesson_break_changed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed',
         'حصل تغيير: ' || case when new.kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end
           || ' يوم ' || to_char(new.break_date, 'YYYY-MM-DD'),
         public.lesson_break_summary(new.kind, new.shift, new.attendance_taken)
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_lesson_break_cleared()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed', 'الدرس رجع 👍',
         'درس يوم ' || to_char(old.break_date, 'YYYY-MM-DD')
           || ' رجع تاني: لا هيتأجل ولا هيتلغى.'
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return old;
exception when others then
  return old;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_lesson_edited()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed',
         'اتعدّل درس صف ' || new.grade,
         'درس ' || public.lesson_slot_label(new.coptic_month, new.week)
           || ' لصف ' || new.grade || ' بقى: ' || new.title
           || case when new.page is not null then ' (ص ' || new.page || ')' else '' end
  from public.profiles p
  where p.is_active and not p.is_hidden
    and (
      p.role = 'general_servant'
      or (p.role = 'servant' and exists (
            select 1
            from public.class_servants cs
            join public.classes c on c.id = cs.class_id and c.is_active
            where cs.servant_id = p.id
              and substring(c.name from '^\s*([3-6])') = new.grade::text))
    );
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_extras_edited()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed', 'المنبر والترانيم اتحدّثوا 🎵',
         'بص على المنبر والترانيم الجديدة لدرس ' || public.lesson_slot_label(new.coptic_month, new.week)
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_prep_reviewed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body, ref_id)
  values (
    new.servant_id,
    'prep_reviewed',
    case new.status when 'accepted' then 'تحضيرك اتقبل 👏' else 'فيه تعليق على تحضيرك' end,
    case when new.status = 'commented' and new.admin_comment is not null
      then new.admin_comment when new.status = 'accepted' then 'تسلم إيدك، الأمين راجع تحضيرك'
      else 'بص على تعليق الأمين على تحضيرك' end,
    new.id);
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_prep_submitted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_name text;
begin
  select full_name into v_name from public.profiles where id = new.servant_id;
  perform public.notify_admins(
    'prep_submitted', 'تحضير جديد مستنيك',
    coalesce(v_name, 'خادم') || ' بعت تحضير الدرس', new.id);
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.resubmit_prep(p_prep_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_prep public.servant_lesson_preps;
  v_name text;
begin
  select * into v_prep from public.servant_lesson_preps where id = p_prep_id;
  if v_prep.id is null or v_prep.servant_id is distinct from auth.uid() then
    raise exception 'هذا التحضير ليس لك' using errcode = '42501';
  end if;
  if v_prep.status <> 'commented' then
    raise exception 'التحضير ليس عليه تعليق ليُرسل من جديد' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.servant_lesson_prep_photos f
                 where f.prep_id = p_prep_id) then
    raise exception 'أضف ملفاً واحداً على الأقل' using errcode = 'P0001';
  end if;

  -- The comment stays, so both sides still see what was asked.
  update public.servant_lesson_preps
  set status = 'pending', reviewed_by = null, reviewed_at = null
  where id = p_prep_id;

  select full_name into v_name from public.profiles where id = v_prep.servant_id;
  perform public.notify_admins(
    'prep_submitted', 'تحضير اتعدّل ومستنيك',
    coalesce(v_name, 'خادم') || ' عدّل تحضير الدرس وبعته تاني',
    p_prep_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_attendance_taken()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_by    public.profiles;
  v_class text;
  v_class_id uuid;
  v_date  date;
  v_body  text;
begin
  select * into v_by from public.profiles where id = new.created_by;
  if v_by.id is null or v_by.role = 'admin' then
    return new;
  end if;
  select c.name, c.id, s.session_date into v_class, v_class_id, v_date
  from public.attendance_sessions s
  join public.classes c on c.id = s.class_id
  where s.id = new.session_id;

  v_body := v_by.full_name || ' سجّل حضور فصل ' || coalesce(v_class, '') ||
            ' يوم ' || to_char(v_date, 'YYYY-MM-DD');

  if not exists (
    select 1 from public.notifications n
    where n.kind = 'attendance_taken' and n.body = v_body
      and n.created_at > now() - interval '1 day'
  ) then
    perform public.notify_admins('attendance_taken', 'الحضور اتسجّل ✅', v_body, v_class_id);
  end if;
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_coservants_attendance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_class_id   uuid;
  v_class_name text;
  v_date       date;
begin
  if auth.uid() is null then return new; end if;
  select c.id, c.name, s.session_date into v_class_id, v_class_name, v_date
  from public.attendance_sessions s
  join public.classes c on c.id = s.class_id
  where s.id = new.session_id;
  if v_class_id is null or not public.actor_serves_class(v_class_id) then
    return new;
  end if;
  perform public.notify_class_servants(
    v_class_id, auth.uid(), 'attendance_taken', 'الحضور اتسجّل ✅',
    public.actor_name() || ' سجّل حضور فصل ' || v_class_name ||
      ' يوم ' || to_char(v_date, 'YYYY-MM-DD'),
    v_class_id);
  return new;
exception when others then
  return new;
end;
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
         'الحضور لسه متسجّلش',
         'حضور فصل ' || c.name || ' لسه متسجّلش النهارده. سجّله قبل ما تنسى 🙏',
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

CREATE OR REPLACE FUNCTION public.notify_absence_followup(p_force boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_now   timestamp := now() at time zone 'Africa/Cairo';
  v_today date := v_now::date;
  v_year  uuid;
  v_sent  integer := 0;
  v_part  integer;
begin
  if not p_force and (extract(isodow from v_now) <> 7 or extract(hour from v_now) <> 17) then
    return 0;
  end if;

  select id into v_year from public.attendance_years where is_current limit 1;
  if v_year is null then
    return 0;
  end if;

  create temporary table if not exists _absent (
    class_id uuid, absent bigint, names text[]
  ) on commit drop;
  truncate _absent;

  insert into _absent
  select s.class_id,
         count(*),
         (array_agg(s.child_name order by s.absent_streak desc, s.child_name))[1:3]
  from public.v_child_attendance_streak s
  where s.year_id = v_year and s.absent_streak >= 2
  group by s.class_id;

  -- A servant: each class of theirs with absent children.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id,
         'absence_followup',
         'يلا نفتقدهم ❤️',
         'فصل ' || cl.name || ': ' ||
           case when a.absent = 1 then 'مخدوم واحد غايب'
                when a.absent = 2 then 'مخدومين غايبين'
                when a.absent <= 10 then a.absent || ' مخدومين غايبين'
                else a.absent || ' مخدوم غايبين'
           end || ' سبتين أو أكتر ورا بعض (' || array_to_string(a.names, '، ') ||
           case when a.absent > 3 then ' وغيرهم' else '' end || '). نطمن عليهم الأسبوع ده.',
         cl.id
  from public.class_servants cs
  join public.classes cl on cl.id = cs.class_id and cl.is_active
  join _absent a on a.class_id = cl.id
  join public.profiles p
    on p.id = cs.servant_id and p.is_active and not p.is_hidden
       and p.role = 'servant'
  where not exists (
    select 1 from public.notifications n
    where n.user_id = cs.servant_id and n.kind = 'absence_followup'
      and n.ref_id = cl.id
      and (n.created_at at time zone 'Africa/Cairo')::date = v_today
  );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  -- An admin or the general servant: the whole service.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id,
         'absence_followup',
         'يلا نفتقدهم ❤️',
         'في الخدمة ' ||
           case when t.absent = 1 then 'مخدوم واحد غايب'
                when t.absent = 2 then 'مخدومين غايبين'
                when t.absent <= 10 then t.absent || ' مخدومين غايبين'
                else t.absent || ' مخدوم غايبين'
           end || ' سبتين أو أكتر ورا بعض.',
         null
  from public.profiles p
  cross join (select coalesce(sum(absent), 0) as absent from _absent) t
  where p.is_active and not p.is_hidden
    and p.role in ('admin', 'general_servant')
    and t.absent > 0
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id and n.kind = 'absence_followup'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  return v_sent;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_missing_child_info(p_force boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_now   timestamp := now() at time zone 'Africa/Cairo';
  v_today date := v_now::date;
  v_sent  integer := 0;
  v_part  integer;
begin
  if not p_force and (extract(isodow from v_now) <> 6 or extract(hour from v_now) <> 17) then
    return 0;
  end if;

  create temporary table if not exists _gaps (
    class_id uuid, no_birth bigint, any_gap bigint
  ) on commit drop;
  truncate _gaps;

  insert into _gaps
  select class_id,
         count(*) filter (where no_birth),
         count(*) filter (where any_gap)
  from (
    select c.class_id,
           c.birth_date is null as no_birth,
           (c.birth_date is null
            or (coalesce(btrim(c.mobile), '') = ''
                and coalesce(btrim(c.mother_mobile), '') = ''
                and coalesce(btrim(c.father_mobile), '') = '')
            or coalesce(btrim(c.mother_name), '') = ''
            or coalesce(btrim(c.father_name), '') = ''
            or coalesce(btrim(c.confession_father), '') = ''
            or coalesce(btrim(c.school), '') = ''
            or coalesce(btrim(c.address), '') = '') as any_gap
    from public.children c
    where c.is_active
  ) g
  group by class_id;

  -- A servant: their own class.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id,
         'missing_info',
         'فيه بيانات ناقصة 📝',
         'فصل ' || cl.name || ': ' ||
           case when g.no_birth > 0
             then g.no_birth || ' مخدوم ناقص تاريخ الميلاد' ||
                  case when g.any_gap > g.no_birth
                       then ' و' || (g.any_gap - g.no_birth) || ' ناقص بيانات تانية'
                       else '' end
             else g.any_gap || ' مخدوم ناقص بيانات'
           end || '. يلا نكمّلها النهارده.',
         cl.id
  from public.class_servants cs
  join public.classes cl on cl.id = cs.class_id and cl.is_active
  join _gaps g on g.class_id = cl.id and g.any_gap > 0
  join public.profiles p
    on p.id = cs.servant_id and p.is_active and not p.is_hidden
       and p.role = 'servant'
  where not exists (
    select 1 from public.notifications n
    where n.user_id = cs.servant_id and n.kind = 'missing_info'
      and (n.created_at at time zone 'Africa/Cairo')::date = v_today
  );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  -- An admin or the general servant: the whole service.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id,
         'missing_info',
         'فيه بيانات ناقصة 📝',
         'في الخدمة ' ||
           case when t.no_birth > 0
             then t.no_birth || ' مخدوم ناقص تاريخ الميلاد' ||
                  case when t.any_gap > t.no_birth
                       then ' و' || (t.any_gap - t.no_birth) || ' ناقص بيانات تانية'
                       else '' end
             else t.any_gap || ' مخدوم ناقص بيانات'
           end || '. يلا نكمّلها النهارده.',
         null
  from public.profiles p
  cross join (
    select coalesce(sum(no_birth), 0) as no_birth, coalesce(sum(any_gap), 0) as any_gap
    from _gaps
  ) t
  where p.is_active and not p.is_hidden
    and p.role in ('admin', 'general_servant')
    and t.any_gap > 0
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id and n.kind = 'missing_info'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  return v_sent;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_birthdays()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_today    date := (now() at time zone 'Africa/Cairo')::date;
  v_year     int  := extract(year from v_today);
  v_leap     boolean := (v_year % 4 = 0 and v_year % 100 <> 0) or v_year % 400 = 0;
  v_children text;
  v_servants text;
  v_body     text;
begin
  select string_agg(full_name, '، ' order by full_name) into v_children
  from public.children
  where is_active and birth_date is not null
    and (
      (extract(month from birth_date) = extract(month from v_today)
       and extract(day from birth_date) = extract(day from v_today))
      or (not v_leap and extract(month from birth_date) = 2
          and extract(day from birth_date) = 29
          and extract(month from v_today) = 2 and extract(day from v_today) = 28)
    );

  select string_agg(full_name, '، ' order by full_name) into v_servants
  from public.profiles
  where is_active and role in ('servant', 'general_servant') and birth_date is not null
    and (
      (extract(month from birth_date) = extract(month from v_today)
       and extract(day from birth_date) = extract(day from v_today))
      or (not v_leap and extract(month from birth_date) = 2
          and extract(day from birth_date) = 29
          and extract(month from v_today) = 2 and extract(day from v_today) = 28)
    );

  if v_children is null and v_servants is null then
    return;
  end if;

  v_body := concat_ws(E'\n',
    case when v_children is not null then 'المخدومين: ' || v_children end,
    case when v_servants is not null then 'الخدام: ' || v_servants end,
    'متنساش تعيّد عليهم');

  -- One digest per admin per day, even if the job runs twice.
  insert into public.notifications (user_id, kind, title, body)
  select a.id, 'birthdays', 'عيد ميلاد النهارده 🎂', v_body
  from public.profiles a
  where a.role = 'admin' and a.is_active
    and not exists (
      select 1 from public.notifications n
      where n.user_id = a.id and n.kind = 'birthdays'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_servant_birthdays()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_today date := (now() at time zone 'Africa/Cairo')::date;
  v_year  int  := extract(year from v_today);
  v_leap  boolean := (v_year % 4 = 0 and v_year % 100 <> 0) or v_year % 400 = 0;
begin
  insert into public.notifications (user_id, kind, title, body)
  select s.id, 'birthdays', 'عيد ميلاد النهارده 🎂',
         concat_ws(E'\n',
           case when kids.names is not null then 'المخدومين: ' || kids.names end,
           case when peers.names is not null then 'الخدام: ' || peers.names end,
           'متنساش تعيّد عليهم')
  from public.profiles s
  left join lateral (
    select string_agg(ch.full_name, '، ' order by ch.full_name) as names
    from public.children ch
    where ch.is_active and ch.birth_date is not null
      and (s.role = 'general_servant'
           or ch.class_id in (select class_id from public.class_servants where servant_id = s.id))
      and (
        (extract(month from ch.birth_date) = extract(month from v_today)
         and extract(day from ch.birth_date) = extract(day from v_today))
        or (not v_leap and extract(month from ch.birth_date) = 2
            and extract(day from ch.birth_date) = 29
            and extract(month from v_today) = 2 and extract(day from v_today) = 28)
      )
  ) kids on true
  left join lateral (
    select string_agg(o.full_name, '، ' order by o.full_name) as names
    from public.profiles o
    where o.is_active and o.id <> s.id
      and o.role in ('servant', 'general_servant') and o.birth_date is not null
      and (
        (extract(month from o.birth_date) = extract(month from v_today)
         and extract(day from o.birth_date) = extract(day from v_today))
        or (not v_leap and extract(month from o.birth_date) = 2
            and extract(day from o.birth_date) = 29
            and extract(month from v_today) = 2 and extract(day from v_today) = 28)
      )
  ) peers on true
  where s.is_active and s.role in ('servant', 'general_servant')
    and (kids.names is not null or peers.names is not null)
    and not exists (
      select 1 from public.notifications n
      where n.user_id = s.id and n.kind = 'birthdays'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_child_added()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_by    public.profiles;
  v_class text;
begin
  select * into v_by from public.profiles where id = new.created_by;
  if v_by.id is null or v_by.role = 'admin' then
    return new;
  end if;
  select name into v_class from public.classes where id = new.class_id;
  perform public.notify_admins(
    'child_added', 'مخدوم جديد نوّرنا 🌟',
    v_by.full_name || ' ضاف ' || new.full_name || coalesce(' في فصل ' || v_class, ''),
    new.id);
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_coservants_child()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_who   text;
  v_new_class text;
  v_old_class text;
begin
  if v_actor is null then return new; end if;
  v_who := public.actor_name();

  if tg_op = 'INSERT' then
    if public.actor_serves_class(new.class_id) then
      perform public.notify_class_servants(
        new.class_id, v_actor, 'child_added', 'مخدوم جديد نوّرنا 🌟',
        v_who || ' ضاف ' || new.full_name || ' في فصلكم', new.id);
    end if;
    return new;
  end if;

  if new.class_id is distinct from old.class_id then
    if public.actor_serves_class(old.class_id)
       or public.actor_serves_class(new.class_id) then
      select name into v_new_class from public.classes where id = new.class_id;
      select name into v_old_class from public.classes where id = old.class_id;
      -- The old class can no longer open the child: its notice opens the class.
      perform public.notify_class_servants(
        old.class_id, v_actor, 'class_activity', 'جديد في فصلك 👀',
        v_who || ' نقل ' || new.full_name || ' لفصل ' || coalesce(v_new_class, ''),
        old.class_id);
      perform public.notify_class_servants(
        new.class_id, v_actor, 'class_activity', 'جديد في فصلك 👀',
        v_who || ' نقل ' || new.full_name || ' من فصل ' || coalesce(v_old_class, '') ||
          ' لفصلكم',
        new.class_id, null, new.id);
    end if;
    return new;
  end if;

  if not public.actor_serves_class(new.class_id) then return new; end if;

  if new.is_active is distinct from old.is_active then
    perform public.notify_class_servants(
      new.class_id, v_actor, 'class_activity', 'جديد في فصلك 👀',
      v_who || case when new.is_active then ' رجّع ' else ' وقّف ' end ||
        new.full_name,
      new.class_id, null, new.id);
    return new;
  end if;

  -- The columns a servant edits (not the visit dates, which the visit entries
  -- below announce, and not the stamps and the code the database sets).
  if (old.full_name, old.gender, old.birth_date, old.mobile, old.mother_name,
      old.mother_mobile, old.father_name, old.father_mobile,
      old.confession_father, old.is_deacon, old.school, old.address, old.notes,
      old.photo_path)
     is distinct from
     (new.full_name, new.gender, new.birth_date, new.mobile, new.mother_name,
      new.mother_mobile, new.father_name, new.father_mobile,
      new.confession_father, new.is_deacon, new.school, new.address, new.notes,
      new.photo_path) then
    perform public.notify_class_servants(
      new.class_id, v_actor, 'class_activity', 'جديد في فصلك 👀',
      v_who || ' عدّل بيانات ' || new.full_name, new.class_id,
      v_who || ' عدّل بيانات', new.id);
  end if;
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_coservants_class()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null or not public.actor_serves_class(new.id) then
    return new;
  end if;
  if (old.name, old.description, old.patron_name, old.patron_photo_path)
     is distinct from
     (new.name, new.description, new.patron_name, new.patron_photo_path) then
    perform public.notify_class_servants(
      new.id, auth.uid(), 'class_activity', 'جديد في فصلك 👀',
      public.actor_name() || ' عدّل بيانات الفصل', new.id,
      public.actor_name() || ' عدّل بيانات الفصل');
  end if;
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_coservants_visit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_name  text;
  v_class uuid;
begin
  if auth.uid() is null then return new; end if;
  select full_name, class_id into v_name, v_class
  from public.children where id = new.child_id;
  if v_class is null or not public.actor_serves_class(v_class) then
    return new;
  end if;
  perform public.notify_class_servants(
    v_class, auth.uid(), 'class_activity', 'جديد في فصلك 👀',
    public.actor_name() || ' سجّل افتقاد ' ||
      case new.visit_type when 'phone' then '(اتصال)' else '(زيارة)' end ||
      ' لـ ' || v_name,
    v_class, null, new.child_id);
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_class_assigned()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_class text;
begin
  select name into v_class from public.classes where id = new.class_id;
  insert into public.notifications (user_id, kind, title, body, ref_id)
  values (new.servant_id, 'class_assigned', 'بقيت في فصل جديد 🙌',
          'إنت دلوقتي من خدام فصل ' || coalesce(v_class, '') || '. ربنا يبارك خدمتك', new.class_id);
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_class_removed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_class text;
begin
  -- When the whole account is being deleted there is nobody left to tell.
  if not exists (select 1 from public.profiles where id = old.servant_id) then
    return old;
  end if;
  select name into v_class from public.classes where id = old.class_id;
  insert into public.notifications (user_id, kind, title, body)
  values (old.servant_id, 'class_removed', 'تغيير في فصلك',
          'مبقتش من خدام فصل ' || coalesce(v_class, '') || '. شكرًا على تعبك ❤️');
  return old;
exception when others then
  return old;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_admins_of_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  perform public.notify_admins(
    'signup', 'طلب انضمام جديد 👋',
    new.full_name || ' عايز ينضم للخدمة');
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_servant_of_decision()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_accepted boolean := new.is_active and new.rejected_at is null;
begin
  insert into public.notifications (user_id, kind, title, body)
  values (
    new.id,
    'decision',
    case when v_accepted then 'أهلًا بيك في الخدمة 🎉' else 'بخصوص طلب الانضمام' end,
    case when v_accepted
      then 'طلبك اتقبل، تقدر تسجّل الدخول دلوقتي'
      else 'طلبك متقبلش المرة دي، كلّم أمين الخدمة' end);
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_event_added()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  perform public.notify_servants(
    'event_added', 'نشاط جديد 🎉',
    new.title || ' — ' || to_char(new.event_date, 'YYYY-MM-DD'));
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_events_today(p_force boolean DEFAULT false)
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
  if not p_force and extract(hour from v_now) <> 6 then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id,
         'event_today',
         'نشاطنا النهارده 🎉',
         e.title || coalesce(' — ' || nullif(left(btrim(e.description), 120), ''), ''),
         e.id
  from public.events e
  cross join public.profiles p
  where e.event_date = v_today
    and p.is_active
    and not p.is_hidden
    and p.role in ('admin', 'servant', 'general_servant')
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id and n.kind = 'event_today' and n.ref_id = e.id
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_competition_added()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body)
  select id, 'competition_added', 'مسابقة جديدة 🏆',
         new.title || ' — ' || to_char(new.week_date, 'YYYY-MM-DD')
  from public.profiles
  where is_active and role = 'general_servant';
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_update_on_activation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_version text;
  v_build   integer;
  v_until   date;
  v_body    text;
begin
  if not new.is_active or new.is_hidden then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.is_active then
    return new;
  end if;

  select nullif(value, '') into v_version from public.app_config where key = 'latest_app_version';
  select nullif(value, '')::integer into v_build from public.app_config where key = 'latest_app_build';
  select nullif(value, '')::date into v_until from public.app_config where key = 'update_reminder_until';
  if v_version is null or v_until is null or (now() at time zone 'Africa/Cairo')::date > v_until then
    return new;
  end if;
  if v_build is not null and exists (
       select 1 from public.user_app_builds b where b.user_id = new.id and b.build >= v_build) then
    return new;
  end if;

  v_body := 'دوس هنا ونزّل النسخة ' || v_version || '. لازم التحديث عشان التطبيق يفضل شغال.';
  if not exists (select 1 from public.notifications n
                 where n.user_id = new.id and n.kind = 'app_update' and n.body = v_body) then
    insert into public.notifications (user_id, kind, title, body)
    values (new.id, 'app_update', 'فيه تحديث جديد لسبتاوية ✨', v_body);
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_update_reminder(p_force boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_now     timestamp := now() at time zone 'Africa/Cairo';
  v_version text;
  v_build   integer;
  v_until   date;
  v_sent    integer := 0;
begin
  if not p_force and (extract(isodow from v_now) <> 5 or extract(hour from v_now) <> 19) then
    return 0;
  end if;

  select nullif(value, '') into v_version from public.app_config where key = 'latest_app_version';
  select nullif(value, '')::date into v_until from public.app_config where key = 'update_reminder_until';
  select nullif(value, '')::integer into v_build from public.app_config where key = 'latest_app_build';
  if v_version is null or v_until is null or v_now::date > v_until then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body)
  select p.id,
         'app_update_reminder',
         'فكّرناك: حدّث سبتاوية 🔔',
         case
           when d.android then
             'نزّل النسخة ' || v_version || ' عشان التطبيق يفضل شغال. دوس هنا وحدّثه.'
           when d.web then
             'افتح سبتاوية من أيقونتها على الشاشة الرئيسية وهتتحدّث لوحدها للنسخة ' || v_version || '. لو مش عندك، ضيفها من سفاري.'
           else
             'حدّث سبتاوية للنسخة ' || v_version || ': أندرويد من sabtawya.vercel.app/apk.html، وآيفون افتح الموقع وضيفه للشاشة الرئيسية.'
         end
  from public.profiles p
  left join lateral (
    select coalesce(bool_or(t.platform = 'android'), false) as android,
           coalesce(bool_or(t.platform <> 'android'), false) as web
    from public.device_tokens t
    where t.user_id = p.id
  ) d on true
  where p.is_active and not p.is_hidden
    and not exists (
      select 1 from public.user_app_builds b
      where b.user_id = p.id and v_build is not null and b.build >= v_build
    )
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id
        and n.kind in ('app_update', 'app_update_reminder')
        and n.created_at > now() - interval '1 day'
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$function$;

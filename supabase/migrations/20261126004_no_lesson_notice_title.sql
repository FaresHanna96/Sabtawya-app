-- The Friday no-lesson notice title is «مفيش درس بكرة» (it was «لا درس بكرة»). Only the
-- title changes; the rest of the function is as in 20261126003.

create or replace function public.notify_lesson_prep(
  p_force boolean default false,
  p_today date default null
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
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
  select b.shift, b.kind into v_shift, v_kind from public.lesson_breaks b where b.break_date = v_sat;
  if found then
    insert into public.notifications (user_id, kind, title, body)
    select distinct cs.servant_id,
           'lesson_changed',
           case when v_shift then 'درس بكرة مؤجل' else 'مفيش درس بكرة' end,
           'بكرة ' || case when v_kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end
             || '، فمفيش تحضير للدرس الجمعة دي.'
             || case when v_shift then ' الدروس بعده تتأجل أسبوع.' else '' end
    from public.class_servants cs
    join public.classes c on c.id = cs.class_id and c.is_active
    join public.profiles p on p.id = cs.servant_id and p.is_active and not p.is_hidden
    where not exists (
      select 1 from public.notifications n
      where n.user_id = cs.servant_id and n.kind = 'lesson_changed'
        and n.title = case when v_shift then 'درس بكرة مؤجل' else 'مفيش درس بكرة' end
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
         'حضّر درس بكرة',
         'حضّر درس فصل ' || c.name || ': ' || l.title
           || case when l.page is not null then ' (ص ' || l.page || ')' else '' end
           || ' قبل خدمة بكرة',
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
$$;

revoke all on function public.notify_lesson_prep(boolean, date) from public, anon, authenticated;

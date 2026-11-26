-- Every notice about a no-lesson Saturday now sums up what was chosen for it in the
-- «فيه درس السبت ده؟» sheet: the kind of day, what happens to the lesson, and whether
-- attendance is taken. Used by the notice for a new day, the one for a changed day and
-- the Friday 5 PM notice.
--
-- A change of several settings in one save now sends one notice (it sent one per
-- setting), and a change of the kind of day is announced too.

create or replace function public.lesson_break_summary(
  p_kind text, p_shift boolean, p_attendance_taken boolean
) returns text
language sql
immutable
as $$
  select concat_ws(E'\n',
    case when p_shift
           then '• الدرس اتأجل أسبوع، والدروس اللي بعده تتأخر أسبوع.'
         when p_kind = 'activity'
           then '• الدرس اتلغى، وباقي الدروس في مواعيدها.'
         else '• باقي الدروس في مواعيدها.' end,
    case when p_kind <> 'activity'
           then '• مفيش حضور.'
         when p_attendance_taken
           then '• حضور الأطفال هيتسجّل ويتحسب، وحضور الخدام كمان.'
         else '• حضور الأطفال مش هيتسجّل، وحضور الخدام بيتسجّل.' end);
$$;

create or replace function public.notify_lesson_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reason text := case when new.kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end;
begin
  perform public.notify_servants(
    'lesson_changed',
    v_reason || ' يوم ' || to_char(new.break_date, 'YYYY-MM-DD'),
    public.lesson_break_summary(new.kind, new.shift, new.attendance_taken));
  return new;
exception when others then
  return new;
end;
$$;

create or replace function public.notify_lesson_break_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed',
         'تغيير: ' || case when new.kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end
           || ' يوم ' || to_char(new.break_date, 'YYYY-MM-DD'),
         public.lesson_break_summary(new.kind, new.shift, new.attendance_taken)
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$$;

-- One trigger for any of the three settings.
drop trigger if exists lesson_breaks_notify_attendance on public.lesson_breaks;
drop function if exists public.notify_lesson_break_attendance();
drop trigger if exists lesson_breaks_notify_change on public.lesson_breaks;
create trigger lesson_breaks_notify_change
  after update of kind, shift, attendance_taken on public.lesson_breaks
  for each row
  when ((old.kind, old.shift, old.attendance_taken)
        is distinct from (new.kind, new.shift, new.attendance_taken))
  execute function public.notify_lesson_break_changed();

revoke all on function public.lesson_break_summary(text, boolean, boolean),
  public.notify_lesson_break(), public.notify_lesson_break_changed()
  from public, anon, authenticated;


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
           case when v_shift then 'درس بكرة مؤجل' else 'مفيش درس بكرة' end,
           'بكرة ' || case when v_kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end
             || '، فمفيش تحضير للدرس الجمعة دي.' || E'\n'
             || public.lesson_break_summary(v_kind, v_shift, v_taken)
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

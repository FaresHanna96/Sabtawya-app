-- Friday 5 PM (Cairo): every servant is reminded to prepare tomorrow's lesson, one
-- reminder per class they serve, naming that class's lesson (title and page).
--
-- Skipped for the whole week when tomorrow's Saturday is in lesson_breaks (the lesson
-- is postponed or cancelled). Skipped for a servant who already submitted the prep for
-- that class's session. One reminder per servant and class per Friday (none within 20 hours of the last).
--
-- Which lesson a Saturday has follows the app (LessonProgramme.slotOn): lesson 1 is the
-- first Saturday on or after 1 Tout (11 September, 12 in the year before a leap year),
-- every later Saturday takes the next lesson, a postponed week (shift = true) keeps its
-- lesson for the next week, a cancelled one (shift = false) drops it, 4 weeks to a
-- Coptic month, 48 lessons. A class's grade is the leading digit of its name.
--
-- pg_cron runs in UTC, so the job runs at 14:00 and 15:00 UTC on Fridays and acts only
-- in Cairo's 5 PM hour. p_force skips the day and hour check; p_today sets the Friday
-- for testing. The kind is 'lesson_prep_reminder' (older apps just mark it read).

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
begin
  if not p_force and (extract(isodow from v_now) <> 5 or extract(hour from v_now) <> 17) then
    return 0;
  end if;

  v_sat := v_today + 1;
  if extract(isodow from v_sat) <> 6 then
    return 0;
  end if;
  -- Postponed or cancelled: no lesson tomorrow, nothing to prepare.
  if exists (select 1 from public.lesson_breaks where break_date = v_sat) then
    return 0;
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

select cron.unschedule('friday-lesson-prep')
where exists (select 1 from cron.job where jobname = 'friday-lesson-prep');

select cron.schedule('friday-lesson-prep', '0 14,15 * * 5',
                     'select public.notify_lesson_prep()');

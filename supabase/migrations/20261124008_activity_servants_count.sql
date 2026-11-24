-- «نشاط ترفيهي»: the servants' attendance counts, the prep does not.
--
-- On a نشاط ترفيهي (any, whatever the children's choice) the servants' attendance
-- (خدمة، اجتماع، قدّاس، اعتراف) can be marked and counts like on a normal Saturday;
-- there is no lesson, so no prep is expected or counted. An إجازة still counts for
-- nothing. (Children: 20261124006.)
--
--  * attendance_sessions.servants_off: the day is out of the servants' attendance
--    numbers (a holiday). is_break keeps meaning «no lesson» (preps, programme).
--  * servant_activity_summary counts a نشاط ترفيهي day for the four activities.
--  * the notice for a no-lesson day says what is taken that day.

alter table public.attendance_sessions
  add column if not exists servants_off boolean not null default false;

update public.attendance_sessions s
set servants_off = exists (select 1 from public.lesson_breaks b
                           where b.break_date = s.session_date and b.kind = 'holiday')
where s.servants_off is distinct from exists (select 1 from public.lesson_breaks b
                           where b.break_date = s.session_date and b.kind = 'holiday');

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
  new.servants_off := exists (select 1 from public.lesson_breaks b
                              where b.break_date = new.session_date
                                and b.kind = 'holiday');
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
    update public.attendance_sessions
       set is_break = false, children_off = false, servants_off = false
     where session_date = old.break_date
       and (is_break or children_off or servants_off);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    update public.attendance_sessions
       set is_break = true,
           children_off = not (new.kind = 'activity' and new.attendance_taken),
           servants_off = (new.kind = 'holiday')
     where session_date = new.break_date;
  end if;
  return null;
end;
$$;

create or replace function public.servant_activity_summary(p_from date, p_to date)
returns table (
  servant_id      uuid,
  servant_name    text,
  role            text,
  classes_count   integer,
  sunday_school   integer,
  servant_meeting integer,
  mass            integer,
  confession      integer,
  preps_total     integer,
  preps_pending   integer,
  preps_accepted  integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'للأدمن فقط' using errcode = '42501';
  end if;

  return query
  select p.id,
         p.full_name::text,
         p.role::text,
         (select count(*)::int from public.class_servants cs
           where cs.servant_id = p.id),
         coalesce(a.sunday_school, 0),
         coalesce(a.servant_meeting, 0),
         coalesce(a.mass, 0),
         coalesce(a.confession, 0),
         coalesce(pr.total, 0),
         coalesce(pr.pending, 0),
         coalesce(pr.accepted, 0)
  from public.profiles p
  left join lateral (
    select count(*) filter (where sa.activity_type = 'sunday_school')::int   as sunday_school,
           count(*) filter (where sa.activity_type = 'servant_meeting')::int as servant_meeting,
           count(*) filter (where sa.activity_type = 'mass')::int            as mass,
           count(*) filter (where sa.activity_type = 'confession')::int      as confession,
           count(*)::int as any_mark
    from public.servant_attendances sa
    where sa.servant_id = p.id
      and sa.date between p_from and p_to
      -- a holiday counts for nothing; a نشاط ترفيهي counts for the four
      -- activities but there is no prep that day
      and not exists (select 1 from public.lesson_breaks b
                      where b.break_date = sa.date
                        and (b.kind = 'holiday' or sa.activity_type = 'lesson_prep'))
  ) a on true
  left join lateral (
    select (select count(*)::int from (
              select s.session_date as d
                from public.servant_lesson_preps lp
                join public.attendance_sessions s on s.id = lp.session_id
               where lp.servant_id = p.id
                 and s.session_date between p_from and p_to
                 and not s.is_break
              union
              select sa.date
                from public.servant_attendances sa
               where sa.servant_id = p.id
                 and sa.activity_type = 'lesson_prep'
                 and sa.date between p_from and p_to
                 and not exists (select 1 from public.lesson_breaks b
                                  where b.break_date = sa.date)
            ) u)                                                  as total,
           count(*) filter (where lp.status = 'pending')::int     as pending,
           count(*) filter (where lp.status = 'accepted')::int    as accepted
    from public.servant_lesson_preps lp
    join public.attendance_sessions s on s.id = lp.session_id
    where lp.servant_id = p.id
      and s.session_date between p_from and p_to
      and not s.is_break
  ) pr on true
  where (p.role::text in ('servant', 'general_servant')
         and p.is_active and not coalesce(p.is_hidden, false))
     or coalesce(a.any_mark, 0) > 0
     or coalesce(pr.total, 0) > 0
  order by p.full_name;
end;
$$;

revoke all on function public.servant_activity_summary(date, date) from public, anon;
grant execute on function public.servant_activity_summary(date, date) to authenticated;

-- The notice for a new no-lesson day says what is taken that day.
create or replace function public.notify_lesson_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reason text := case when new.kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end;
  v_lessons text := case when new.shift
    then 'الدروس بعده تتأجل أسبوع.'
    else 'باقي الدروس في مواعيدها.' end;
begin
  perform public.notify_servants(
    'lesson_changed',
    v_reason || ' يوم ' || to_char(new.break_date, 'YYYY-MM-DD'),
    case
      when new.kind = 'activity' and new.attendance_taken
        then 'مفيش درس ولا تحضير، لكن حضور الأطفال والخدام بيتسجّل وبيتحسب يومها. ' || v_lessons
      when new.kind = 'activity'
        then 'مفيش درس ولا تحضير. حضور الخدام بيتسجّل، وحضور الأطفال مش بيتسجّل. ' || v_lessons
      else 'مفيش درس ولا حضور يومها. ' || v_lessons end);
  return new;
exception when others then
  return new;
end;
$$;

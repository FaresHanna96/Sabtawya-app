-- «تحضير الدرس» in the admin's servant activity list counted only the preps a
-- servant UPLOADED. A prep the admin ticked by hand (servant_attendances,
-- activity_type 'lesson_prep') showed as 0. Now a Saturday has a prep when
-- either exists, counted once per Saturday; a no-lesson Saturday counts for
-- nothing. preps_pending / preps_accepted still follow uploaded preps only.
-- Everything else is unchanged from 20261121005.

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
      and not exists (select 1 from public.lesson_breaks b
                      where b.break_date = sa.date)
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

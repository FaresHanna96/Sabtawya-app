-- صحة الفصول: one row per active class for أمين الخدمة's dashboard, over the
-- whole attendance year up to today (Cairo), so classes that need support
-- stand out. The app turns these numbers into green / amber / red.
--
-- Counted Saturdays: the class's sessions up to today, except a Saturday with
-- no lesson (lesson_breaks) on which nothing was recorded; the attendance
-- reminder skips those days too, so they must not count as "not taken".
--
--   taken          Saturdays with at least one mark
--   taken_late     of those, first saved more than a day after the Saturday
--   present_pct    present / marked over the taken Saturdays
--   prep_expected  servants now in the class x Saturdays that had a lesson
--   prep_submitted preps those servants sent for this class's Saturdays
--   prep_accepted  of those, accepted
--   absent_2plus   active children absent the last 2+ taken Saturdays
--   absent_followed of those, with a call or visit logged since they last came
--
-- Admin only: it reads every servant's preps, which their own policy hides.

create or replace function public.class_health(p_year uuid)
returns table (
  class_id        uuid,
  class_name      text,
  servants_count  int,
  active_children int,
  held            int,
  taken           int,
  taken_late      int,
  present_pct     numeric,
  prep_expected   int,
  prep_submitted  int,
  prep_accepted   int,
  absent_2plus    int,
  absent_followed int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if not public.is_admin() then
    raise exception 'only the admin can read class health' using errcode = '42501';
  end if;

  return query
  with sess as (
    select s.id, s.class_id, s.session_date,
           exists (select 1 from public.lesson_breaks b
                   where b.break_date = s.session_date) as is_break,
           (select min(r.created_at) from public.attendance_records r
             where r.session_id = s.id) as first_saved
    from public.attendance_sessions s
    where s.year_id = p_year
      and s.session_date <= v_today
  ),
  counted as (
    select * from sess where not is_break or first_saved is not null
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
  order by c.sort_order, c.name;
end;
$$;

revoke all on function public.class_health(uuid) from public, anon;
grant execute on function public.class_health(uuid) to authenticated;

-- «يوم كامل» no longer needs confession: Sunday school, vespers and mass on
-- the same Saturday, 5 times. (Confession has its own badge, «قلب نقي».)
-- «ملتزم ذهبي» now comes at a run of 12 Saturdays instead of 16 (the badge
-- id stays streak16 so stored data and the app keep matching).
-- Everything else in child_badges is unchanged from 20261123003.

create or replace function public.child_badges(
  p_year  uuid,
  p_class uuid default null,
  p_child uuid default null
)
returns table (
  child_id  uuid,
  class_id  uuid,
  badge     text,
  earned_on date,
  progress  int,
  target    int
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
with taken as (
  select s.id as session_id, s.class_id, s.session_date,
         date_trunc('month', s.session_date)::date as month
    from public.attendance_sessions s
   where s.year_id = p_year
     and (p_class is null or s.class_id = p_class)
     and s.session_date <= current_date
     and exists (select 1 from public.attendance_records r where r.session_id = s.id)
     and not exists (select 1 from public.lesson_breaks b where b.break_date = s.session_date)
),
kids as (
  select ch.id as child_id, ch.class_id
    from public.children ch
   where ch.is_active
     and (p_class is null or ch.class_id = p_class)
     and (p_child is null or ch.id = p_child)
),
marks as (
  select k.child_id, k.class_id, t.session_date, t.month,
         coalesce(r.score, 0) > 0              as present,
         coalesce(r.score, 0)                  as score,
         coalesce(r.mass, false)               as mass,
         coalesce(r.confession, false)         as confession,
         coalesce(r.sunday_school and r.vespers and r.mass, false)
                                               as full_day,
         row_number() over (partition by k.child_id order by t.session_date) as n
    from kids k
    join taken t on t.class_id = k.class_id
    left join public.attendance_records r
           on r.session_id = t.session_id and r.child_id = k.child_id
),
-- The taken Saturdays newest first, to find the day a run reached 4 or 12.
recent as (
  select m.child_id, m.session_date,
         row_number() over (partition by m.child_id order by m.session_date desc) as pos
    from marks m
),
-- ملتزم / ملتزم ذهبي ARE the ملتزمين list: the run still going, read from
-- the same view (v_child_attendance_streak), so the two never disagree. The
-- badge is held while the run lasts and goes when it breaks.
streaks as (
  select k.child_id,
         coalesce(v.present_streak, 0) as current_run,
         case when v.present_streak >= 4 then
           (select r.session_date from recent r
             where r.child_id = k.child_id and r.pos = v.present_streak - 3)
         end as streak4_on,
         case when v.present_streak >= 12 then
           (select r.session_date from recent r
             where r.child_id = k.child_id and r.pos = v.present_streak - 15)
         end as streak16_on
    from kids k
    left join public.v_child_attendance_streak v
           on v.child_id = k.child_id and v.year_id = p_year
),
full_days as (
  select f.child_id,
         min(f.session_date) filter (where f.k = 5) as full_on,
         count(*)::int                              as full_count
    from (select m.child_id, m.session_date,
                 row_number() over (partition by m.child_id order by m.session_date) as k
            from marks m where m.full_day) f
   group by f.child_id
),
-- Per child and month the class met.
months as (
  select m.child_id, m.class_id, m.month,
         count(*)::int                            as saturdays,
         count(*) filter (where m.mass)::int      as masses,
         bool_or(m.confession)                    as confessed,
         sum(m.score)::int                        as points,
         max(m.session_date)                      as last_date,
         min(m.session_date) filter (where m.confession) as first_confession,
         -- 1, 2, 3 … over the months the class met, so a month with no
         -- confession breaks a run but a summer with no Saturdays does not.
         dense_rank() over (partition by m.child_id order by m.month)::int
                                                  as month_idx
    from marks m
   group by m.child_id, m.class_id, m.month
),
-- قداسي كامل: a FINISHED month of at least three Saturdays, mass at all.
mass_months as (
  select mo.child_id,
         min(mo.last_date) filter (
           where mo.saturdays >= 3 and mo.masses = mo.saturdays
             and mo.month < date_trunc('month', current_date)::date) as mass_on
    from months mo
   group by mo.child_id
),
this_month as (
  select mo.child_id, mo.saturdays, mo.masses
    from months mo
   where mo.month = date_trunc('month', current_date)::date
),
-- قلب نقي: confession in three of the class's months in a row.
confession_runs as (
  select mo.child_id, mo.month, mo.first_confession,
         mo.month_idx
           - row_number() over (partition by mo.child_id order by mo.month) as island
    from months mo
   where mo.confessed
),
confession_counted as (
  select c.child_id, c.month, c.first_confession,
         row_number() over (partition by c.child_id, c.island order by c.month) as run_pos
    from confession_runs c
),
confessions as (
  select k.child_id,
         (select min(cc.first_confession) from confession_counted cc
           where cc.child_id = k.child_id and cc.run_pos = 3) as confession_on,
         -- The run still going: it reaches this month or the one before.
         coalesce((select max(cc.run_pos) from confession_counted cc
                    where cc.child_id = k.child_id
                      and cc.month >= (date_trunc('month', current_date) - interval '1 month')::date), 0)::int
                                                              as confession_run
    from kids k
),
-- نجم الشهر: the most points in the class over a FINISHED month (ties all win).
stars as (
  select mo.child_id, min(mo.last_date) as star_on
    from months mo
   where mo.month < date_trunc('month', current_date)::date
     and mo.points > 0
     and mo.points = (select max(o.points) from months o
                       where o.class_id = mo.class_id and o.month = mo.month)
   group by mo.child_id
)
select k.child_id, k.class_id, b.badge,
       case b.badge
         when 'streak4'     then st.streak4_on
         when 'streak16'    then st.streak16_on
         when 'mass_month'  then mm.mass_on
         when 'full_day'    then fd.full_on
         when 'confession3' then cf.confession_on
         when 'star_month'  then sr.star_on
       end as earned_on,
       least(b.target, case b.badge
         when 'streak4'     then st.current_run
         when 'streak16'    then st.current_run
         when 'mass_month'  then coalesce(tm.masses, 0)
         when 'full_day'    then coalesce(fd.full_count, 0)
         when 'confession3' then cf.confession_run
         else 0
       end)::int as progress,
       case b.badge
         when 'mass_month' then greatest(coalesce(tm.saturdays, 0), 3)
         else b.target
       end::int as target
  from kids k
 cross join (values ('streak4', 4), ('mass_month', 3), ('full_day', 5),
                    ('confession3', 3), ('star_month', 1), ('streak16', 12))
        as b(badge, target)
  left join streaks      st on st.child_id = k.child_id
  left join full_days    fd on fd.child_id = k.child_id
  left join mass_months  mm on mm.child_id = k.child_id
  left join this_month   tm on tm.child_id = k.child_id
  left join confessions  cf on cf.child_id = k.child_id
  left join stars        sr on sr.child_id = k.child_id;
$$;

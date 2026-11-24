-- A Saturday marked «إجازة / نشاط ترفيهي» (lesson_breaks) must not count
-- toward the badges. child_badges, the streak view and the school stars
-- already leave those Saturdays out; the class ranking did not: attendance
-- saved on a Saturday that was marked a break afterwards still added its points
-- (and so moved the child's level and place). Everything else in
-- class_leaderboard is unchanged from 20261123001.
create or replace function public.class_leaderboard(
  p_year  uuid,
  p_class uuid,
  p_from  date default null
)
returns table (
  child_id          uuid,
  child_name        text,
  attendance_points int,
  badges_earned     int,
  game_points       int
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
with pts as (
  select r.child_id, sum(r.score)::int as points
    from public.attendance_records r
    join public.attendance_sessions s on s.id = r.session_id
   where s.year_id = p_year
     and s.class_id = p_class
     and s.session_date <= current_date
     and (p_from is null or s.session_date >= p_from)
     and not exists (select 1 from public.lesson_breaks b
                      where b.break_date = s.session_date)
   group by r.child_id
),
won as (
  select b.child_id, count(*)::int as badges
    from public.child_badges(p_year, p_class) b
   where b.earned_on is not null
     and (p_from is null or b.earned_on >= p_from)
   group by b.child_id
)
select ch.id, ch.full_name,
       coalesce(p.points, 0),
       coalesce(w.badges, 0),
       coalesce(p.points, 0) + 10 * coalesce(w.badges, 0)
  from public.children ch
  left join pts p on p.child_id = ch.id
  left join won w on w.child_id = ch.id
 where ch.class_id = p_class
   and ch.is_active
 order by 5 desc, ch.full_name;
$$;

revoke all on function public.class_leaderboard(uuid, uuid, date) from public, anon;
grant execute on function public.class_leaderboard(uuid, uuid, date) to authenticated;

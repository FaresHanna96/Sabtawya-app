-- A Saturday with no lesson now says why: إجازة (holiday) or نشاط ترفيهي
-- (an outing / activity day). The admin sets it from the attendance screen.
--
-- And attendance saved on such a day no longer counts: on 14 Nov 2026 (a نشاط
-- ترفيهي) one class was saved with nobody ticked, which stored every child as
-- absent and reset every run in ملتزمين to zero. The streak and trend views
-- now skip no-lesson Saturdays even when records exist for them.

-- ── the kind ──────────────────────────────────────────────────────────────────
alter table public.lesson_breaks
  add column if not exists kind text not null default 'holiday';

alter table public.lesson_breaks
  drop constraint if exists lesson_breaks_kind_check;
alter table public.lesson_breaks
  add constraint lesson_breaks_kind_check check (kind in ('holiday', 'activity'));

-- The servants' notice names the reason.
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
    case when new.shift
      then 'مفيش درس ولا حضور يومها. الدروس بعده تتأجل أسبوع.'
      else 'مفيش درس ولا حضور يومها. باقي الدروس في مواعيدها.' end);
  return new;
exception when others then
  return new;
end;
$$;

-- ── streaks: no-lesson Saturdays do not count ────────────────────────────────
create or replace view public.v_child_attendance_streak
with (security_invoker = true) as
with taken as (
  select s.id as session_id, s.class_id, s.year_id, s.session_date
  from public.attendance_sessions s
  where s.session_date <= current_date
    and exists (select 1 from public.attendance_records r where r.session_id = s.id)
    and not exists (select 1 from public.lesson_breaks b where b.break_date = s.session_date)
),
marked as (
  select
    ch.id as child_id,
    t.year_id,
    t.session_date,
    coalesce(r.score, 0) > 0 as present
  from public.children ch
  join taken t on t.class_id = ch.class_id
  left join public.attendance_records r
         on r.session_id = t.session_id and r.child_id = ch.id
  where ch.is_active
),
ranked as (
  select
    m.*,
    row_number() over (
      partition by m.child_id, m.year_id order by m.session_date desc
    ) as position
  from marked m
),
agg as (
  select
    r.child_id,
    r.year_id,
    max(r.position) as sessions,
    min(r.position) filter (where r.present)     as first_present,
    min(r.position) filter (where not r.present) as first_absent,
    max(r.session_date) filter (where r.present) as last_present_date
  from ranked r
  group by r.child_id, r.year_id
)
select
  a.child_id,
  ch.full_name as child_name,
  ch.gender,
  ch.photo_path,
  ch.class_id,
  c.name as class_name,
  a.year_id,
  coalesce(a.first_present - 1, a.sessions)::int as absent_streak,
  coalesce(a.first_absent  - 1, a.sessions)::int as present_streak,
  a.last_present_date
from agg a
join public.children ch on ch.id = a.child_id
join public.classes  c  on c.id  = ch.class_id;

revoke all on public.v_child_attendance_streak from anon;
grant select on public.v_child_attendance_streak to authenticated;

-- ── trend: the same rule ─────────────────────────────────────────────────────
create or replace view public.v_child_attendance_trend
with (security_invoker = true) as
with taken as (
  select s.id as session_id, s.class_id, s.year_id, s.session_date
  from public.attendance_sessions s
  where s.session_date <= current_date
    and exists (select 1 from public.attendance_records r where r.session_id = s.id)
    and not exists (select 1 from public.lesson_breaks b where b.break_date = s.session_date)
),
marked as (
  select
    ch.id as child_id,
    t.year_id,
    t.session_date,
    coalesce(r.score, 0) > 0 as present
  from public.children ch
  join taken t on t.class_id = ch.class_id
  left join public.attendance_records r
         on r.session_id = t.session_id and r.child_id = ch.id
  where ch.is_active
),
ranked as (
  select
    m.*,
    row_number() over (
      partition by m.child_id, m.year_id order by m.session_date desc
    ) as position
  from marked m
),
agg as (
  select
    r.child_id,
    r.year_id,
    count(*) filter (where r.position <= 4)                     as recent_held,
    count(*) filter (where r.position <= 4 and r.present)       as recent_present,
    count(*) filter (where r.position between 5 and 8)          as previous_held,
    count(*) filter (where r.position between 5 and 8 and r.present) as previous_present
  from ranked r
  where r.position <= 8
  group by r.child_id, r.year_id
)
select
  a.child_id,
  ch.full_name as child_name,
  ch.class_id,
  c.name as class_name,
  a.year_id,
  a.recent_present,
  a.previous_present,
  round(a.recent_present   * 100.0 / a.recent_held)   as recent_rate,
  round(a.previous_present * 100.0 / a.previous_held) as previous_rate,
  round(a.previous_present * 100.0 / a.previous_held)
    - round(a.recent_present * 100.0 / a.recent_held)  as drop_points,
  (a.previous_present * 100.0 / a.previous_held
     - a.recent_present * 100.0 / a.recent_held) >= 25 as is_declining
from agg a
join public.children ch on ch.id = a.child_id
join public.classes  c  on c.id  = ch.class_id
where a.recent_held = 4 and a.previous_held = 4;

revoke all on public.v_child_attendance_trend from anon;
grant select on public.v_child_attendance_trend to authenticated;

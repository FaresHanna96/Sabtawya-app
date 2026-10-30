-- =============================================================================
-- 07 - Fourth activity: الاعتراف (confession), 5 points
-- =============================================================================
-- A Saturday is now worth 20 points: مدارس الأحد + عشية + قداس + الاعتراف.
--
-- max_points_per_session was a generated column over three activities, and a
-- generation expression cannot be changed in place. Dropping and re-adding it
-- would mean dropping every view that reads it, so it becomes a plain column
-- maintained by a trigger instead: the ceiling stays database-owned, and the
-- next activity is one line in that trigger rather than a view cascade.
-- =============================================================================

alter table public.attendance_years
  add column if not exists points_confession smallint not null default 5;

alter table public.attendance_years
  drop constraint if exists attendance_years_points;
alter table public.attendance_years
  add constraint attendance_years_points check (
    points_sunday_school >= 0 and points_vespers >= 0
    and points_mass >= 0 and points_confession >= 0
  );

alter table public.attendance_years
  alter column max_points_per_session drop expression if exists;

comment on column public.attendance_years.max_points_per_session is
  'Points available on one attendance day. Maintained by attendance_years_apply_max_points(), so a client value is ignored.';

create or replace function public.attendance_years_apply_max_points()
returns trigger
language plpgsql
as $$
begin
  new.max_points_per_session := new.points_sunday_school
                              + new.points_vespers
                              + new.points_mass
                              + new.points_confession;
  return new;
end;
$$;

drop trigger if exists attendance_years_max_points on public.attendance_years;
create trigger attendance_years_max_points
  before insert or update on public.attendance_years
  for each row execute function public.attendance_years_apply_max_points();

update public.attendance_years
   set max_points_per_session = points_sunday_school + points_vespers
                              + points_mass + points_confession
 where max_points_per_session is distinct from
       (points_sunday_school + points_vespers + points_mass + points_confession);

-- -----------------------------------------------------------------------------
-- The record gains the fourth flag; the score still comes from the trigger
-- -----------------------------------------------------------------------------
alter table public.attendance_records
  add column if not exists confession boolean not null default false;

alter table public.attendance_records
  alter column max_score set default 20;

create or replace function public.attendance_records_apply_scoring()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_points_sunday_school smallint;
  v_points_vespers       smallint;
  v_points_mass          smallint;
  v_points_confession    smallint;
  v_max_points           integer;
  v_class_id             uuid;
  v_is_locked            boolean;
begin
  select ay.points_sunday_school,
         ay.points_vespers,
         ay.points_mass,
         ay.points_confession,
         ay.max_points_per_session,
         s.class_id,
         s.is_locked
    into v_points_sunday_school,
         v_points_vespers,
         v_points_mass,
         v_points_confession,
         v_max_points,
         v_class_id,
         v_is_locked
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  where s.id = new.session_id;

  if v_class_id is null then
    raise exception 'جلسة الحضور غير موجودة' using errcode = '23503';
  end if;

  if v_is_locked and not public.is_admin() then
    raise exception 'تم إغلاق هذه الجلسة ولا يمكن تعديلها' using errcode = '42501';
  end if;

  -- Integrity: a record may only exist for a child of the session's class.
  if not exists (
    select 1 from public.children c
    where c.id = new.child_id and c.class_id = v_class_id
  ) then
    raise exception 'المخدوم لا ينتمي إلى فصل هذه الجلسة' using errcode = '23514';
  end if;

  new.score := (case when new.sunday_school then v_points_sunday_school else 0 end)
             + (case when new.vespers       then v_points_vespers       else 0 end)
             + (case when new.mass          then v_points_mass          else 0 end)
             + (case when new.confession    then v_points_confession    else 0 end);
  new.max_score  := v_max_points;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);

  if tg_op = 'INSERT' then
    new.created_at := now();
    new.created_by := coalesce(new.created_by, auth.uid());
  end if;

  return new;
end;
$$;

-- Re-score what is already stored. The trigger is stepped around because it
-- refuses to touch a locked session unless the caller is an admin, and a
-- migration runs with no authenticated user at all.
alter table public.attendance_records disable trigger attendance_records_scoring;

update public.attendance_records r
   set max_score = ay.max_points_per_session
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
 where s.id = r.session_id
   and r.max_score is distinct from ay.max_points_per_session;

alter table public.attendance_records enable trigger attendance_records_scoring;

-- -----------------------------------------------------------------------------
-- Expose the new flag
-- -----------------------------------------------------------------------------
drop view if exists public.v_session_scores;
create view public.v_session_scores
with (security_invoker = true) as
select
  r.id          as record_id,
  s.id          as session_id,
  s.year_id,
  s.class_id,
  c.name        as class_name,
  s.session_date,
  s.is_locked,
  ch.id         as child_id,
  ch.full_name  as child_name,
  ch.gender,
  ch.is_active  as child_is_active,
  r.sunday_school,
  r.vespers,
  r.mass,
  r.confession,
  r.score,
  r.max_score,
  r.updated_at,
  r.updated_by,
  p.full_name   as updated_by_name
from public.attendance_records r
join public.attendance_sessions s on s.id = r.session_id
join public.classes            c on c.id = s.class_id
join public.children          ch on ch.id = r.child_id
left join public.profiles      p on p.id = r.updated_by;

-- Supabase grants new tables and views to anon by default, so the revoke from
-- migration 04 has to be repeated for a view that was dropped and rebuilt.
revoke all on public.v_session_scores from anon;
grant select on public.v_session_scores to authenticated;

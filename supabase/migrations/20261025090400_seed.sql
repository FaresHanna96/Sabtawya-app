-- =============================================================================
-- 05 - Seed: attendance year and the eight classes
-- =============================================================================
-- Order matters. The year is inserted first so the classes_backfill_sessions
-- trigger can generate every Saturday for each class as it is created.
--
-- 24 Oct 2026 and 25 Sep 2027 are both Saturdays, giving 49 sessions and a
-- ceiling of 49 x 15 = 735 points for the year.
-- =============================================================================

insert into public.attendance_years (
  name, start_date, end_date, session_weekday,
  points_sunday_school, points_vespers, points_mass, is_current
)
values ('2026 - 2027', date '2026-10-24', date '2027-09-25', 6, 5, 5, 5, true)
on conflict (name) do nothing;

insert into public.classes (name, description, sort_order)
values
  ('الفصل 1', null, 1),
  ('الفصل 2', null, 2),
  ('الفصل 3', null, 3),
  ('الفصل 4', null, 4),
  ('الفصل 5', null, 5),
  ('الفصل 6', null, 6),
  ('الفصل 7', null, 7),
  ('الفصل 8', null, 8)
on conflict (name) do nothing;

-- Safety net in case the classes already existed before the year was added.
do $$
declare
  v_year_id uuid;
begin
  select id into v_year_id from public.attendance_years where is_current limit 1;
  if v_year_id is not null then
    perform public.generate_sessions_internal(v_year_id, null);
  end if;
end $$;

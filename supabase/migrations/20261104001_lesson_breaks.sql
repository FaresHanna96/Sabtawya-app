-- A week with no lesson, set by أمين الخدمة (holiday, trip, exam...).
--   shift = true : the week's lesson moves to the next week and every later
--                  lesson moves one week too (postponed).
--   shift = false: the lesson of that week is dropped; later lessons keep
--                  their dates (cancelled).
create table if not exists public.lesson_breaks (
  break_date date primary key,
  shift      boolean not null default true,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

alter table public.lesson_breaks enable row level security;

drop policy if exists lesson_breaks_select on public.lesson_breaks;
create policy lesson_breaks_select on public.lesson_breaks
  for select to authenticated using (true);
drop policy if exists lesson_breaks_write on public.lesson_breaks;
create policy lesson_breaks_write on public.lesson_breaks
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

grant select on public.lesson_breaks to authenticated;
grant insert, update, delete on public.lesson_breaks to authenticated;

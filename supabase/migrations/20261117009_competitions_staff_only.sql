-- Competitions are for the general servant (خادم عام) and the admin only. A
-- servant of a class no longer reads them, records marks, or is told about a
-- new one. Hiding the screens is a convenience; these policies are the control.

-- competitions: read by admin and general servant only (writes already are).
drop policy if exists competitions_select on public.competitions;
create policy competitions_select on public.competitions
  for select to authenticated
  using (public.is_admin() or public.is_general_servant());

-- competition_marks: admin and general servant. A general servant changes or
-- removes only the marks they wrote themselves, as before.
drop policy if exists competition_marks_select on public.competition_marks;
create policy competition_marks_select on public.competition_marks
  for select to authenticated
  using (public.is_admin() or public.is_general_servant());

drop policy if exists competition_marks_upsert on public.competition_marks;
create policy competition_marks_upsert on public.competition_marks
  for insert to authenticated
  with check (public.is_admin() or public.is_general_servant());

drop policy if exists competition_marks_update on public.competition_marks;
create policy competition_marks_update on public.competition_marks
  for update to authenticated
  using (public.is_admin()
         or (public.is_general_servant() and marked_by = auth.uid()));

drop policy if exists competition_marks_delete on public.competition_marks;
create policy competition_marks_delete on public.competition_marks
  for delete to authenticated
  using (public.is_admin()
         or (public.is_general_servant() and marked_by = auth.uid()));

-- A new competition notifies the general servants, not every servant.
create or replace function public.notify_competition_added()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  select id, 'competition_added', 'مسابقة جديدة',
         new.title || ' — ' || to_char(new.week_date, 'YYYY-MM-DD')
  from public.profiles
  where is_active and role = 'general_servant';
  return new;
exception when others then
  return new;
end;
$$;

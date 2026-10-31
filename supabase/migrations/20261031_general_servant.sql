-- =============================================================================
-- خادم عام role: read access to all classes' data, no servant management
-- =============================================================================

-- 1. Add the new enum value
alter type public.app_role add value if not exists 'general_servant';

-- 2. Helper function (mirrors is_admin pattern)
create or replace function public.is_general_servant()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select p.role = 'general_servant'
     from public.profiles p
     where p.id = auth.uid() and p.is_active),
    false
  );
$$;

grant execute on function public.is_general_servant() to authenticated;

-- 3. classes — general servant sees all classes (read-only)
drop policy if exists classes_select on public.classes;
create policy classes_select on public.classes
for select to authenticated
using (public.is_admin() or public.serves_class(id) or public.is_general_servant());

-- 4. children — general servant sees all children (read-only)
drop policy if exists children_select on public.children;
create policy children_select on public.children
for select to authenticated
using (public.is_admin() or public.serves_class(class_id) or public.is_general_servant());

-- 5. attendance_sessions — general servant sees all sessions
drop policy if exists attendance_sessions_select on public.attendance_sessions;
create policy attendance_sessions_select on public.attendance_sessions
for select to authenticated
using (public.is_admin() or public.serves_class(class_id) or public.is_general_servant());

-- 6. attendance_records — general servant sees all records
drop policy if exists attendance_records_select on public.attendance_records;
create policy attendance_records_select on public.attendance_records
for select to authenticated
using (
  public.is_admin()
  or public.is_general_servant()
  or exists (
    select 1 from public.attendance_sessions s
    where s.id = attendance_records.session_id
      and public.serves_class(s.class_id)
  )
);

-- 7. competition_marks — general servant can read all, but not write
drop policy if exists "competition_marks_select" on public.competition_marks;
create policy "competition_marks_select" on public.competition_marks
  for select using (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1 from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid()
        and ch.id = competition_marks.child_id
    )
  );

-- 8. servant_activities — general servant has NO access (existing policy unchanged)
--    The existing servant_activities policies use is_admin() or servant_id check,
--    so general_servant is already blocked. No change needed.

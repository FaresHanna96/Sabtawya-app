-- خادم عام may now work with every class: add / edit children (and their
-- photos, visits and attendance), add / edit classes, and add / edit
-- competitions and record their marks. Deleting classes, children and
-- competitions, and managing servants, stay with the admin.

-- Class-scoped writes (children, photos, visits, attendance) all go through
-- this helper, so the general servant joins it.
create or replace function public.can_access_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_admin()
      or public.is_general_servant()
      or public.serves_class(p_class_id);
$$;

-- Classes: create and edit (no delete).
drop policy if exists classes_insert on public.classes;
create policy classes_insert on public.classes
  for insert to authenticated
  with check (public.is_admin() or public.is_general_servant());

drop policy if exists classes_update on public.classes;
create policy classes_update on public.classes
  for update to authenticated
  using (public.is_admin() or public.is_general_servant() or public.serves_class(id))
  with check (public.is_admin() or public.is_general_servant() or public.serves_class(id));

-- The patron picture of a class.
drop policy if exists class_patrons_insert on storage.objects;
create policy class_patrons_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'class-patrons'
              and (public.is_admin() or public.is_general_servant()));

drop policy if exists class_patrons_update on storage.objects;
create policy class_patrons_update on storage.objects
  for update to authenticated
  using (bucket_id = 'class-patrons'
         and (public.is_admin() or public.is_general_servant()))
  with check (bucket_id = 'class-patrons'
              and (public.is_admin() or public.is_general_servant()));

-- Competitions: create and edit (no delete), and record marks for any child.
drop policy if exists competitions_insert on public.competitions;
create policy competitions_insert on public.competitions
  for insert to authenticated
  with check (public.is_admin() or public.is_general_servant());

drop policy if exists competitions_update on public.competitions;
create policy competitions_update on public.competitions
  for update to authenticated
  using (public.is_admin() or public.is_general_servant());

drop policy if exists competition_marks_upsert on public.competition_marks;
create policy competition_marks_upsert on public.competition_marks
  for insert to authenticated
  with check (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1
      from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid()
        and ch.id = competition_marks.child_id
    )
  );

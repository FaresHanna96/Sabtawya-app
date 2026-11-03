-- خادم عام does not add or edit children or classes after all (the 010
-- migration allowed it). Back to read-only for those, and for everything that
-- hangs off can_access_class: photos, visits and attendance. The competition
-- permissions from 010 stay.

create or replace function public.can_access_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_admin() or public.serves_class(p_class_id);
$$;

drop policy if exists classes_insert on public.classes;
create policy classes_insert on public.classes
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists classes_update on public.classes;
create policy classes_update on public.classes
  for update to authenticated
  using (public.is_admin() or public.serves_class(id))
  with check (public.is_admin() or public.serves_class(id));

drop policy if exists class_patrons_insert on storage.objects;
create policy class_patrons_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'class-patrons' and public.is_admin());

drop policy if exists class_patrons_update on storage.objects;
create policy class_patrons_update on storage.objects
  for update to authenticated
  using (bucket_id = 'class-patrons' and public.is_admin())
  with check (bucket_id = 'class-patrons' and public.is_admin());

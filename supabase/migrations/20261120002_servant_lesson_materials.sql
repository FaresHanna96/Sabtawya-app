-- Servants add lesson materials too (a video link, a picture, a PDF they used),
-- from "المواد والأفكار" under a lesson, including on the lesson prep screen.
-- Each one says who added it. A servant removes only their own; أمين الخدمة
-- removes any. Editing stays the admin's.

alter table public.lesson_materials
  add column if not exists author_name text;

alter table public.lesson_materials
  alter column created_by set default auth.uid();

-- The author is whoever is signed in, with the name from their profile, so a
-- servant cannot add a material under someone else's name.
create or replace function public.lesson_materials_stamp()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.created_by := auth.uid();
  select full_name into new.author_name
  from public.profiles where id = auth.uid();
  return new;
end;
$$;

revoke all on function public.lesson_materials_stamp() from public, anon, authenticated;

drop trigger if exists lesson_materials_stamp on public.lesson_materials;
create trigger lesson_materials_stamp
  before insert on public.lesson_materials
  for each row execute function public.lesson_materials_stamp();

update public.lesson_materials m
set author_name = p.full_name
from public.profiles p
where p.id = m.created_by and m.author_name is null;

drop policy if exists lesson_materials_write on public.lesson_materials;

drop policy if exists lesson_materials_insert on public.lesson_materials;
create policy lesson_materials_insert on public.lesson_materials
  for insert to authenticated
  with check (public.auth_role() is not null);

drop policy if exists lesson_materials_update on public.lesson_materials;
create policy lesson_materials_update on public.lesson_materials
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists lesson_materials_delete on public.lesson_materials;
create policy lesson_materials_delete on public.lesson_materials
  for delete to authenticated
  using (public.is_admin() or created_by = auth.uid());

-- Files: any active servant uploads; a servant deletes only what they
-- uploaded (storage keeps the uploader as the object's owner).
drop policy if exists lesson_materials_files_insert on storage.objects;
create policy lesson_materials_files_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'lesson-materials' and public.auth_role() is not null);

drop policy if exists lesson_materials_files_delete on storage.objects;
create policy lesson_materials_files_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'lesson-materials'
    and (public.is_admin() or owner_id = auth.uid()::text)
  );

-- =============================================================================
-- Servants may edit the class they are assigned to
-- =============================================================================
-- Allows a servant to update any column of their own class (name, description,
-- sort_order, patron_name, patron_photo_path).  Structural operations
-- (insert, delete, setActive) remain admin-only.
-- =============================================================================

-- classes : update now allowed for the servant assigned to that class
drop policy if exists classes_update on public.classes;
create policy classes_update on public.classes
for update to authenticated
using  (public.is_admin() or public.serves_class(id))
with check (public.is_admin() or public.serves_class(id));

-- class-patrons storage : servants may upload / replace / delete photos
-- for the class they serve.  Path inside the bucket: <class_id>/<filename>
drop policy if exists class_patrons_insert on storage.objects;
create policy class_patrons_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'class-patrons'
  and (
    public.is_admin()
    or public.serves_class((split_part(name, '/', 1))::uuid)
  )
);

drop policy if exists class_patrons_update on storage.objects;
create policy class_patrons_update on storage.objects
for update to authenticated
using (
  bucket_id = 'class-patrons'
  and (
    public.is_admin()
    or public.serves_class((split_part(name, '/', 1))::uuid)
  )
)
with check (
  bucket_id = 'class-patrons'
  and (
    public.is_admin()
    or public.serves_class((split_part(name, '/', 1))::uuid)
  )
);

drop policy if exists class_patrons_delete on storage.objects;
create policy class_patrons_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'class-patrons'
  and (
    public.is_admin()
    or public.serves_class((split_part(name, '/', 1))::uuid)
  )
);

-- =============================================================================
-- 05 - Child photos
-- =============================================================================
-- A photo lives in Supabase Storage, not in the table: the row keeps only the
-- object path, so the image is fetched on demand and a child record stays small.
--
-- Object layout: child-photos/<child_id>/<unix_millis>.<ext>
-- The first path segment is the child id, which is what lets the storage
-- policies below reuse public.can_access_class() and give photos exactly the
-- same visibility as the rest of the child's data.

alter table public.children
  add column if not exists photo_path text;

comment on column public.children.photo_path is
  'Object path inside the child-photos storage bucket, or null for no photo.';

-- -----------------------------------------------------------------------------
-- Bucket
-- -----------------------------------------------------------------------------
-- Private: a child's photo must never be reachable through a guessable public
-- URL. The app reads it through a short-lived signed URL, which still goes
-- through the policies below.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'child-photos',
  'child-photos',
  false,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- Access helper
-- -----------------------------------------------------------------------------
-- Resolves the child id from the object path and defers to can_access_class().
-- plpgsql rather than sql so a malformed path fails closed instead of raising
-- an invalid-uuid error inside a policy.
create or replace function public.can_access_child_photo(p_object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_child_id uuid;
  v_class_id uuid;
begin
  begin
    v_child_id := nullif(split_part(p_object_name, '/', 1), '')::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  if v_child_id is null then
    return false;
  end if;

  select ch.class_id into v_class_id
  from public.children ch
  where ch.id = v_child_id;

  if v_class_id is null then
    return false;
  end if;

  return public.can_access_class(v_class_id);
end;
$$;

revoke all on function public.can_access_child_photo(text) from public, anon;
grant execute on function public.can_access_child_photo(text) to authenticated;

-- -----------------------------------------------------------------------------
-- Storage policies
-- -----------------------------------------------------------------------------
-- Mirrors the children table: a servant may see and change photos of children
-- in their own classes, an admin may do so everywhere, and anon gets nothing.
drop policy if exists child_photos_select on storage.objects;
create policy child_photos_select on storage.objects
for select to authenticated
using (
  bucket_id = 'child-photos'
  and public.can_access_child_photo(name)
);

drop policy if exists child_photos_insert on storage.objects;
create policy child_photos_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'child-photos'
  and public.can_access_child_photo(name)
);

drop policy if exists child_photos_update on storage.objects;
create policy child_photos_update on storage.objects
for update to authenticated
using (
  bucket_id = 'child-photos'
  and public.can_access_child_photo(name)
)
with check (
  bucket_id = 'child-photos'
  and public.can_access_child_photo(name)
);

drop policy if exists child_photos_delete on storage.objects;
create policy child_photos_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'child-photos'
  and public.can_access_child_photo(name)
);

-- =============================================================================
-- 11 - Each class has a patron saint
-- =============================================================================
-- Name and picture of the saint the class is named after. Stored like a child
-- photo: the row keeps only the object path.
--
-- Object layout: class-patrons/<class_id>/<unix_millis>.<ext>
--
-- The picture is not personal data, so every signed-in servant may read any of
-- them, but only an admin may add, replace, or delete one. That mirrors the
-- classes table itself, where a servant has read access and no write access.
-- =============================================================================

alter table public.classes
  add column if not exists patron_name text,
  add column if not exists patron_photo_path text;

comment on column public.classes.patron_name is
  'Name of the class patron saint, e.g. الشهيد مار مينا.';
comment on column public.classes.patron_photo_path is
  'Object path inside the class-patrons storage bucket, or null for no picture.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'class-patrons',
  'class-patrons',
  false,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- Storage policies
-- -----------------------------------------------------------------------------
drop policy if exists class_patrons_select on storage.objects;
create policy class_patrons_select on storage.objects
for select to authenticated
using (bucket_id = 'class-patrons');

drop policy if exists class_patrons_insert on storage.objects;
create policy class_patrons_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'class-patrons' and public.is_admin());

drop policy if exists class_patrons_update on storage.objects;
create policy class_patrons_update on storage.objects
for update to authenticated
using (bucket_id = 'class-patrons' and public.is_admin())
with check (bucket_id = 'class-patrons' and public.is_admin());

drop policy if exists class_patrons_delete on storage.objects;
create policy class_patrons_delete on storage.objects
for delete to authenticated
using (bucket_id = 'class-patrons' and public.is_admin());

-- -----------------------------------------------------------------------------
-- Expose the patron on the overview the dashboards and lists already read
-- -----------------------------------------------------------------------------
create or replace view public.v_class_overview
with (security_invoker = true) as
select
  c.id          as class_id,
  c.name        as class_name,
  c.description,
  c.sort_order,
  c.is_active,
  (select count(*)
     from public.children ch
    where ch.class_id = c.id and ch.is_active)           as active_children,
  (select count(*)
     from public.children ch
    where ch.class_id = c.id and ch.is_active and ch.gender = 'boy')  as boys_count,
  (select count(*)
     from public.children ch
    where ch.class_id = c.id and ch.is_active and ch.gender = 'girl') as girls_count,
  (select count(*)
     from public.class_servants cs
    where cs.class_id = c.id)                            as servants_count,
  (select min(s.session_date)
     from public.attendance_sessions s
    where s.class_id = c.id and s.session_date >= current_date) as next_session_date,
  coalesce(
    (select max(s.session_date)
       from public.attendance_sessions s
      where s.class_id = c.id and s.session_date <= current_date),
    (select min(s.session_date)
       from public.attendance_sessions s
      where s.class_id = c.id)
  )                                                      as last_session_date,
  c.patron_name,
  c.patron_photo_path
from public.classes c;

revoke all on public.v_class_overview from anon;
grant select on public.v_class_overview to authenticated;

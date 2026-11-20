-- Lesson materials (المواد والأفكار) and shared preps (تحضيرات مميزة).
--
-- Materials: PDFs, pictures and links أمين الخدمة attaches to a lesson of the
-- programme. They are keyed by the programme slot (Coptic month, week, grade),
-- like `lessons`, so next year's same lesson finds them again. A null grade is
-- for every grade (e.g. the week's hymn).
--
-- Shared preps: an accepted preparation the admin marks as an example. It is
-- then readable, files included, by every signed-in servant, who sees it under
-- the same lesson. An unshared prep stays private exactly as before (its owner
-- and the admin only).

create table if not exists public.lesson_materials (
  id           uuid primary key default gen_random_uuid(),
  coptic_month smallint not null check (coptic_month between 1 and 12),
  week         smallint not null check (week between 1 and 4),
  grade        smallint check (grade between 3 and 6),
  kind         text not null check (kind in ('file', 'link')),
  title        text not null check (length(btrim(title)) between 1 and 120),
  url          text,
  storage_path text,
  mime         text,
  created_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint lesson_materials_one_source check (
    (kind = 'link' and url is not null and storage_path is null)
    or (kind = 'file' and storage_path is not null and url is null)
  ),
  constraint lesson_materials_web_link check (
    url is null or url ~* '^https?://'
  )
);

create index if not exists lesson_materials_slot_idx
  on public.lesson_materials (coptic_month, week, grade);

alter table public.lesson_materials enable row level security;

drop policy if exists lesson_materials_select on public.lesson_materials;
create policy lesson_materials_select on public.lesson_materials
  for select to authenticated using (public.auth_role() is not null);

drop policy if exists lesson_materials_write on public.lesson_materials;
create policy lesson_materials_write on public.lesson_materials
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

revoke all on public.lesson_materials from anon;
grant select, insert, update, delete on public.lesson_materials to authenticated;

-- The files: private, read through signed URLs by any signed-in servant,
-- written by the admin only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lesson-materials',
  'lesson-materials',
  false,
  20971520, -- 20 MB
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists lesson_materials_files_select on storage.objects;
create policy lesson_materials_files_select on storage.objects
  for select to authenticated
  using (bucket_id = 'lesson-materials' and public.auth_role() is not null);

drop policy if exists lesson_materials_files_insert on storage.objects;
create policy lesson_materials_files_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'lesson-materials' and public.is_admin());

drop policy if exists lesson_materials_files_delete on storage.objects;
create policy lesson_materials_files_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'lesson-materials' and public.is_admin());

-- ── Shared preps ─────────────────────────────────────────────────────────────

alter table public.servant_lesson_preps
  add column if not exists shared_at    timestamptz,
  add column if not exists shared_month smallint check (shared_month between 1 and 12),
  add column if not exists shared_week  smallint check (shared_week between 1 and 4),
  add column if not exists shared_grade smallint check (shared_grade between 3 and 6);

-- A servant adds their own prep, but never one already shared (or already
-- reviewed): sharing and reviewing stay the admin's, through update.
drop policy if exists slp_insert on public.servant_lesson_preps;
create policy slp_insert on public.servant_lesson_preps
  for insert to authenticated
  with check (
    auth.uid() = servant_id
    and status = 'pending'
    and shared_at is null
    and reviewed_by is null
  );

create index if not exists servant_lesson_preps_shared_idx
  on public.servant_lesson_preps (shared_month, shared_week, shared_grade)
  where shared_at is not null;

-- A shared prep's files are readable by every signed-in servant (an extra,
-- permissive policy: the owner / admin ones are unchanged).
drop policy if exists ss_select_shared on storage.objects;
create policy ss_select_shared on storage.objects
  for select to authenticated
  using (
    bucket_id = 'servant-submissions'
    and public.auth_role() is not null
    and exists (
      select 1 from public.servant_lesson_preps p
      where p.id::text = split_part(name, '/', 1)
        and p.shared_at is not null
    )
  );

-- Marks an accepted prep as an example for its lesson's slot. The app works
-- out the slot (the programme moves with postponed weeks) and passes it.
create or replace function public.share_prep(
  p_prep  uuid,
  p_month int,
  p_week  int,
  p_grade int
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'only the admin can share a prep' using errcode = '42501';
  end if;
  update public.servant_lesson_preps
     set shared_at = now(),
         shared_month = p_month,
         shared_week = p_week,
         shared_grade = p_grade
   where id = p_prep and status = 'accepted';
  if not found then
    raise exception 'only an accepted prep can be shared' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.unshare_prep(p_prep uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'only the admin can unshare a prep' using errcode = '42501';
  end if;
  update public.servant_lesson_preps
     set shared_at = null, shared_month = null, shared_week = null, shared_grade = null
   where id = p_prep;
end;
$$;

revoke all on function public.share_prep(uuid, int, int, int) from public, anon;
grant execute on function public.share_prep(uuid, int, int, int) to authenticated;
revoke all on function public.unshare_prep(uuid) from public, anon;
grant execute on function public.unshare_prep(uuid) to authenticated;

-- The shared preps of one lesson: who prepared it, for which Saturday, and the
-- files. Only what an example needs; nothing about the review.
create or replace function public.shared_preps(p_month int, p_week int, p_grade int)
returns table (
  prep_id       uuid,
  servant_name  text,
  session_date  date,
  storage_paths text[]
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select lp.id, p.full_name, s.session_date,
         coalesce(array(
           select ph.storage_path from public.servant_lesson_prep_photos ph
           where ph.prep_id = lp.id
           order by ph.created_at), '{}'::text[])
  from public.servant_lesson_preps lp
  join public.profiles p on p.id = lp.servant_id
  join public.attendance_sessions s on s.id = lp.session_id
  where public.auth_role() is not null
    and lp.shared_at is not null
    and lp.shared_month = p_month
    and lp.shared_week = p_week
    and lp.shared_grade = p_grade
  order by lp.shared_at desc;
$$;

revoke all on function public.shared_preps(int, int, int) from public, anon;
grant execute on function public.shared_preps(int, int, int) to authenticated;

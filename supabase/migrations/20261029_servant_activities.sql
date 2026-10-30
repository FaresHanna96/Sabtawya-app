-- =============================================================================
-- Servant activity tracking
-- =============================================================================
-- Three activities:
--   1. servant_lesson_preps       – servant submits lesson-prep photos per session
--   2. servant_lesson_prep_photos – photos attached to a submission
--   3. servant_attendances        – admin records Sunday-school / meeting attendance
-- =============================================================================

-- -----------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------

create table public.servant_lesson_preps (
  id            uuid        primary key default gen_random_uuid(),
  servant_id    uuid        not null references public.profiles(id) on delete cascade,
  session_id    uuid        not null references public.attendance_sessions(id) on delete cascade,
  status        text        not null default 'pending'
                              check (status in ('pending', 'accepted', 'commented')),
  admin_comment text,
  reviewed_by   uuid        references public.profiles(id),
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now(),
  unique (servant_id, session_id)
);

create table public.servant_lesson_prep_photos (
  id           uuid        primary key default gen_random_uuid(),
  prep_id      uuid        not null references public.servant_lesson_preps(id) on delete cascade,
  storage_path text        not null,
  created_at   timestamptz not null default now()
);

create table public.servant_attendances (
  id            uuid        primary key default gen_random_uuid(),
  servant_id    uuid        not null references public.profiles(id) on delete cascade,
  activity_type text        not null
                              check (activity_type in ('sunday_school', 'servant_meeting')),
  date          date        not null,
  recorded_by   uuid        not null references public.profiles(id),
  created_at    timestamptz not null default now(),
  unique (servant_id, activity_type, date)
);

-- -----------------------------------------------------------------------
-- RLS – servant_lesson_preps
-- -----------------------------------------------------------------------

alter table public.servant_lesson_preps enable row level security;

create policy slp_select on public.servant_lesson_preps
for select to authenticated
using (public.is_admin() or auth.uid() = servant_id);

create policy slp_insert on public.servant_lesson_preps
for insert to authenticated
with check (auth.uid() = servant_id);

create policy slp_update on public.servant_lesson_preps
for update to authenticated
using  (public.is_admin())
with check (public.is_admin());

create policy slp_delete on public.servant_lesson_preps
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------
-- RLS – servant_lesson_prep_photos
-- -----------------------------------------------------------------------

alter table public.servant_lesson_prep_photos enable row level security;

create policy slpp_select on public.servant_lesson_prep_photos
for select to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.servant_lesson_preps p
    where p.id = prep_id and p.servant_id = auth.uid()
  )
);

create policy slpp_insert on public.servant_lesson_prep_photos
for insert to authenticated
with check (
  exists (
    select 1 from public.servant_lesson_preps p
    where p.id = prep_id and p.servant_id = auth.uid()
  )
);

create policy slpp_delete on public.servant_lesson_prep_photos
for delete to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.servant_lesson_preps p
    where p.id = prep_id and p.servant_id = auth.uid()
  )
);

-- -----------------------------------------------------------------------
-- RLS – servant_attendances
-- -----------------------------------------------------------------------

alter table public.servant_attendances enable row level security;

create policy sa_select on public.servant_attendances
for select to authenticated
using (public.is_admin() or auth.uid() = servant_id);

create policy sa_insert on public.servant_attendances
for insert to authenticated
with check (public.is_admin());

create policy sa_update on public.servant_attendances
for update to authenticated
using  (public.is_admin())
with check (public.is_admin());

create policy sa_delete on public.servant_attendances
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------
-- Storage bucket: servant-submissions (created manually in Supabase dashboard
-- as a private bucket; policies below reference it once it exists)
-- -----------------------------------------------------------------------

-- SELECT: admin sees all; servant sees paths whose first segment is a prep they own
insert into storage.buckets (id, name, public)
values ('servant-submissions', 'servant-submissions', false)
on conflict (id) do nothing;

create policy ss_select on storage.objects
for select to authenticated
using (
  bucket_id = 'servant-submissions'
  and (
    public.is_admin()
    or exists (
      select 1 from public.servant_lesson_preps p
      where p.id = (split_part(name, '/', 1))::uuid
        and p.servant_id = auth.uid()
    )
  )
);

create policy ss_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'servant-submissions'
  and exists (
    select 1 from public.servant_lesson_preps p
    where p.id = (split_part(name, '/', 1))::uuid
      and p.servant_id = auth.uid()
  )
);

create policy ss_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'servant-submissions'
  and (
    public.is_admin()
    or exists (
      select 1 from public.servant_lesson_preps p
      where p.id = (split_part(name, '/', 1))::uuid
        and p.servant_id = auth.uid()
    )
  )
);

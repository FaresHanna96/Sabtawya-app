-- Private health / special-needs notes for a child (allergies, family
-- situation ...), readable and writable only by the servants of the child's
-- class and by admins.
--
-- A separate table, not a column of children: children_select also lets the
-- general servant read every column of every child, and row level security
-- cannot hide one column. can_access_class() is "admin or serves the class" and
-- does not include the general servant, which is exactly who must not see this.
--
-- The text is deliberately not copied into activity_log (admin-readable, kept
-- in backups of the log).

create table if not exists public.child_private_notes (
  child_id     uuid primary key references public.children (id) on delete cascade,
  health_notes text,
  updated_by   uuid references public.profiles (id) on delete set null,
  updated_at   timestamptz not null default now()
);

alter table public.child_private_notes enable row level security;

drop policy if exists child_private_notes_select on public.child_private_notes;
create policy child_private_notes_select on public.child_private_notes
  for select to authenticated
  using (exists (
    select 1 from public.children c
    where c.id = child_private_notes.child_id
      and public.can_access_class(c.class_id)));

drop policy if exists child_private_notes_insert on public.child_private_notes;
create policy child_private_notes_insert on public.child_private_notes
  for insert to authenticated
  with check (exists (
    select 1 from public.children c
    where c.id = child_private_notes.child_id
      and public.can_access_class(c.class_id)));

drop policy if exists child_private_notes_update on public.child_private_notes;
create policy child_private_notes_update on public.child_private_notes
  for update to authenticated
  using (exists (
    select 1 from public.children c
    where c.id = child_private_notes.child_id
      and public.can_access_class(c.class_id)))
  with check (exists (
    select 1 from public.children c
    where c.id = child_private_notes.child_id
      and public.can_access_class(c.class_id)));

-- Clearing a note deletes the row; same people as above.
drop policy if exists child_private_notes_delete on public.child_private_notes;
create policy child_private_notes_delete on public.child_private_notes
  for delete to authenticated
  using (exists (
    select 1 from public.children c
    where c.id = child_private_notes.child_id
      and public.can_access_class(c.class_id)));

revoke all on public.child_private_notes from anon;
grant select, insert, update, delete on public.child_private_notes to authenticated;

create or replace function public.child_private_notes_stamp()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists child_private_notes_stamp on public.child_private_notes;
create trigger child_private_notes_stamp
  before insert or update on public.child_private_notes
  for each row execute function public.child_private_notes_stamp();

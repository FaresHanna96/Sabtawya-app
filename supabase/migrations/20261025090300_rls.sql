-- =============================================================================
-- 04 - Row Level Security
-- =============================================================================
-- This file is the real access control for Sabtawya. Hiding buttons in the app
-- is cosmetic; a servant who crafts their own request still cannot read or
-- write anything outside the classes they are assigned to.
-- =============================================================================

alter table public.profiles            enable row level security;
alter table public.servant_invites     enable row level security;
alter table public.classes             enable row level security;
alter table public.class_servants      enable row level security;
alter table public.children            enable row level security;
alter table public.attendance_years    enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records  enable row level security;
alter table public.activity_log        enable row level security;

-- Nothing is reachable without a session.
revoke all on all tables in schema public from anon;

grant select, insert, update, delete on
  public.profiles,
  public.servant_invites,
  public.classes,
  public.class_servants,
  public.children,
  public.attendance_years,
  public.attendance_sessions,
  public.attendance_records
to authenticated;

grant select on public.activity_log to authenticated;

-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or public.is_admin()
  -- A servant may see the co-servants of the classes they serve.
  or exists (
    select 1
    from public.class_servants cs
    where cs.servant_id = profiles.id
      and public.serves_class(cs.class_id)
  )
);

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
for update to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());
-- profiles_guard() still blocks a non-admin from editing role or is_active.

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
for insert to authenticated
with check (public.is_admin());

drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------------
-- servant_invites : admin only
-- -----------------------------------------------------------------------------
drop policy if exists servant_invites_all on public.servant_invites;
create policy servant_invites_all on public.servant_invites
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- classes : a servant sees only assigned classes and can never change them
-- -----------------------------------------------------------------------------
drop policy if exists classes_select on public.classes;
create policy classes_select on public.classes
for select to authenticated
using (public.is_admin() or public.serves_class(id));

drop policy if exists classes_insert on public.classes;
create policy classes_insert on public.classes
for insert to authenticated
with check (public.is_admin());

drop policy if exists classes_update on public.classes;
create policy classes_update on public.classes
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists classes_delete on public.classes;
create policy classes_delete on public.classes
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------------
-- class_servants : only an admin assigns, removes, or switches servants
-- -----------------------------------------------------------------------------
drop policy if exists class_servants_select on public.class_servants;
create policy class_servants_select on public.class_servants
for select to authenticated
using (
  public.is_admin()
  or servant_id = auth.uid()
  or public.serves_class(class_id)
);

drop policy if exists class_servants_insert on public.class_servants;
create policy class_servants_insert on public.class_servants
for insert to authenticated
with check (public.is_admin());

drop policy if exists class_servants_update on public.class_servants;
create policy class_servants_update on public.class_servants
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists class_servants_delete on public.class_servants;
create policy class_servants_delete on public.class_servants
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------------
-- children
-- -----------------------------------------------------------------------------
drop policy if exists children_select on public.children;
create policy children_select on public.children
for select to authenticated
using (public.can_access_class(class_id));

-- A servant may add a child, but only into a class they are assigned to.
drop policy if exists children_insert on public.children;
create policy children_insert on public.children
for insert to authenticated
with check (public.can_access_class(class_id));

-- USING guards the row as it is now, WITH CHECK guards the row after the edit.
-- Together they stop a servant from moving a child into a class they do not
-- serve, which is what makes "move child" effectively admin-only.
drop policy if exists children_update on public.children;
create policy children_update on public.children
for update to authenticated
using (public.can_access_class(class_id))
with check (public.can_access_class(class_id));

-- Deactivation is the supported path; hard delete stays with the admin.
drop policy if exists children_delete on public.children;
create policy children_delete on public.children
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------------
-- attendance_years : readable by all, managed by the admin
-- -----------------------------------------------------------------------------
drop policy if exists attendance_years_select on public.attendance_years;
create policy attendance_years_select on public.attendance_years
for select to authenticated
using (true);

drop policy if exists attendance_years_write on public.attendance_years;
create policy attendance_years_write on public.attendance_years
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- attendance_sessions
-- -----------------------------------------------------------------------------
drop policy if exists attendance_sessions_select on public.attendance_sessions;
create policy attendance_sessions_select on public.attendance_sessions
for select to authenticated
using (public.can_access_class(class_id));

drop policy if exists attendance_sessions_insert on public.attendance_sessions;
create policy attendance_sessions_insert on public.attendance_sessions
for insert to authenticated
with check (public.can_access_class(class_id));

drop policy if exists attendance_sessions_update on public.attendance_sessions;
create policy attendance_sessions_update on public.attendance_sessions
for update to authenticated
using (public.can_access_class(class_id))
with check (public.can_access_class(class_id));
-- attendance_sessions_guard() keeps is_locked admin-only.

drop policy if exists attendance_sessions_delete on public.attendance_sessions;
create policy attendance_sessions_delete on public.attendance_sessions
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------------
-- attendance_records : reachable only through a session of an allowed class
-- -----------------------------------------------------------------------------
drop policy if exists attendance_records_select on public.attendance_records;
create policy attendance_records_select on public.attendance_records
for select to authenticated
using (
  exists (
    select 1 from public.attendance_sessions s
    where s.id = attendance_records.session_id
      and public.can_access_class(s.class_id)
  )
);

drop policy if exists attendance_records_insert on public.attendance_records;
create policy attendance_records_insert on public.attendance_records
for insert to authenticated
with check (
  exists (
    select 1 from public.attendance_sessions s
    where s.id = attendance_records.session_id
      and public.can_access_class(s.class_id)
  )
);

drop policy if exists attendance_records_update on public.attendance_records;
create policy attendance_records_update on public.attendance_records
for update to authenticated
using (
  exists (
    select 1 from public.attendance_sessions s
    where s.id = attendance_records.session_id
      and public.can_access_class(s.class_id)
  )
)
with check (
  exists (
    select 1 from public.attendance_sessions s
    where s.id = attendance_records.session_id
      and public.can_access_class(s.class_id)
  )
);
-- attendance_records_apply_scoring() recomputes the score, rejects a child from
-- another class, and refuses edits to a locked session.

drop policy if exists attendance_records_delete on public.attendance_records;
create policy attendance_records_delete on public.attendance_records
for delete to authenticated
using (public.is_admin());

-- -----------------------------------------------------------------------------
-- activity_log : admin only, written by SECURITY DEFINER triggers
-- -----------------------------------------------------------------------------
drop policy if exists activity_log_select on public.activity_log;
create policy activity_log_select on public.activity_log
for select to authenticated
using (public.is_admin());

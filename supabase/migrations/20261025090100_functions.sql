-- =============================================================================
-- 02 - Functions and triggers
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Authorization helpers
-- -----------------------------------------------------------------------------
-- SECURITY DEFINER so they can read profiles/class_servants without being
-- blocked by the very policies that call them, which would recurse.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select p.role = 'admin' from public.profiles p where p.id = auth.uid() and p.is_active),
    false
  );
$$;

create or replace function public.auth_role()
returns public.app_role
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.role from public.profiles p where p.id = auth.uid() and p.is_active;
$$;

-- True when the caller is an active servant assigned to this class.
create or replace function public.serves_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.class_servants cs
    join public.profiles p on p.id = cs.servant_id
    where cs.class_id = p_class_id
      and cs.servant_id = auth.uid()
      and p.is_active
  );
$$;

create or replace function public.can_access_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_admin() or public.serves_class(p_class_id);
$$;

-- -----------------------------------------------------------------------------
-- updated_at bookkeeping
-- -----------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists classes_touch on public.classes;
create trigger classes_touch before update on public.classes
  for each row execute function public.touch_updated_at();

drop trigger if exists attendance_years_touch on public.attendance_years;
create trigger attendance_years_touch before update on public.attendance_years
  for each row execute function public.touch_updated_at();

-- -----------------------------------------------------------------------------
-- Child audit columns
-- -----------------------------------------------------------------------------
create or replace function public.children_stamp()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, auth.uid());
    new.created_at := now();
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  new.full_name  := btrim(new.full_name);
  new.code       := nullif(btrim(coalesce(new.code, '')), '');

  if new.birth_date is not null and new.birth_date > current_date then
    raise exception 'تاريخ الميلاد لا يمكن أن يكون في المستقبل' using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists children_stamp_trg on public.children;
create trigger children_stamp_trg before insert or update on public.children
  for each row execute function public.children_stamp();

-- -----------------------------------------------------------------------------
-- Profile guard: only an admin may change role or activation
-- -----------------------------------------------------------------------------
create or replace function public.profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'غير مصرح لك بتغيير الصلاحية' using errcode = '42501';
  end if;

  if new.is_active is distinct from old.is_active then
    raise exception 'غير مصرح لك بتغيير حالة التنشيط' using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_guard_trg on public.profiles;
create trigger profiles_guard_trg before update on public.profiles
  for each row execute function public.profiles_guard();

-- -----------------------------------------------------------------------------
-- Attendance scoring: derived from the attendance year, never sent by the client
-- -----------------------------------------------------------------------------
create or replace function public.attendance_records_apply_scoring()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_points_sunday_school smallint;
  v_points_vespers       smallint;
  v_points_mass          smallint;
  v_max_points           integer;
  v_class_id             uuid;
  v_is_locked            boolean;
begin
  select ay.points_sunday_school,
         ay.points_vespers,
         ay.points_mass,
         ay.max_points_per_session,
         s.class_id,
         s.is_locked
    into v_points_sunday_school,
         v_points_vespers,
         v_points_mass,
         v_max_points,
         v_class_id,
         v_is_locked
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  where s.id = new.session_id;

  if v_class_id is null then
    raise exception 'جلسة الحضور غير موجودة' using errcode = '23503';
  end if;

  if v_is_locked and not public.is_admin() then
    raise exception 'تم إغلاق هذه الجلسة ولا يمكن تعديلها' using errcode = '42501';
  end if;

  -- Integrity: a record may only exist for a child of the session's class.
  if not exists (
    select 1 from public.children c
    where c.id = new.child_id and c.class_id = v_class_id
  ) then
    raise exception 'المخدوم لا ينتمي إلى فصل هذه الجلسة' using errcode = '23514';
  end if;

  new.score := (case when new.sunday_school then v_points_sunday_school else 0 end)
             + (case when new.vespers       then v_points_vespers       else 0 end)
             + (case when new.mass          then v_points_mass          else 0 end);
  new.max_score  := v_max_points;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);

  if tg_op = 'INSERT' then
    new.created_at := now();
    new.created_by := coalesce(new.created_by, auth.uid());
  end if;

  return new;
end;
$$;

drop trigger if exists attendance_records_scoring on public.attendance_records;
create trigger attendance_records_scoring
  before insert or update on public.attendance_records
  for each row execute function public.attendance_records_apply_scoring();

-- -----------------------------------------------------------------------------
-- Only an admin may lock or unlock a session
-- -----------------------------------------------------------------------------
create or replace function public.attendance_sessions_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.is_locked is distinct from old.is_locked and not public.is_admin() then
    raise exception 'غير مصرح لك بإغلاق أو فتح الجلسات' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists attendance_sessions_guard_trg on public.attendance_sessions;
create trigger attendance_sessions_guard_trg before update on public.attendance_sessions
  for each row execute function public.attendance_sessions_guard();

-- -----------------------------------------------------------------------------
-- Session generation for an attendance year
-- -----------------------------------------------------------------------------
-- Internal worker: no permission check so triggers can call it.
create or replace function public.generate_sessions_internal(
  p_year_id  uuid,
  p_class_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_year     public.attendance_years;
  v_first    date;
  v_inserted integer;
begin
  select * into v_year from public.attendance_years where id = p_year_id;
  if v_year.id is null then
    raise exception 'سنة الحضور غير موجودة' using errcode = 'P0002';
  end if;

  -- First attendance weekday on or after the start date.
  v_first := v_year.start_date
           + ((v_year.session_weekday - extract(isodow from v_year.start_date)::int + 7) % 7);

  with days as (
    select generate_series(v_first, v_year.end_date, interval '7 days')::date as session_date
  ),
  target_classes as (
    select c.id
    from public.classes c
    where c.is_active
      and (p_class_id is null or c.id = p_class_id)
  )
  insert into public.attendance_sessions (year_id, class_id, session_date)
  select p_year_id, tc.id, d.session_date
  from target_classes tc
  cross join days d
  on conflict (class_id, session_date) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

-- Admin-facing wrapper, called by the app.
create or replace function public.generate_sessions_for_year(
  p_year_id  uuid,
  p_class_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return public.generate_sessions_internal(p_year_id, p_class_id);
end;
$$;

-- A brand new class immediately gets the current year's Saturdays.
create or replace function public.classes_backfill_sessions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_year_id uuid;
begin
  select id into v_year_id from public.attendance_years where is_current limit 1;
  if v_year_id is not null and new.is_active then
    perform public.generate_sessions_internal(v_year_id, new.id);
  end if;
  return null;
end;
$$;

drop trigger if exists classes_backfill_sessions_trg on public.classes;
create trigger classes_backfill_sessions_trg after insert on public.classes
  for each row execute function public.classes_backfill_sessions();

-- Marking a year current fills in any missing sessions.
create or replace function public.attendance_years_backfill_sessions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.is_current then
    perform public.generate_sessions_internal(new.id, null);
  end if;
  return null;
end;
$$;

drop trigger if exists attendance_years_backfill_trg on public.attendance_years;
create trigger attendance_years_backfill_trg after insert or update of is_current
  on public.attendance_years
  for each row execute function public.attendance_years_backfill_sessions();

-- -----------------------------------------------------------------------------
-- Exactly one current year
-- -----------------------------------------------------------------------------
create or replace function public.set_current_attendance_year(p_year_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;

  update public.attendance_years set is_current = false where is_current and id <> p_year_id;
  update public.attendance_years set is_current = true where id = p_year_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Servant onboarding: apply the admin's invite when the user signs up
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invite public.servant_invites;
  v_name   text;
begin
  select * into v_invite
  from public.servant_invites
  where lower(email) = lower(new.email)
    and accepted_at is null
  limit 1;

  v_name := coalesce(
    nullif(btrim(v_invite.full_name), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(coalesce(new.email, 'user'), '@', 1)
  );

  -- No invite means no access until an admin activates the account. The
  -- client-supplied metadata is deliberately never trusted for the role.
  insert into public.profiles (id, full_name, email, mobile, role, is_active)
  values (
    new.id,
    v_name,
    new.email,
    coalesce(v_invite.mobile, nullif(btrim(new.raw_user_meta_data ->> 'mobile'), '')),
    coalesce(v_invite.role, 'servant'),
    v_invite.id is not null
  )
  on conflict (id) do nothing;

  if v_invite.id is not null then
    insert into public.class_servants (class_id, servant_id, assigned_by)
    select unnest(v_invite.class_ids), new.id, v_invite.created_by
    on conflict (class_id, servant_id) do nothing;

    update public.servant_invites
    set accepted_at = now(), accepted_profile_id = new.id
    where id = v_invite.id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- One-off bootstrap helper, run from the SQL editor to create the first admin.
create or replace function public.promote_to_admin(p_email text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.profiles
  set role = 'admin', is_active = true
  where lower(email) = lower(p_email);

  if not found then
    raise exception 'لا يوجد مستخدم بهذا البريد: %', p_email using errcode = 'P0002';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Activity log
-- -----------------------------------------------------------------------------
create or replace function public.write_activity_log()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row     record;
  v_actor   text;
  v_details jsonb := '{}'::jsonb;
begin
  v_row := coalesce(new, old);
  select full_name into v_actor from public.profiles where id = auth.uid();

  if tg_table_name = 'children' then
    v_details := jsonb_build_object('name', v_row.full_name, 'class_id', v_row.class_id);
  elsif tg_table_name = 'attendance_records' then
    v_details := jsonb_build_object('session_id', v_row.session_id, 'score', v_row.score);
  elsif tg_table_name = 'class_servants' then
    v_details := jsonb_build_object('class_id', v_row.class_id, 'servant_id', v_row.servant_id);
  end if;

  insert into public.activity_log (actor_id, actor_name, action, entity, entity_id, details)
  values (auth.uid(), v_actor, lower(tg_op), tg_table_name, v_row.id::text, v_details);

  return null;
end;
$$;

drop trigger if exists children_activity on public.children;
create trigger children_activity after insert or update or delete on public.children
  for each row execute function public.write_activity_log();

drop trigger if exists attendance_records_activity on public.attendance_records;
create trigger attendance_records_activity after insert or update on public.attendance_records
  for each row execute function public.write_activity_log();

drop trigger if exists class_servants_activity on public.class_servants;
create trigger class_servants_activity after insert or delete on public.class_servants
  for each row execute function public.write_activity_log();

-- -----------------------------------------------------------------------------
-- Execution grants
-- -----------------------------------------------------------------------------
grant execute on function public.is_admin()                             to authenticated;
grant execute on function public.auth_role()                            to authenticated;
grant execute on function public.serves_class(uuid)                     to authenticated;
grant execute on function public.can_access_class(uuid)                 to authenticated;
grant execute on function public.generate_sessions_for_year(uuid, uuid) to authenticated;
grant execute on function public.set_current_attendance_year(uuid)      to authenticated;

revoke all on function public.promote_to_admin(text)                 from public;
revoke all on function public.generate_sessions_internal(uuid, uuid) from public;

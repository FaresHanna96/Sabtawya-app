-- >>> 20261025090000_schema.sql
-- =============================================================================
-- Sabtawya â€” Multi-Class Attendance Management System
-- 01 - Core schema
-- =============================================================================
-- Terminology: a *servant* (Ø®Ø§Ø¯Ù…) serves one or more classes; a *child*
-- (Ù…Ø®Ø¯ÙˆÙ…) is a boy or girl enrolled in exactly one class.
--
-- Entity chain:
--   profiles -> classes -> class_servants -> children
--            -> attendance_years -> attendance_sessions -> attendance_records
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('admin', 'servant');
  end if;

  if not exists (select 1 from pg_type where typname = 'child_gender') then
    create type public.child_gender as enum ('boy', 'girl');
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- profiles : one row per authenticated user
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text        not null,
  email       text,
  mobile      text,
  role        public.app_role not null default 'servant',
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles (role) where is_active;
create index if not exists profiles_email_idx on public.profiles (lower(email));

comment on table public.profiles is
  'Application user: an admin or a servant. Role drives every RLS policy.';

-- -----------------------------------------------------------------------------
-- servant_invites : how an admin onboards a servant from the mobile app
-- -----------------------------------------------------------------------------
-- A mobile client never holds the service-role key, so it cannot create auth
-- users. The admin records an invite instead; when that email signs up the
-- handle_new_user trigger applies the invited role and class assignments.
-- A sign-up with no matching invite lands inactive with no class.
create table if not exists public.servant_invites (
  id                  uuid primary key default gen_random_uuid(),
  email               text        not null,
  full_name           text        not null,
  mobile              text,
  role                public.app_role not null default 'servant',
  class_ids           uuid[]      not null default '{}',
  created_by          uuid        references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now(),
  accepted_at         timestamptz,
  accepted_profile_id uuid        references public.profiles (id) on delete set null
);

create unique index if not exists servant_invites_email_key
  on public.servant_invites (lower(email));

-- -----------------------------------------------------------------------------
-- classes
-- -----------------------------------------------------------------------------
create table if not exists public.classes (
  id          uuid primary key default gen_random_uuid(),
  name        text        not null,
  description text,
  sort_order  integer     not null default 0,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint classes_name_key unique (name)
);

create index if not exists classes_active_idx on public.classes (sort_order) where is_active;

-- -----------------------------------------------------------------------------
-- class_servants : many-to-many, one servant -> many classes and vice versa
-- -----------------------------------------------------------------------------
create table if not exists public.class_servants (
  id          uuid primary key default gen_random_uuid(),
  class_id    uuid        not null references public.classes (id) on delete cascade,
  servant_id  uuid        not null references public.profiles (id) on delete cascade,
  assigned_at timestamptz not null default now(),
  assigned_by uuid        references public.profiles (id) on delete set null,
  constraint class_servants_unique unique (class_id, servant_id)
);

create index if not exists class_servants_servant_idx on public.class_servants (servant_id);
create index if not exists class_servants_class_idx on public.class_servants (class_id);

-- -----------------------------------------------------------------------------
-- children : the single source of truth for a child's data
-- -----------------------------------------------------------------------------
create table if not exists public.children (
  id            uuid primary key default gen_random_uuid(),
  class_id      uuid        not null references public.classes (id) on delete restrict,
  code          text,
  full_name     text        not null,
  gender        public.child_gender not null,
  birth_date    date,
  mobile        text,
  mother_name   text,
  mother_mobile text,
  father_name   text,
  father_mobile text,
  -- Ø£Ø¨ Ø§Ù„Ø§Ø¹ØªØ±Ø§Ù: the child's confession father.
  confession_father text,
  school        text,
  address       text,
  notes         text,
  is_active     boolean     not null default true,
  created_at    timestamptz not null default now(),
  created_by    uuid        references public.profiles (id) on delete set null,
  updated_at    timestamptz not null default now(),
  updated_by    uuid        references public.profiles (id) on delete set null,
  constraint children_name_not_blank check (length(btrim(full_name)) > 0),
  -- A CHECK constraint must be immutable, so it only catches a mistyped year.
  -- children_stamp() rejects a birth date in the future.
  constraint children_birth_date_sane check (
    birth_date is null or birth_date > date '1950-01-01'
  )
);

-- Business key used by Excel import to update instead of duplicating.
create sequence if not exists public.children_code_seq;

create unique index if not exists children_code_key on public.children (code);

create index if not exists children_class_idx on public.children (class_id) where is_active;
create index if not exists children_name_idx on public.children (full_name);

comment on column public.children.code is
  'Auto-issued business key (C001, C002, …). Used by Excel import to match an existing child.';

-- -----------------------------------------------------------------------------
-- attendance_years : the scoring configuration lives here, not in code
-- -----------------------------------------------------------------------------
create table if not exists public.attendance_years (
  id                     uuid primary key default gen_random_uuid(),
  name                   text        not null,
  start_date             date        not null,
  end_date               date        not null,
  -- ISO day of week for the attendance day: 1 = Monday ... 6 = Saturday, 7 = Sunday
  session_weekday        smallint    not null default 6,
  points_sunday_school   smallint    not null default 5,
  points_vespers         smallint    not null default 5,
  points_mass            smallint    not null default 5,
  max_points_per_session integer generated always as
    (points_sunday_school + points_vespers + points_mass) stored,
  is_current             boolean     not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint attendance_years_name_key unique (name),
  constraint attendance_years_range check (end_date > start_date),
  constraint attendance_years_weekday check (session_weekday between 1 and 7),
  constraint attendance_years_points check (
    points_sunday_school >= 0 and points_vespers >= 0 and points_mass >= 0
  )
);

-- At most one current year.
create unique index if not exists attendance_years_single_current
  on public.attendance_years (is_current) where is_current;

-- -----------------------------------------------------------------------------
-- attendance_sessions : one row per (class, attendance day)
-- -----------------------------------------------------------------------------
create table if not exists public.attendance_sessions (
  id           uuid primary key default gen_random_uuid(),
  year_id      uuid        not null references public.attendance_years (id) on delete cascade,
  class_id     uuid        not null references public.classes (id) on delete cascade,
  session_date date        not null,
  is_locked    boolean     not null default false,
  notes        text,
  created_at   timestamptz not null default now(),
  constraint attendance_sessions_unique unique (class_id, session_date)
);

create index if not exists attendance_sessions_year_idx
  on public.attendance_sessions (year_id, session_date);
create index if not exists attendance_sessions_class_date_idx
  on public.attendance_sessions (class_id, session_date desc);

-- -----------------------------------------------------------------------------
-- attendance_records : three activities, score derived from the year config
-- -----------------------------------------------------------------------------
-- Records reference the child row by id only. A child's name is never copied
-- here, so a rename updates every screen and report at once.
create table if not exists public.attendance_records (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid        not null references public.attendance_sessions (id) on delete cascade,
  child_id      uuid        not null references public.children (id) on delete cascade,
  sunday_school boolean     not null default false,
  vespers       boolean     not null default false,
  mass          boolean     not null default false,
  score         integer     not null default 0,
  max_score     integer     not null default 15,
  created_at    timestamptz not null default now(),
  created_by    uuid        references public.profiles (id) on delete set null,
  updated_at    timestamptz not null default now(),
  updated_by    uuid        references public.profiles (id) on delete set null,
  constraint attendance_records_unique unique (session_id, child_id)
);

create index if not exists attendance_records_child_idx
  on public.attendance_records (child_id);
create index if not exists attendance_records_session_idx
  on public.attendance_records (session_id);

-- -----------------------------------------------------------------------------
-- activity_log : feeds the admin "recent activity" panel
-- -----------------------------------------------------------------------------
create table if not exists public.activity_log (
  id         bigserial primary key,
  actor_id   uuid        references public.profiles (id) on delete set null,
  actor_name text,
  action     text        not null,
  entity     text        not null,
  entity_id  text,
  details    jsonb       not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists activity_log_created_idx on public.activity_log (created_at desc);


-- >>> 20261025090100_functions.sql
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
    new.code := 'C' || lpad(nextval('public.children_code_seq')::text, 3, '0');
  else
    new.code := old.code;
  end if;

  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  new.full_name  := btrim(new.full_name);

  if new.birth_date is not null and new.birth_date > current_date then
    raise exception 'ØªØ§Ø±ÙŠØ® Ø§Ù„Ù…ÙŠÙ„Ø§Ø¯ Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø£Ù† ÙŠÙƒÙˆÙ† ÙÙŠ Ø§Ù„Ù…Ø³ØªÙ‚Ø¨Ù„' using errcode = '23514';
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
    raise exception 'ØºÙŠØ± Ù…ØµØ±Ø­ Ù„Ùƒ Ø¨ØªØºÙŠÙŠØ± Ø§Ù„ØµÙ„Ø§Ø­ÙŠØ©' using errcode = '42501';
  end if;

  if new.is_active is distinct from old.is_active then
    raise exception 'ØºÙŠØ± Ù…ØµØ±Ø­ Ù„Ùƒ Ø¨ØªØºÙŠÙŠØ± Ø­Ø§Ù„Ø© Ø§Ù„ØªÙ†Ø´ÙŠØ·' using errcode = '42501';
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
    raise exception 'Ø¬Ù„Ø³Ø© Ø§Ù„Ø­Ø¶ÙˆØ± ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯Ø©' using errcode = '23503';
  end if;

  if v_is_locked and not public.is_admin() then
    raise exception 'ØªÙ… Ø¥ØºÙ„Ø§Ù‚ Ù‡Ø°Ù‡ Ø§Ù„Ø¬Ù„Ø³Ø© ÙˆÙ„Ø§ ÙŠÙ…ÙƒÙ† ØªØ¹Ø¯ÙŠÙ„Ù‡Ø§' using errcode = '42501';
  end if;

  -- Integrity: a record may only exist for a child of the session's class.
  if not exists (
    select 1 from public.children c
    where c.id = new.child_id and c.class_id = v_class_id
  ) then
    raise exception 'Ø§Ù„Ù…Ø®Ø¯ÙˆÙ… Ù„Ø§ ÙŠÙ†ØªÙ…ÙŠ Ø¥Ù„Ù‰ ÙØµÙ„ Ù‡Ø°Ù‡ Ø§Ù„Ø¬Ù„Ø³Ø©' using errcode = '23514';
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
    raise exception 'ØºÙŠØ± Ù…ØµØ±Ø­ Ù„Ùƒ Ø¨Ø¥ØºÙ„Ø§Ù‚ Ø£Ùˆ ÙØªØ­ Ø§Ù„Ø¬Ù„Ø³Ø§Øª' using errcode = '42501';
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
    raise exception 'Ø³Ù†Ø© Ø§Ù„Ø­Ø¶ÙˆØ± ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯Ø©' using errcode = 'P0002';
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
    raise exception 'ØºÙŠØ± Ù…ØµØ±Ø­' using errcode = '42501';
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
    raise exception 'ØºÙŠØ± Ù…ØµØ±Ø­' using errcode = '42501';
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
    raise exception 'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ù…Ø³ØªØ®Ø¯Ù… Ø¨Ù‡Ø°Ø§ Ø§Ù„Ø¨Ø±ÙŠØ¯: %', p_email using errcode = 'P0002';
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


-- >>> 20261025090200_views.sql
-- =============================================================================
-- 03 - Reporting views
-- =============================================================================
-- Every view uses security_invoker so the caller's RLS policies still apply.
-- A servant querying these sees only their own classes.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Class overview: powers both dashboards and the classes list
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
  (select max(s.session_date)
     from public.attendance_sessions s
    where s.class_id = c.id and s.session_date <= current_date) as last_session_date
from public.classes c;

-- -----------------------------------------------------------------------------
-- Servant assignments, flattened for display
-- -----------------------------------------------------------------------------
create or replace view public.v_class_servants
with (security_invoker = true) as
select
  cs.id         as assignment_id,
  cs.class_id,
  c.name        as class_name,
  cs.servant_id,
  p.full_name   as servant_name,
  p.email       as servant_email,
  p.mobile      as servant_mobile,
  p.is_active   as servant_is_active,
  cs.assigned_at
from public.class_servants cs
join public.profiles p on p.id = cs.servant_id
join public.classes  c on c.id = cs.class_id;

-- -----------------------------------------------------------------------------
-- One row per child per attendance day, with the class it was taken in
-- -----------------------------------------------------------------------------
create or replace view public.v_session_scores
with (security_invoker = true) as
select
  r.id          as record_id,
  s.id          as session_id,
  s.year_id,
  s.class_id,
  c.name        as class_name,
  s.session_date,
  s.is_locked,
  ch.id         as child_id,
  ch.full_name  as child_name,
  ch.gender,
  ch.is_active  as child_is_active,
  r.sunday_school,
  r.vespers,
  r.mass,
  r.score,
  r.max_score,
  r.updated_at,
  r.updated_by,
  p.full_name   as updated_by_name
from public.attendance_records r
join public.attendance_sessions s on s.id = r.session_id
join public.classes            c on c.id = s.class_id
join public.children          ch on ch.id = r.child_id
left join public.profiles      p on p.id = r.updated_by;

-- -----------------------------------------------------------------------------
-- Per-class progress for one attendance day, used by the history screen
-- -----------------------------------------------------------------------------
create or replace view public.v_class_session_summary
with (security_invoker = true) as
select
  s.id           as session_id,
  s.year_id,
  s.class_id,
  s.session_date,
  s.is_locked,
  s.notes,
  count(r.id)                                      as recorded_count,
  count(r.id) filter (where r.score > 0)           as present_count,
  coalesce(sum(r.score), 0)::int                   as points,
  coalesce(sum(r.max_score), 0)::int               as max_points,
  (select count(*)
     from public.children ch
    where ch.class_id = s.class_id and ch.is_active) as active_children
from public.attendance_sessions s
left join public.attendance_records r on r.session_id = s.id
group by s.id, s.year_id, s.class_id, s.session_date, s.is_locked, s.notes;

-- -----------------------------------------------------------------------------
-- Monthly rollup
-- -----------------------------------------------------------------------------
-- The maximum comes from the attendance calendar, not from the rows a servant
-- happened to save, so a month with no data still reports the right ceiling.
-- Earned points come from the child's own records regardless of which class the
-- session belonged to, so moving a child never loses history.
create or replace view public.v_child_monthly_scores
with (security_invoker = true) as
with calendar as (
  select
    s.year_id,
    date_trunc('month', s.session_date)::date                  as month_start,
    count(distinct s.session_date)                             as sessions_total,
    count(distinct s.session_date) * ay.max_points_per_session as max_points
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  group by s.year_id, date_trunc('month', s.session_date), ay.max_points_per_session
),
earned as (
  select
    r.child_id,
    s.year_id,
    date_trunc('month', s.session_date)::date  as month_start,
    sum(r.score)::int                          as points,
    count(*) filter (where r.score > 0)        as sessions_attended
  from public.attendance_records r
  join public.attendance_sessions s on s.id = r.session_id
  group by r.child_id, s.year_id, date_trunc('month', s.session_date)
)
select
  ch.id                                  as child_id,
  ch.class_id,
  cal.year_id,
  cal.month_start,
  cal.sessions_total::int                as sessions_total,
  cal.max_points::int                    as max_points,
  coalesce(e.points, 0)::int             as points,
  coalesce(e.sessions_attended, 0)::int  as sessions_attended,
  case
    when cal.max_points > 0
      then round(coalesce(e.points, 0)::numeric * 100 / cal.max_points, 1)
    else 0
  end                                    as percentage
from public.children ch
cross join calendar cal
left join earned e
       on e.child_id    = ch.id
      and e.year_id     = cal.year_id
      and e.month_start = cal.month_start;

-- -----------------------------------------------------------------------------
-- Yearly rollup
-- -----------------------------------------------------------------------------
create or replace view public.v_child_year_scores
with (security_invoker = true) as
select
  m.child_id,
  m.class_id,
  m.year_id,
  sum(m.sessions_total)::int    as sessions_total,
  sum(m.sessions_attended)::int as sessions_attended,
  sum(m.points)::int            as points,
  sum(m.max_points)::int        as max_points,
  case
    when sum(m.max_points) > 0
      then round(sum(m.points)::numeric * 100 / sum(m.max_points), 1)
    else 0
  end                           as percentage
from public.v_child_monthly_scores m
group by m.child_id, m.class_id, m.year_id;

-- -----------------------------------------------------------------------------
-- Report-ready projections that carry names, so exports need no extra joins
-- -----------------------------------------------------------------------------
create or replace view public.v_child_year_report
with (security_invoker = true) as
select
  y.child_id,
  ch.full_name as child_name,
  ch.gender,
  ch.birth_date,
  ch.code      as child_code,
  ch.mobile    as child_mobile,
  ch.school,
  ch.is_active as child_is_active,
  y.class_id,
  c.name       as class_name,
  y.year_id,
  ay.name      as year_name,
  y.sessions_total,
  y.sessions_attended,
  y.points,
  y.max_points,
  y.percentage
from public.v_child_year_scores y
join public.children         ch on ch.id = y.child_id
join public.classes           c on c.id  = y.class_id
join public.attendance_years ay on ay.id = y.year_id;

create or replace view public.v_child_monthly_report
with (security_invoker = true) as
select
  m.child_id,
  ch.full_name as child_name,
  ch.gender,
  ch.is_active as child_is_active,
  m.class_id,
  c.name       as class_name,
  m.year_id,
  m.month_start,
  m.sessions_total,
  m.sessions_attended,
  m.points,
  m.max_points,
  m.percentage
from public.v_child_monthly_scores m
join public.children ch on ch.id = m.child_id
join public.classes   c on c.id  = m.class_id;

-- -----------------------------------------------------------------------------
-- Class standing for a year
-- -----------------------------------------------------------------------------
create or replace view public.v_class_year_scores
with (security_invoker = true) as
select
  y.class_id,
  c.name                  as class_name,
  y.year_id,
  count(*)::int           as children,
  sum(y.points)::int      as points,
  sum(y.max_points)::int  as max_points,
  case
    when sum(y.max_points) > 0
      then round(sum(y.points)::numeric * 100 / sum(y.max_points), 1)
    else 0
  end                     as percentage
from public.v_child_year_scores y
join public.children ch on ch.id = y.child_id
join public.classes   c on c.id  = y.class_id
where ch.is_active
group by y.class_id, c.name, y.year_id;

-- -----------------------------------------------------------------------------
-- Admin dashboard counters
-- -----------------------------------------------------------------------------
create or replace view public.v_admin_stats
with (security_invoker = true) as
select
  (select count(*) from public.classes  where is_active)                        as classes_count,
  (select count(*) from public.profiles where is_active and role = 'servant')   as servants_count,
  (select count(*) from public.profiles where is_active and role = 'admin')     as admins_count,
  (select count(*) from public.children where is_active)                        as children_count,
  (select count(*) from public.children where is_active and gender = 'boy')     as boys_count,
  (select count(*) from public.children where is_active and gender = 'girl')    as girls_count,
  (select min(session_date) from public.attendance_sessions
    where session_date >= current_date)                                         as next_session_date,
  (select coalesce(sum(score), 0)::int from public.attendance_records)          as total_points;

-- -----------------------------------------------------------------------------
-- Grants
-- -----------------------------------------------------------------------------
grant select on public.v_class_overview        to authenticated;
grant select on public.v_class_servants        to authenticated;
grant select on public.v_session_scores        to authenticated;
grant select on public.v_class_session_summary to authenticated;
grant select on public.v_child_monthly_scores  to authenticated;
grant select on public.v_child_year_scores     to authenticated;
grant select on public.v_child_year_report     to authenticated;
grant select on public.v_child_monthly_report  to authenticated;
grant select on public.v_class_year_scores     to authenticated;
grant select on public.v_admin_stats           to authenticated;


-- >>> 20261025090300_rls.sql
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


-- >>> 20261025090400_seed.sql
-- =============================================================================
-- 05 - Seed: attendance year and the eight classes
-- =============================================================================
-- Order matters. The year is inserted first so the classes_backfill_sessions
-- trigger can generate every Saturday for each class as it is created.
--
-- 24 Oct 2026 and 25 Sep 2027 are both Saturdays, giving 49 sessions and a
-- ceiling of 49 x 15 = 735 points for the year.
-- =============================================================================

insert into public.attendance_years (
  name, start_date, end_date, session_weekday,
  points_sunday_school, points_vespers, points_mass, is_current
)
values ('2026 - 2027', date '2026-10-24', date '2027-09-25', 6, 5, 5, 5, true)
on conflict (name) do nothing;

insert into public.classes (name, description, sort_order)
values
  ('Ø§Ù„ÙØµÙ„ 1', null, 1),
  ('Ø§Ù„ÙØµÙ„ 2', null, 2),
  ('Ø§Ù„ÙØµÙ„ 3', null, 3),
  ('Ø§Ù„ÙØµÙ„ 4', null, 4),
  ('Ø§Ù„ÙØµÙ„ 5', null, 5),
  ('Ø§Ù„ÙØµÙ„ 6', null, 6),
  ('Ø§Ù„ÙØµÙ„ 7', null, 7),
  ('Ø§Ù„ÙØµÙ„ 8', null, 8)
on conflict (name) do nothing;

-- Safety net in case the classes already existed before the year was added.
do $$
declare
  v_year_id uuid;
begin
  select id into v_year_id from public.attendance_years where is_current limit 1;
  if v_year_id is not null then
    perform public.generate_sessions_internal(v_year_id, null);
  end if;
end $$;


-- >>> 20261025090500_child_photos.sql
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


-- >>> 20261025091000_confession_activity.sql
-- =============================================================================
-- 07 - Fourth activity: Ø§Ù„Ø§Ø¹ØªØ±Ø§Ù (confession), 5 points
-- =============================================================================
-- A Saturday is now worth 20 points: Ù…Ø¯Ø§Ø±Ø³ Ø§Ù„Ø£Ø­Ø¯ + Ø¹Ø´ÙŠØ© + Ù‚Ø¯Ø§Ø³ + Ø§Ù„Ø§Ø¹ØªØ±Ø§Ù.
--
-- max_points_per_session was a generated column over three activities, and a
-- generation expression cannot be changed in place. Dropping and re-adding it
-- would mean dropping every view that reads it, so it becomes a plain column
-- maintained by a trigger instead: the ceiling stays database-owned, and the
-- next activity is one line in that trigger rather than a view cascade.
-- =============================================================================

alter table public.attendance_years
  add column if not exists points_confession smallint not null default 5;

alter table public.attendance_years
  drop constraint if exists attendance_years_points;
alter table public.attendance_years
  add constraint attendance_years_points check (
    points_sunday_school >= 0 and points_vespers >= 0
    and points_mass >= 0 and points_confession >= 0
  );

alter table public.attendance_years
  alter column max_points_per_session drop expression if exists;

comment on column public.attendance_years.max_points_per_session is
  'Points available on one attendance day. Maintained by attendance_years_apply_max_points(), so a client value is ignored.';

create or replace function public.attendance_years_apply_max_points()
returns trigger
language plpgsql
as $$
begin
  new.max_points_per_session := new.points_sunday_school
                              + new.points_vespers
                              + new.points_mass
                              + new.points_confession;
  return new;
end;
$$;

drop trigger if exists attendance_years_max_points on public.attendance_years;
create trigger attendance_years_max_points
  before insert or update on public.attendance_years
  for each row execute function public.attendance_years_apply_max_points();

update public.attendance_years
   set max_points_per_session = points_sunday_school + points_vespers
                              + points_mass + points_confession
 where max_points_per_session is distinct from
       (points_sunday_school + points_vespers + points_mass + points_confession);

-- -----------------------------------------------------------------------------
-- The record gains the fourth flag; the score still comes from the trigger
-- -----------------------------------------------------------------------------
alter table public.attendance_records
  add column if not exists confession boolean not null default false;

alter table public.attendance_records
  alter column max_score set default 20;

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
  v_points_confession    smallint;
  v_max_points           integer;
  v_class_id             uuid;
  v_is_locked            boolean;
begin
  select ay.points_sunday_school,
         ay.points_vespers,
         ay.points_mass,
         ay.points_confession,
         ay.max_points_per_session,
         s.class_id,
         s.is_locked
    into v_points_sunday_school,
         v_points_vespers,
         v_points_mass,
         v_points_confession,
         v_max_points,
         v_class_id,
         v_is_locked
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
  where s.id = new.session_id;

  if v_class_id is null then
    raise exception 'Ø¬Ù„Ø³Ø© Ø§Ù„Ø­Ø¶ÙˆØ± ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯Ø©' using errcode = '23503';
  end if;

  if v_is_locked and not public.is_admin() then
    raise exception 'ØªÙ… Ø¥ØºÙ„Ø§Ù‚ Ù‡Ø°Ù‡ Ø§Ù„Ø¬Ù„Ø³Ø© ÙˆÙ„Ø§ ÙŠÙ…ÙƒÙ† ØªØ¹Ø¯ÙŠÙ„Ù‡Ø§' using errcode = '42501';
  end if;

  -- Integrity: a record may only exist for a child of the session's class.
  if not exists (
    select 1 from public.children c
    where c.id = new.child_id and c.class_id = v_class_id
  ) then
    raise exception 'Ø§Ù„Ù…Ø®Ø¯ÙˆÙ… Ù„Ø§ ÙŠÙ†ØªÙ…ÙŠ Ø¥Ù„Ù‰ ÙØµÙ„ Ù‡Ø°Ù‡ Ø§Ù„Ø¬Ù„Ø³Ø©' using errcode = '23514';
  end if;

  new.score := (case when new.sunday_school then v_points_sunday_school else 0 end)
             + (case when new.vespers       then v_points_vespers       else 0 end)
             + (case when new.mass          then v_points_mass          else 0 end)
             + (case when new.confession    then v_points_confession    else 0 end);
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

-- Re-score what is already stored. The trigger is stepped around because it
-- refuses to touch a locked session unless the caller is an admin, and a
-- migration runs with no authenticated user at all.
alter table public.attendance_records disable trigger attendance_records_scoring;

update public.attendance_records r
   set max_score = ay.max_points_per_session
  from public.attendance_sessions s
  join public.attendance_years ay on ay.id = s.year_id
 where s.id = r.session_id
   and r.max_score is distinct from ay.max_points_per_session;

alter table public.attendance_records enable trigger attendance_records_scoring;

-- -----------------------------------------------------------------------------
-- Expose the new flag
-- -----------------------------------------------------------------------------
drop view if exists public.v_session_scores;
create view public.v_session_scores
with (security_invoker = true) as
select
  r.id          as record_id,
  s.id          as session_id,
  s.year_id,
  s.class_id,
  c.name        as class_name,
  s.session_date,
  s.is_locked,
  ch.id         as child_id,
  ch.full_name  as child_name,
  ch.gender,
  ch.is_active  as child_is_active,
  r.sunday_school,
  r.vespers,
  r.mass,
  r.confession,
  r.score,
  r.max_score,
  r.updated_at,
  r.updated_by,
  p.full_name   as updated_by_name
from public.attendance_records r
join public.attendance_sessions s on s.id = r.session_id
join public.classes            c on c.id = s.class_id
join public.children          ch on ch.id = r.child_id
left join public.profiles      p on p.id = r.updated_by;

-- Supabase grants new tables and views to anon by default, so the revoke from
-- migration 04 has to be repeated for a view that was dropped and rebuilt.
revoke all on public.v_session_scores from anon;
grant select on public.v_session_scores to authenticated;

-- Child codes are issued by the database. The client never chooses them.
select setval(
  'public.children_code_seq',
  greatest(
    coalesce((
      select max((regexp_match(code, '^C([0-9]+)$'))[1]::int)
      from public.children
      where code ~ '^C[0-9]+$'
    ), 0),
    0
  )
);

update public.children
set code = 'C' || lpad(nextval('public.children_code_seq')::text, 3, '0')
where code is null or btrim(code) = '';

alter table public.children alter column code set not null;

drop index if exists public.children_code_key;
create unique index children_code_key on public.children (code);



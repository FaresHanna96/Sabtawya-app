-- =============================================================================
-- Sabtawya — Multi-Class Attendance Management System
-- 01 - Core schema
-- =============================================================================
-- Terminology: a *servant* (خادم) serves one or more classes; a *child*
-- (مخدوم) is a boy or girl enrolled in exactly one class.
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
  -- أب الاعتراف: the child's confession father.
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

-- Business key used by Excel import to update instead of duplicating. NULLs are
-- not compared by a unique index, so a code stays optional per child.
create unique index if not exists children_code_key on public.children (code)
  where code is not null;

create index if not exists children_class_idx on public.children (class_id) where is_active;
create index if not exists children_name_idx on public.children (full_name);

comment on column public.children.code is
  'Optional stable business key. Excel import matches on this to update an existing child.';

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

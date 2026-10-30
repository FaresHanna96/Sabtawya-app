-- =============================================================================
-- 13 - Servant sign-up, gendered roles, and admin approval
-- =============================================================================
-- Roles stay two: أمين الخدمة (admin) and خادم (servant). خادم and خادمة differ
-- only in wording, not in what they may do, so the distinction is a gender on
-- the profile. Adding a third enum value would have meant widening every policy
-- that compares role = 'servant'.
--
-- Sign-up is open, but an account without an invite arrives inactive. The admin
-- accepts it (is_active = true) or rejects it (rejected_at), and both the
-- pending count and the activity feed are built from the profiles table.
-- =============================================================================

-- The enum is no longer only about children.
alter type public.child_gender rename to person_gender;

alter table public.profiles
  add column if not exists gender public.person_gender,
  add column if not exists rejected_at timestamptz,
  add column if not exists rejected_by uuid references public.profiles (id) on delete set null;

comment on column public.profiles.gender is
  'Drives the wording خادم / خادمة. Null for an account that never said.';
comment on column public.profiles.rejected_at is
  'Set when an admin refuses a sign-up request. The account stays inactive.';

alter table public.servant_invites
  add column if not exists gender public.person_gender;

create index if not exists profiles_pending_idx
  on public.profiles (created_at desc)
  where role = 'servant' and not is_active and rejected_at is null;

-- -----------------------------------------------------------------------------
-- Keep the guard honest about the new columns
-- -----------------------------------------------------------------------------
-- A servant may edit their own name, mobile, and gender, and nothing else: the
-- role, the activation, and the rejection are the admin's alone.
create or replace function public.profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.is_admin() or auth.uid() is null then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'غير مصرح لك بتغيير الصلاحية' using errcode = '42501';
  end if;

  if new.is_active is distinct from old.is_active then
    raise exception 'غير مصرح لك بتغيير حالة التنشيط' using errcode = '42501';
  end if;

  if new.rejected_at is distinct from old.rejected_at
     or new.rejected_by is distinct from old.rejected_by then
    raise exception 'غير مصرح لك بمراجعة طلبات الانضمام' using errcode = '42501';
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Sign-up: carry the gender over and tell the admin about it
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
  v_gender public.person_gender;
  v_active boolean;
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

  begin
    v_gender := coalesce(
      v_invite.gender,
      nullif(btrim(new.raw_user_meta_data ->> 'gender'), '')::public.person_gender
    );
  exception
    when invalid_text_representation then
      v_gender := v_invite.gender;
  end;

  -- No invite means no access until an admin accepts the request. The
  -- client-supplied metadata is deliberately never trusted for the role.
  v_active := v_invite.id is not null;

  insert into public.profiles (id, full_name, email, mobile, gender, role, is_active)
  values (
    new.id,
    v_name,
    new.email,
    coalesce(v_invite.mobile, nullif(btrim(new.raw_user_meta_data ->> 'mobile'), '')),
    v_gender,
    coalesce(v_invite.role, 'servant'),
    v_active
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

  -- Surfaces in the admin's activity feed, which is what makes an open
  -- sign-up noticeable without a push service.
  if not v_active then
    insert into public.activity_log (actor_id, actor_name, action, entity, entity_id, details)
    values (
      new.id,
      v_name,
      'signup',
      'profiles',
      new.id::text,
      jsonb_build_object('name', v_name, 'email', new.email, 'gender', v_gender)
    );
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Accept / reject, so the app never writes those columns itself
-- -----------------------------------------------------------------------------
create or replace function public.review_servant_request(
  p_profile_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مصرح لك بمراجعة طلبات الانضمام' using errcode = '42501';
  end if;

  if p_accept then
    update public.profiles
    set is_active = true, rejected_at = null, rejected_by = null
    where id = p_profile_id;
  else
    update public.profiles
    set is_active = false, rejected_at = now(), rejected_by = auth.uid()
    where id = p_profile_id;
  end if;

  if not found then
    raise exception 'لا يوجد طلب بهذا المعرّف' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.review_servant_request(uuid, boolean) from public, anon;
grant execute on function public.review_servant_request(uuid, boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- Pending requests, for the admin's approval queue
-- -----------------------------------------------------------------------------
create or replace view public.v_pending_servants
with (security_invoker = true) as
select
  p.id,
  p.full_name,
  p.email,
  p.mobile,
  p.gender,
  p.created_at
from public.profiles p
where p.role = 'servant'
  and not p.is_active
  and p.rejected_at is null;

revoke all on public.v_pending_servants from anon;
grant select on public.v_pending_servants to authenticated;

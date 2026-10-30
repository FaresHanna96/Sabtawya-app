-- =============================================================================
-- 08 - Make the first-admin bootstrap actually work
-- =============================================================================
-- Two problems showed up the first time an admin had to be created by hand.
--
-- 1. profiles_guard() refused the role change. It only lets an admin through,
--    and the very first admin is promoted from a connection that has no
--    authenticated user, so the guard blocked its own bootstrap helper.
--
--    A null auth.uid() means the statement did not come from a signed-in
--    client: `authenticated` always carries a uid, and `anon` has no grant on
--    profiles at all (migration 04 revokes them), so what is left is a
--    privileged server-side connection such as postgres or service_role, both
--    of which already bypass row level security.
--
-- 2. An account created before on_auth_user_created existed has no profile
--    row, and promote_to_admin() only updated existing rows. It now adopts the
--    auth user instead of failing.
-- =============================================================================

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

  return new;
end;
$$;

create or replace function public.promote_to_admin(p_email text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp, auth
as $$
declare
  v_user auth.users;
begin
  select * into v_user
  from auth.users
  where lower(email) = lower(p_email)
  limit 1;

  if v_user.id is null then
    raise exception 'لا يوجد مستخدم بهذا البريد: %', p_email using errcode = 'P0002';
  end if;

  insert into public.profiles (id, full_name, email, mobile, role, is_active)
  values (
    v_user.id,
    coalesce(
      nullif(btrim(v_user.raw_user_meta_data ->> 'full_name'), ''),
      split_part(p_email, '@', 1)
    ),
    v_user.email,
    nullif(btrim(v_user.raw_user_meta_data ->> 'mobile'), ''),
    'admin',
    true
  )
  on conflict (id) do update
    set role      = 'admin',
        is_active = true;
end;
$$;

revoke all on function public.promote_to_admin(text) from public, anon, authenticated;

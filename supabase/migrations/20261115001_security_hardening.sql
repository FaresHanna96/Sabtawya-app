-- Two gaps found in review.

-- 1. v_servant_birthdays was the only view made without security_invoker, so
--    it ran as its owner and answered anybody signed in, including a sign-up
--    still waiting for approval or a rejected one. It stays owner-run on
--    purpose (the birthday screen shows every servant to every servant, which
--    the profiles policy alone would cut down to co-servants of one class),
--    but now answers active accounts only: auth_role() is null for the rest.
create or replace view public.v_servant_birthdays as
select
  p.id,
  p.full_name,
  p.role,
  p.gender,
  p.birth_date
from public.profiles p
where p.is_active
  and p.birth_date is not null
  and public.auth_role() is not null;

revoke all on public.v_servant_birthdays from anon;
grant select on public.v_servant_birthdays to authenticated;

-- 2. Only an admin may hide an account from the servants lists. The guard
--    covered role, activation and the sign-up decision, but not is_hidden,
--    so a servant could hide themselves.
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

  if new.is_hidden is distinct from old.is_hidden then
    raise exception 'غير مصرح لك بإخفاء الحساب' using errcode = '42501';
  end if;

  return new;
end;
$$;

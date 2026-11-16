-- A phone book of the servants for every signed-in servant: name, role, the
-- classes they serve and their mobile (to call or message on WhatsApp).
-- Nothing else (no email, address, confessor) leaves this function, and
-- hidden (test) and inactive accounts are not listed. A servant's own profile
-- policy still only lets them read co-servants of their classes; this is the
-- deliberate, narrow exception.

create or replace function public.servant_directory()
returns table (
  id          uuid,
  full_name   text,
  role        text,
  gender      text,
  mobile      text,
  class_names text[]
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.full_name, p.role::text, p.gender::text, p.mobile,
         coalesce(array(
           select c.name
           from public.class_servants cs
           join public.classes c on c.id = cs.class_id
           where cs.servant_id = p.id
           order by c.sort_order, c.name), '{}'::text[])
  from public.profiles p
  where auth.uid() is not null
    and p.is_active
    and not p.is_hidden
  order by p.full_name;
$$;

revoke all on function public.servant_directory() from public, anon;
grant execute on function public.servant_directory() to authenticated;

-- Every servant can see every active servant's birthday, not only the
-- co-servants of their own classes (profiles_select is class-scoped, so an
-- أمين الخدمة or a خادم عام without a class was invisible to servants).
-- The view exposes only name, role, gender and birth date; it runs with the
-- owner's rights on purpose, so the other profile columns stay protected.
create or replace view public.v_servant_birthdays as
select
  p.id,
  p.full_name,
  p.role,
  p.gender,
  p.birth_date
from public.profiles p
where p.is_active
  and p.birth_date is not null;

revoke all on public.v_servant_birthdays from anon;
grant select on public.v_servant_birthdays to authenticated;

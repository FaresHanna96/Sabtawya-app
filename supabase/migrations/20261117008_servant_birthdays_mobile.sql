-- The servant birthday lists (screen, calendar, home) never showed the call
-- and WhatsApp icons: the view did not carry the mobile number. It now does,
-- for the same active, signed-in audience as before (and the same audience
-- that already sees mobiles in servant_directory()).
create or replace view public.v_servant_birthdays as
select
  p.id,
  p.full_name,
  p.role,
  p.gender,
  p.birth_date,
  p.mobile
from public.profiles p
where p.is_active
  and p.birth_date is not null
  and public.auth_role() is not null;

revoke all on public.v_servant_birthdays from anon;
grant select on public.v_servant_birthdays to authenticated;

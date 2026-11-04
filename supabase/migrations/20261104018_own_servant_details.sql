-- Every user can read and edit their own data (address, confessor, work).
-- The admin policy from 20261103001 still covers everyone else's row; this
-- one only ever matches the caller's own profile id.
drop policy if exists servant_details_own on public.servant_details;
create policy servant_details_own on public.servant_details
for all to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

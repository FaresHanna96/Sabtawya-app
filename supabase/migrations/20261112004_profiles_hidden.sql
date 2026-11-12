-- Accounts that keep working but do not appear in the servants lists, e.g. a
-- test admin used to try things on production. Hidden is not deleted and not
-- deactivated: the account signs in and works as before.
alter table public.profiles
  add column if not exists is_hidden boolean not null default false;

comment on column public.profiles.is_hidden is
  'Left out of the servants lists in the app. The account still signs in.';

update public.profiles p
set is_hidden = true
from auth.users u
where u.id = p.id
  and lower(u.email) = 'test-admin@sabtawya.test';

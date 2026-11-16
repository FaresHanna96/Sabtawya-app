-- Forcing old app versions to update, from the database side.
--
-- Apps from 1.0.30 on add " sabtawya/<build>" to the X-Client-Info header of
-- every data request. When app_config 'min_app_build' is above 0, a signed-in
-- request from a build below it (or from an app that sends no build, i.e. any
-- version before 1.0.30) is refused with an Arabic message the apps show as it
-- is. Signed-out requests (the download page, sign-up checks) are never gated.
--
--   turn on : update app_config set value = '31' where key = 'min_app_build';
--   turn off: update app_config set value = '0'  where key = 'min_app_build';
-- It ships OFF (0).

insert into public.app_config (key, value) values ('min_app_build', '0')
on conflict (key) do nothing;

create or replace function public.app_min_build()
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select nullif(value, '')::integer
                   from public.app_config where key = 'min_app_build'), 0);
$$;

create or replace function public.app_build_gate()
returns void
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_min     integer;
  v_headers json;
  v_build   integer;
begin
  if current_user <> 'authenticated' then
    return;
  end if;
  v_min := public.app_min_build();
  if v_min <= 0 then
    return;
  end if;
  v_headers := nullif(current_setting('request.headers', true), '')::json;
  v_build := coalesce(
    substring((v_headers ->> 'x-client-info') from 'sabtawya/([0-9]+)')::integer,
    0);
  if v_build < v_min then
    raise exception 'لازم تحدّث التطبيق: افتح sabtawya.vercel.app/apk.html'
      using errcode = '23514';
  end if;
end;
$$;

revoke all on function public.app_min_build() from public;
revoke all on function public.app_build_gate() from public;
grant execute on function public.app_min_build() to anon, authenticated;
grant execute on function public.app_build_gate() to anon, authenticated;

alter role authenticator set pgrst.db_pre_request = 'public.app_build_gate';
notify pgrst, 'reload config';

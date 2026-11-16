-- The build gate (20261117003) now lets an old app reach its home screen.
--
-- The three reads the app makes to sign in (the profile, the class overview
-- and the current year) are left open, so an old app gets as far as its home
-- screen, where the green "تحديث الآن" banner installs the update from inside
-- the app. Everything else is still refused. These reads were already allowed
-- by row security, so nothing new is exposed.

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
  v_path    text;
begin
  if current_user <> 'authenticated' then
    return;
  end if;
  v_min := public.app_min_build();
  if v_min <= 0 then
    return;
  end if;

  v_path := current_setting('request.path', true);
  if current_setting('request.method', true) = 'GET'
     and v_path in ('/profiles', '/v_class_overview', '/attendance_years') then
    return;
  end if;

  v_headers := nullif(current_setting('request.headers', true), '')::json;
  v_build := coalesce(
    substring((v_headers ->> 'x-client-info') from 'sabtawya/([0-9]+)')::integer,
    0);
  if v_build < v_min then
    raise exception 'لازم تحدّث التطبيق: اضغط «تحديث الآن» في الشريط الأخضر أعلى الصفحة الرئيسية، أو افتح sabtawya.vercel.app/apk.html'
      using errcode = '23514';
  end if;
end;
$$;

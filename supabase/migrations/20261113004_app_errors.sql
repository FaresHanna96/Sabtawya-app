-- Errors from the website version of the app (Android errors go to Firebase
-- Crashlytics). Signed-in users can only add their own rows; only admins
-- read them, on the stats page through admin_recent_errors().
create table if not exists public.app_errors (
  id          bigint generated always as identity primary key,
  user_id     uuid default auth.uid() references public.profiles (id) on delete set null,
  message     text not null check (char_length(message) <= 500),
  stack       text check (stack is null or char_length(stack) <= 2000),
  platform    text check (platform is null or char_length(platform) <= 20),
  app_version text check (app_version is null or char_length(app_version) <= 20),
  created_at  timestamptz not null default now()
);

create index if not exists app_errors_created_idx on public.app_errors (created_at desc);

alter table public.app_errors enable row level security;

drop policy if exists app_errors_insert on public.app_errors;
create policy app_errors_insert on public.app_errors
  for insert to authenticated
  with check (user_id = auth.uid());

revoke all on public.app_errors from anon, authenticated;
grant insert on public.app_errors to authenticated;

-- The latest errors for the stats page (admins only).
create or replace function public.admin_recent_errors(p_limit int default 30)
returns table (created_at timestamptz, message text, platform text,
               app_version text, who text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
    select e.created_at, e.message, e.platform, e.app_version, p.full_name
    from public.app_errors e
    left join public.profiles p on p.id = e.user_id
    order by e.created_at desc
    limit greatest(1, least(coalesce(p_limit, 30), 100));
end;
$$;

revoke all on function public.admin_recent_errors(int) from public, anon;
grant execute on function public.admin_recent_errors(int) to authenticated;

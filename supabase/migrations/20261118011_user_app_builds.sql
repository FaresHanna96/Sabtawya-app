-- Which app build each signed-in user is running, so a release can be measured:
-- how many users reached the new build, and when.
--
-- Apps from 1.0.45 call record_app_build() on start and after sign-in. A user
-- with no row is still on an older app. 'since' is when they first reported
-- the current build; it restarts whenever the build changes.
create table if not exists public.user_app_builds (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  build      integer not null,
  platform   text check (platform is null or char_length(platform) <= 20),
  since      timestamptz not null default now(),
  last_seen  timestamptz not null default now()
);

alter table public.user_app_builds enable row level security;
revoke all on public.user_app_builds from anon, authenticated;

create or replace function public.record_app_build(p_build integer, p_platform text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or p_build is null or p_build <= 0 then
    return;
  end if;
  insert into public.user_app_builds (user_id, build, platform)
  values (auth.uid(), p_build, left(p_platform, 20))
  on conflict (user_id) do update
    set since     = case when public.user_app_builds.build = excluded.build
                         then public.user_app_builds.since else now() end,
        build     = excluded.build,
        platform  = excluded.platform,
        last_seen = now();
end;
$$;

-- Admin-only report: users per build, with first/last time anyone reported it.
create or replace function public.app_build_report()
returns table (build integer, users bigint, first_since timestamptz, last_since timestamptz)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return query
    select b.build, count(*), min(b.since), max(b.since)
    from public.user_app_builds b
    group by b.build
    order by b.build desc;
end;
$$;

revoke all on function public.record_app_build(integer, text) from public;
revoke all on function public.app_build_report() from public;
grant execute on function public.record_app_build(integer, text) to authenticated;
grant execute on function public.app_build_report() to authenticated;

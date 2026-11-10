-- Names of the people who used the app, for the admin-only part of the stats
-- page. Built from the login sessions (the app keeps them updated while it is
-- used) and the activity log. Admins only: anyone else gets an error, so the
-- public stats page never shows a name.
create or replace function public.admin_active_users(p_days int default 1)
returns table (
  full_name   text,
  role        text,
  last_active timestamptz,
  actions     bigint
)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 1), 365)));
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;

  return query
  select p.full_name::text,
         p.role::text,
         s.last_active,
         coalesce(a.n, 0)
  from (
    select user_id,
           max(coalesce(refreshed_at, updated_at, created_at)) as last_active
    from auth.sessions
    group by user_id
    having max(coalesce(refreshed_at, updated_at, created_at)) >= v_since
  ) s
  join public.profiles p on p.id = s.user_id
  left join (
    select actor_id, count(*) as n
    from public.activity_log
    where created_at >= v_since
    group by actor_id
  ) a on a.actor_id = s.user_id
  order by s.last_active desc;
end;
$$;

revoke all on function public.admin_active_users(int) from public, anon;
grant execute on function public.admin_active_users(int) to authenticated;

-- Daily counts of access_events for the admin stats screen. SECURITY INVOKER:
-- the table's own policy lets only admins read, so anyone else gets nothing.
create or replace function public.access_stats(p_days int default 30)
returns table (day date, kind text, platform text, n bigint)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select (created_at at time zone 'Africa/Cairo')::date as day,
         kind,
         coalesce(platform, 'other') as platform,
         count(*) as n
  from public.access_events
  where created_at >= now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 365)))
  group by 1, 2, 3
  order by 1 desc, 2, 3;
$$;

revoke all on function public.access_stats(int) from public, anon;
grant execute on function public.access_stats(int) to authenticated;

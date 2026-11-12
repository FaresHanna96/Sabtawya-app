-- Hour-by-hour counts for one Cairo day, for the "اليوم" view of stats.html.
--
-- Same data as access_stats (kind and count only, no platform, no person), so
-- it is public like that one: the stats page is opened without signing in.
create or replace function public.access_stats_hourly(p_day date default null)
returns table (hour int, kind text, n bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select extract(hour from created_at at time zone 'Africa/Cairo')::int as hour,
         kind,
         count(*) as n
  from public.access_events
  where (created_at at time zone 'Africa/Cairo')::date
        = coalesce(p_day, (now() at time zone 'Africa/Cairo')::date)
  group by 1, 2
  order by 1, 2;
$$;

revoke all on function public.access_stats_hourly(date) from public;
grant execute on function public.access_stats_hourly(date) to anon, authenticated;

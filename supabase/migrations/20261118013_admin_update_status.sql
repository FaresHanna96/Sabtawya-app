-- Admin-only: every active person with the build their app last reported
-- (null = still on an older app that does not report), so the stats page can
-- list who has not updated and an admin can message them.
create or replace function public.admin_update_status()
returns table (full_name text, role text, mobile text, build integer, platform text,
               since timestamptz, last_seen timestamptz)
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
    select p.full_name, p.role::text, p.mobile, b.build, b.platform, b.since, b.last_seen
    from public.profiles p
    left join public.user_app_builds b on b.user_id = p.id
    where p.is_active and not p.is_hidden
    order by b.build nulls first, p.full_name;
end;
$$;

revoke all on function public.admin_update_status() from public;
grant execute on function public.admin_update_status() to authenticated;

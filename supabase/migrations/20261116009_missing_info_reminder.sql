-- Saturday 5 PM (Cairo): a reminder about the children whose record has gaps,
-- the birthday above all.
--
--   a servant gets the count for their own class (only when there is
--   something missing: a complete class is left in peace);
--   an admin or the general servant gets the count for the whole service.
--
-- "Missing" is the same rule as the app's بيانات ناقصة list: no birth date;
-- nobody reachable (the child's, mother's and father's numbers all empty); or
-- an empty mother's name, father's name, confession father, school or address.
-- Kind 'missing_info' opens that list (app 1.0.23+; older apps mark it read).
--
-- pg_cron runs in UTC and Cairo is UTC+2 or UTC+3, so the job runs at 14:00 and
-- 15:00 UTC on Saturdays and acts only in Cairo's 5 PM hour. One reminder per
-- person per day. p_force is for trying it by hand.

create or replace function public.notify_missing_child_info(p_force boolean default false)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now   timestamp := now() at time zone 'Africa/Cairo';
  v_today date := v_now::date;
  v_sent  integer := 0;
  v_part  integer;
begin
  if not p_force and (extract(isodow from v_now) <> 6 or extract(hour from v_now) <> 17) then
    return 0;
  end if;

  create temporary table if not exists _gaps (
    class_id uuid, no_birth bigint, any_gap bigint
  ) on commit drop;
  truncate _gaps;

  insert into _gaps
  select class_id,
         count(*) filter (where no_birth),
         count(*) filter (where any_gap)
  from (
    select c.class_id,
           c.birth_date is null as no_birth,
           (c.birth_date is null
            or (coalesce(btrim(c.mobile), '') = ''
                and coalesce(btrim(c.mother_mobile), '') = ''
                and coalesce(btrim(c.father_mobile), '') = '')
            or coalesce(btrim(c.mother_name), '') = ''
            or coalesce(btrim(c.father_name), '') = ''
            or coalesce(btrim(c.confession_father), '') = ''
            or coalesce(btrim(c.school), '') = ''
            or coalesce(btrim(c.address), '') = '') as any_gap
    from public.children c
    where c.is_active
  ) g
  group by class_id;

  -- A servant: their own class.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id,
         'missing_info',
         'بيانات ناقصة',
         'فصل ' || cl.name || ': ' ||
           case when g.no_birth > 0
             then g.no_birth || ' مخدوم ناقص تاريخ الميلاد' ||
                  case when g.any_gap > g.no_birth
                       then ' و' || (g.any_gap - g.no_birth) || ' ناقص بيانات أخرى'
                       else '' end
             else g.any_gap || ' مخدوم ناقص بيانات'
           end || '. كمّلها النهارده.',
         cl.id
  from public.class_servants cs
  join public.classes cl on cl.id = cs.class_id and cl.is_active
  join _gaps g on g.class_id = cl.id and g.any_gap > 0
  join public.profiles p
    on p.id = cs.servant_id and p.is_active and not p.is_hidden
       and p.role = 'servant'
  where not exists (
    select 1 from public.notifications n
    where n.user_id = cs.servant_id and n.kind = 'missing_info'
      and (n.created_at at time zone 'Africa/Cairo')::date = v_today
  );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  -- An admin or the general servant: the whole service.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id,
         'missing_info',
         'بيانات ناقصة',
         'في الخدمة ' ||
           case when t.no_birth > 0
             then t.no_birth || ' مخدوم ناقص تاريخ الميلاد' ||
                  case when t.any_gap > t.no_birth
                       then ' و' || (t.any_gap - t.no_birth) || ' ناقص بيانات أخرى'
                       else '' end
             else t.any_gap || ' مخدوم ناقص بيانات'
           end || '.',
         null
  from public.profiles p
  cross join (
    select coalesce(sum(no_birth), 0) as no_birth, coalesce(sum(any_gap), 0) as any_gap
    from _gaps
  ) t
  where p.is_active and not p.is_hidden
    and p.role in ('admin', 'general_servant')
    and t.any_gap > 0
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id and n.kind = 'missing_info'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
  get diagnostics v_part = row_count;
  v_sent := v_sent + v_part;

  return v_sent;
end;
$$;

revoke all on function public.notify_missing_child_info(boolean) from public, anon, authenticated;

select cron.unschedule('saturday-missing-info')
where exists (select 1 from cron.job where jobname = 'saturday-missing-info');

select cron.schedule('saturday-missing-info', '0 14,15 * * 6',
                     'select public.notify_missing_child_info()');

-- A push to the servants of a class the moment a child's run of absences reaches
-- the alert levels (default: 2 and 3 Saturdays in a row). The Sunday digest
-- (notify_absence_followup) stays as it is; this one is immediate and names the
-- child.
--
-- Why a function the app calls after saving, not a trigger on attendance_records:
-- one save writes many rows one by one, in no fixed order. A per-row trigger would
-- see half a Saturday (a child with no row yet counts as absent) and could alert
-- too early, or again after a later edit. The app calls check_absence_alerts() once
-- the whole save succeeded.
--
--   * only the class's latest taken Saturday is looked at, so back-filling or
--     correcting an old Saturday never alerts;
--   * absence_alerts remembers (child, year, level, the Saturday the run reached
--     it), so saving the same Saturday again, or two servants saving, alerts once;
--   * the person who saved is not told about their own save.
--
-- Levels live in app_config ('absence_alert_levels', e.g. '2,3'); admins change
-- them with set_app_setting().

alter table public.notifications add column if not exists child_id uuid;

create table if not exists public.absence_alerts (
  child_id         uuid not null references public.children (id) on delete cascade,
  year_id          uuid not null references public.attendance_years (id) on delete cascade,
  level            integer not null,
  last_absent_date date not null,
  created_at       timestamptz not null default now(),
  primary key (child_id, year_id, level, last_absent_date)
);

-- Internal bookkeeping: no policy, nobody reads it through the API.
alter table public.absence_alerts enable row level security;
revoke all on public.absence_alerts from anon, authenticated;

insert into public.app_config (key, value)
values ('absence_alert_levels', '2,3')
on conflict (key) do nothing;

create or replace function public.check_absence_alerts(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_class  uuid;
  v_year   uuid;
  v_date   date;
  v_latest date;
  v_levels integer[];
  v_actor  uuid := auth.uid();
  v_class_name text;
  v_sent   integer := 0;
  v_new    integer;
  r        record;
begin
  select s.class_id, s.year_id, s.session_date
    into v_class, v_year, v_date
  from public.attendance_sessions s
  where s.id = p_session_id;
  if v_class is null then
    return 0;
  end if;
  if not (public.can_access_class(v_class) or public.is_general_servant()) then
    return 0;
  end if;

  -- Only the newest taken Saturday of the class.
  select max(s.session_date) into v_latest
  from public.attendance_sessions s
  where s.class_id = v_class
    and s.session_date <= current_date
    and exists (select 1 from public.attendance_records r where r.session_id = s.id);
  if v_latest is distinct from v_date then
    return 0;
  end if;

  select array_agg(distinct trim(x)::integer)
    into v_levels
  from public.app_config c, unnest(string_to_array(c.value, ',')) x
  where c.key = 'absence_alert_levels' and trim(x) ~ '^\d{1,2}$';
  if v_levels is null or cardinality(v_levels) = 0 then
    v_levels := array[2, 3];
  end if;

  select name into v_class_name from public.classes where id = v_class;

  for r in
    select s.child_id, s.child_name, s.absent_streak
    from public.v_child_attendance_streak s
    where s.class_id = v_class
      and s.year_id = v_year
      and s.absent_streak = any (v_levels)
  loop
    insert into public.absence_alerts (child_id, year_id, level, last_absent_date)
    values (r.child_id, v_year, r.absent_streak, v_date)
    on conflict do nothing;
    get diagnostics v_new = row_count;
    if v_new = 0 then
      continue;
    end if;

    insert into public.notifications (user_id, kind, title, body, ref_id, child_id)
    select cs.servant_id,
           'absence_child',
           'مخدوم غايب',
           r.child_name || ' غاب ' ||
             case when r.absent_streak = 2 then 'سبتين'
                  else r.absent_streak || ' سبوت' end ||
             ' ورا بعض (فصل ' || coalesce(v_class_name, '') || '). كلّمه أو افتقده.',
           v_class,
           r.child_id
    from public.class_servants cs
    join public.profiles p
      on p.id = cs.servant_id and p.is_active and not p.is_hidden
    where cs.class_id = v_class
      and cs.servant_id is distinct from v_actor;
    v_sent := v_sent + 1;
  end loop;

  return v_sent;
end;
$$;

revoke all on function public.check_absence_alerts(uuid) from public, anon;
grant execute on function public.check_absence_alerts(uuid) to authenticated;

-- Admin-adjustable settings: a fixed list of keys, never the secrets that share
-- the app_config table.
create or replace function public.get_app_setting(p_key text)
returns text
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_key not in ('absence_alert_levels') then
    raise exception 'unknown setting' using errcode = '22023';
  end if;
  return (select value from public.app_config where key = p_key);
end;
$$;

create or replace function public.set_app_setting(p_key text, p_value text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_parts text[];
begin
  if not public.is_admin() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_key = 'absence_alert_levels' then
    -- One to four whole numbers between 1 and 20, like '2,3'.
    v_parts := string_to_array(regexp_replace(coalesce(p_value, ''), '\s', '', 'g'), ',');
    if cardinality(v_parts) not between 1 and 4
       or exists (select 1 from unnest(v_parts) x where x !~ '^([1-9]|1\d|20)$') then
      raise exception 'invalid levels' using errcode = '22023';
    end if;
    p_value := array_to_string(v_parts, ',');
  else
    raise exception 'unknown setting' using errcode = '22023';
  end if;
  insert into public.app_config (key, value) values (p_key, p_value)
  on conflict (key) do update set value = excluded.value;
end;
$$;

revoke all on function public.get_app_setting(text) from public, anon;
revoke all on function public.set_app_setting(text, text) from public, anon;
grant execute on function public.get_app_setting(text) to authenticated;
grant execute on function public.set_app_setting(text, text) to authenticated;

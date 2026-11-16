-- Change history, clearer: an edit now also stores what each field was and
-- became, and edits that only touched the visit fields no longer show up
-- (visits have their own history card).

create or replace function public.write_activity_log()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row     record;
  v_actor   text;
  v_details jsonb := '{}'::jsonb;
  v_name    text;
  v_class   uuid;
begin
  v_row := coalesce(new, old);
  select full_name into v_actor from public.profiles where id = auth.uid();

  if tg_table_name = 'children' then
    v_details := jsonb_build_object(
      'name', v_row.full_name, 'class_id', v_row.class_id, 'child_id', v_row.id);
    if tg_op = 'UPDATE' then
      v_details := v_details || jsonb_build_object('changed', (
        select coalesce(jsonb_agg(n.key order by n.key), '[]'::jsonb)
        from jsonb_each(to_jsonb(new)) n
        where n.key not in ('updated_at', 'updated_by')
          and n.value is distinct from (to_jsonb(old) -> n.key)));
      -- What each field was and became (visits have their own history, so
      -- they are left out; the class is stored by name, not by id).
      v_details := v_details || jsonb_build_object('changes', (
        select coalesce(jsonb_object_agg(n.key, jsonb_build_object(
                 'old', case when n.key = 'class_id'
                             then to_jsonb((select c.name from public.classes c
                                            where c.id = old.class_id))
                             else to_jsonb(old) -> n.key end,
                 'new', case when n.key = 'class_id'
                             then to_jsonb((select c.name from public.classes c
                                            where c.id = new.class_id))
                             else n.value end)), '{}'::jsonb)
        from jsonb_each(to_jsonb(new)) n
        where n.key not in ('updated_at', 'updated_by',
                            'last_phone_visit_date', 'last_phone_visit_notes',
                            'last_home_visit_date', 'last_home_visit_notes')
          and n.value is distinct from (to_jsonb(old) -> n.key)));
    end if;
  elsif tg_table_name = 'attendance_records' then
    select c.full_name, c.class_id into v_name, v_class
    from public.children c where c.id = v_row.child_id;
    v_details := jsonb_build_object(
      'session_id', v_row.session_id,
      'score', v_row.score,
      'child_id', v_row.child_id,
      'child_name', v_name,
      'class_id', v_class,
      'sunday_school', v_row.sunday_school,
      'vespers', v_row.vespers,
      'mass', v_row.mass,
      'confession', v_row.confession);
  elsif tg_table_name = 'class_servants' then
    select full_name into v_name from public.profiles where id = v_row.servant_id;
    v_details := jsonb_build_object(
      'class_id', v_row.class_id,
      'servant_id', v_row.servant_id,
      'servant_name', v_name);
  end if;

  insert into public.activity_log (actor_id, actor_name, action, entity, entity_id, details)
  values (auth.uid(), v_actor, lower(tg_op), tg_table_name, v_row.id::text, v_details);

  return null;
end;
$$;

drop function if exists public.child_change_history(uuid);

create function public.child_change_history(p_child_id uuid)
returns table (
  created_at timestamptz,
  actor_name text,
  action     text,
  entity     text,
  changed    text[],
  changes    jsonb
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select l.created_at, l.actor_name, l.action, l.entity,
         coalesce(array(select jsonb_array_elements_text(l.details -> 'changed')),
                  '{}'::text[]),
         coalesce(l.details -> 'changes', '{}'::jsonb)
  from public.activity_log l
  where exists (
          select 1 from public.children c
          where c.id = p_child_id and public.can_access_class(c.class_id))
    and l.action in ('insert', 'update')
    and ((l.entity = 'children' and l.entity_id = p_child_id::text)
      or (l.entity = 'attendance_records'
          and l.details ->> 'child_id' = p_child_id::text))
    -- An edit that only touched the visit fields is not a profile change.
    and not (l.entity = 'children' and l.action = 'update'
      and jsonb_array_length(coalesce(l.details -> 'changed', '[]'::jsonb)) > 0
      and not exists (
        select 1 from jsonb_array_elements_text(l.details -> 'changed') f
        where f not in ('last_phone_visit_date', 'last_phone_visit_notes',
                        'last_home_visit_date', 'last_home_visit_notes')))
  order by l.created_at desc
  limit 150;
$$;

revoke all on function public.child_change_history(uuid) from public, anon;
grant execute on function public.child_change_history(uuid) to authenticated;

-- The activity log is now something an admin can search (سجل النشاط), so each
-- entry says who it is about. Before, an attendance entry held only the
-- session and the score; now it also holds the child, the class and the four
-- marks, and an assignment holds the servant's name. Older entries keep what
-- they had.

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

-- Searching by servant, by kind of record and by child.
create index if not exists activity_log_actor_idx
  on public.activity_log (actor_id, created_at desc);
create index if not exists activity_log_entity_idx
  on public.activity_log (entity, created_at desc);
create index if not exists activity_log_child_idx
  on public.activity_log ((details ->> 'child_id'));
create index if not exists activity_log_entity_id_idx
  on public.activity_log (entity_id);

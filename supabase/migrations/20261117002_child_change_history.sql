-- "سجل التغييرات" on a child's page: who added or edited the child and who
-- recorded their attendance. The activity log itself stays admin only; this
-- function hands out just this child's entries, and only to the people who may
-- already see the child (an admin, or a servant of the child's class).
--
-- It returns the servant's name and what was done, never the log's raw
-- details. Visits are left out: the visit history already shows who made them.

create or replace function public.child_change_history(p_child_id uuid)
returns table (
  created_at timestamptz,
  actor_name text,
  action     text,
  entity     text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select l.created_at, l.actor_name, l.action, l.entity
  from public.activity_log l
  where exists (
          select 1 from public.children c
          where c.id = p_child_id and public.can_access_class(c.class_id))
    and l.action in ('insert', 'update')
    and ((l.entity = 'children' and l.entity_id = p_child_id::text)
      or (l.entity = 'attendance_records'
          and l.details ->> 'child_id' = p_child_id::text))
  order by l.created_at desc
  limit 60;
$$;

revoke all on function public.child_change_history(uuid) from public, anon;
grant execute on function public.child_change_history(uuid) to authenticated;

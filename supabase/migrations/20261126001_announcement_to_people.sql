-- Announcements to specific servants chosen by name (audience 'people'), on top
-- of all / class servants / general servants / chosen classes.

alter table public.announcements
  add column if not exists servant_ids uuid[] not null default '{}';

alter table public.announcements
  drop constraint if exists announcements_audience_check;
alter table public.announcements
  add constraint announcements_audience_check
  check (audience in ('all', 'servants', 'general', 'classes', 'people'));

alter table public.announcements
  drop constraint if exists announcements_people_given;
alter table public.announcements
  add constraint announcements_people_given
  check (audience <> 'people' or cardinality(servant_ids) > 0);

-- The 4-argument function goes: keeping both would make an old app's call
-- (4 named arguments) ambiguous. It resolves to this one by the default.
drop function if exists public.send_announcement(text, text, text, uuid[]);

create or replace function public.send_announcement(
  p_title       text,
  p_body        text,
  p_audience    text,
  p_class_ids   uuid[] default '{}',
  p_servant_ids uuid[] default '{}'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id    uuid;
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'only the admin can send announcements' using errcode = '42501';
  end if;

  insert into public.announcements
    (title, body, audience, class_ids, servant_ids, created_by)
  values (btrim(p_title), btrim(p_body), p_audience,
          coalesce(p_class_ids, '{}'),
          case when p_audience = 'people'
               then coalesce(p_servant_ids, '{}') else '{}'::uuid[] end,
          auth.uid())
  returning id into v_id;

  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id, 'announcement', btrim(p_title), btrim(p_body), v_id
  from public.profiles p
  where p.is_active
    and not p.is_hidden
    and p.id <> auth.uid()
    and case p_audience
          when 'all'      then true
          when 'servants' then p.role = 'servant'
          when 'general'  then p.role = 'general_servant'
          when 'classes'  then exists (
                 select 1 from public.class_servants cs
                 where cs.servant_id = p.id
                   and cs.class_id = any (p_class_ids))
          when 'people'   then p.id = any (p_servant_ids)
          else false
        end;
  get diagnostics v_count = row_count;

  if v_count = 0 then
    raise exception 'مفيش حد هيوصله الإعلان ده (مفيش خدام في الاختيار ده). اختار جمهور تاني.'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object('id', v_id, 'recipients', v_count);
end;
$$;

revoke all on function public.send_announcement(text, text, text, uuid[], uuid[]) from public, anon;
grant execute on function public.send_announcement(text, text, text, uuid[], uuid[]) to authenticated;

-- The admin's list now also names the chosen people. The return type changes,
-- so the function is dropped and made again.
drop function if exists public.announcements_summary();

create function public.announcements_summary()
returns table (
  id            uuid,
  title         text,
  body          text,
  audience      text,
  class_names   text[],
  sender_name   text,
  created_at    timestamptz,
  recipients    int,
  read_count    int,
  servant_names text[]
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select a.id, a.title, a.body, a.audience,
         coalesce(array(
           select c.name from public.classes c
           where c.id = any (a.class_ids)
           order by c.sort_order, c.name), '{}'::text[]),
         s.full_name,
         a.created_at,
         (select count(*) from public.notifications n
           where n.kind = 'announcement' and n.ref_id = a.id)::int,
         (select count(*) from public.notifications n
           where n.kind = 'announcement' and n.ref_id = a.id
             and n.read_at is not null)::int,
         coalesce(array(
           select p.full_name from public.profiles p
           where p.id = any (a.servant_ids)
           order by p.full_name), '{}'::text[])
  from public.announcements a
  left join public.profiles s on s.id = a.created_by
  where public.is_admin()
  order by a.created_at desc
  limit 200;
$$;

revoke all on function public.announcements_summary() from public, anon;
grant execute on function public.announcements_summary() to authenticated;

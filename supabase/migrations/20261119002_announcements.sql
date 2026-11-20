-- Announcements (إعلانات): أمين الخدمة writes a notice to the servants, to all
-- of them, to the class servants, to the general servants, or to the servants
-- of chosen classes. Each recipient gets it in the bell (kind 'announcement',
-- ref_id = the announcement, the full text in body) and as a push, through
-- the existing notifications_push trigger.
--
-- The notifications policy lets each person read only their own rows, so the
-- admin's "قرأها 12 من 18" comes from two admin-only functions below.

create table if not exists public.announcements (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (length(btrim(title)) between 1 and 120),
  body       text not null check (length(btrim(body)) between 1 and 2000),
  audience   text not null check (audience in ('all', 'servants', 'general', 'classes')),
  class_ids  uuid[] not null default '{}',
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint announcements_classes_given
    check (audience <> 'classes' or cardinality(class_ids) > 0)
);

create index if not exists announcements_created_idx
  on public.announcements (created_at desc);

alter table public.announcements enable row level security;

drop policy if exists announcements_select on public.announcements;
create policy announcements_select on public.announcements
  for select to authenticated using (public.is_admin());

-- Written only through send_announcement.
revoke all on public.announcements from anon;
grant select on public.announcements to authenticated;

create index if not exists notifications_ref_idx
  on public.notifications (kind, ref_id);

-- Sends one announcement. Returns how many people it went to.
create or replace function public.send_announcement(
  p_title     text,
  p_body      text,
  p_audience  text,
  p_class_ids uuid[] default '{}'
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

  insert into public.announcements (title, body, audience, class_ids, created_by)
  values (btrim(p_title), btrim(p_body), p_audience,
          coalesce(p_class_ids, '{}'), auth.uid())
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
          else false
        end;
  get diagnostics v_count = row_count;

  return jsonb_build_object('id', v_id, 'recipients', v_count);
end;
$$;

revoke all on function public.send_announcement(text, text, text, uuid[]) from public, anon;
grant execute on function public.send_announcement(text, text, text, uuid[]) to authenticated;

-- The admin's list: every announcement with how many got it and read it.
create or replace function public.announcements_summary()
returns table (
  id          uuid,
  title       text,
  body        text,
  audience    text,
  class_names text[],
  sender_name text,
  created_at  timestamptz,
  recipients  int,
  read_count  int
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
             and n.read_at is not null)::int
  from public.announcements a
  left join public.profiles s on s.id = a.created_by
  where public.is_admin()
  order by a.created_at desc
  limit 200;
$$;

revoke all on function public.announcements_summary() from public, anon;
grant execute on function public.announcements_summary() to authenticated;

-- Who got one announcement and when each read it (null = not yet). A person
-- who deleted it from their bell no longer appears.
create or replace function public.announcement_reads(p_id uuid)
returns table (
  user_id   uuid,
  full_name text,
  mobile    text,
  read_at   timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.full_name, p.mobile, n.read_at
  from public.notifications n
  join public.profiles p on p.id = n.user_id
  where public.is_admin()
    and n.kind = 'announcement'
    and n.ref_id = p_id
  order by n.read_at is null desc, p.full_name;
$$;

revoke all on function public.announcement_reads(uuid) from public, anon;
grant execute on function public.announcement_reads(uuid) to authenticated;

-- Undo for a mistaken edit of a child and for a mistaken Excel import.
--
-- 1. revert_child_change(log id): puts back what an edit changed, from the
--    "old" values the activity log has kept since 20261117006. It refuses when
--    any of those fields was changed again afterwards (so a later, correct edit
--    is never overwritten) and when the caller cannot reach the child's class.
--    Moving a child between classes stays an admin's job. The photo is not
--    reverted (the old file is deleted when a photo is replaced).
--
-- 2. Every import now writes an import_batches row: the ids it added and the
--    state of every child it changed, in the same transaction as the import.
--    undo_import(batch) removes the added children and restores the changed
--    ones, for the person who imported or an admin, within 14 days, and only if
--    none of those children was edited since and the added ones have no
--    attendance.

-- ---------------------------------------------------------------- edits

drop function if exists public.child_change_history(uuid);

create function public.child_change_history(p_child_id uuid)
returns table (
  id         bigint,
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
  select l.id, l.created_at, l.actor_name, l.action, l.entity,
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

create or replace function public.revert_child_change(p_log_id bigint)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  l       public.activity_log;
  c       public.children;
  r       public.children;
  v_patch jsonb := '{}'::jsonb;
  v_key   text;
  v_val   jsonb;
  v_cur   jsonb;
  v_class uuid;
begin
  select * into l from public.activity_log where id = p_log_id;
  if not found or l.entity <> 'children' or l.action <> 'update' then
    raise exception 'هذا التعديل غير موجود' using errcode = 'P0002';
  end if;
  select * into c from public.children where id = l.entity_id::uuid;
  if not found then
    raise exception 'المخدوم غير موجود' using errcode = 'P0002';
  end if;
  if not public.can_access_class(c.class_id) then
    raise exception 'غير مصرح لك بالتراجع عن هذا التعديل' using errcode = '42501';
  end if;

  for v_key, v_val in
    select e.key, e.value from jsonb_each(coalesce(l.details -> 'changes', '{}'::jsonb)) e
  loop
    if v_key not in ('full_name', 'gender', 'birth_date', 'mobile', 'mother_name',
                     'mother_mobile', 'father_name', 'father_mobile',
                     'confession_father', 'school', 'address', 'notes',
                     'is_active', 'is_deacon', 'latitude', 'longitude',
                     'class_id') then
      continue; -- photo and anything the app does not list
    end if;

    if v_key = 'class_id' then
      if not public.is_admin() then
        raise exception 'نقل المخدوم بين الفصول للأمين فقط' using errcode = '42501';
      end if;
      v_cur := to_jsonb((select cl.name from public.classes cl where cl.id = c.class_id));
    else
      v_cur := to_jsonb(c) -> v_key;
    end if;

    -- Changed again since: leave it, the later edit is the newer truth.
    if v_cur is distinct from (v_val -> 'new') then
      raise exception 'تم تعديل هذه البيانات بعد ذلك، لا يمكن التراجع' using errcode = 'P0001';
    end if;

    if v_key = 'class_id' then
      select cl.id into v_class from public.classes cl where cl.name = (v_val ->> 'old');
      if v_class is null then
        raise exception 'الفصل القديم لم يعد موجودًا' using errcode = 'P0001';
      end if;
      v_patch := v_patch || jsonb_build_object('class_id', v_class);
    else
      v_patch := v_patch || jsonb_build_object(v_key, v_val -> 'old');
    end if;
  end loop;

  if v_patch = '{}'::jsonb then
    return;
  end if;

  r := jsonb_populate_record(null::public.children, v_patch);
  update public.children t set
    full_name         = case when v_patch ? 'full_name' then r.full_name else t.full_name end,
    gender            = case when v_patch ? 'gender' then r.gender else t.gender end,
    birth_date        = case when v_patch ? 'birth_date' then r.birth_date else t.birth_date end,
    mobile            = case when v_patch ? 'mobile' then r.mobile else t.mobile end,
    mother_name       = case when v_patch ? 'mother_name' then r.mother_name else t.mother_name end,
    mother_mobile     = case when v_patch ? 'mother_mobile' then r.mother_mobile else t.mother_mobile end,
    father_name       = case when v_patch ? 'father_name' then r.father_name else t.father_name end,
    father_mobile     = case when v_patch ? 'father_mobile' then r.father_mobile else t.father_mobile end,
    confession_father = case when v_patch ? 'confession_father' then r.confession_father else t.confession_father end,
    school            = case when v_patch ? 'school' then r.school else t.school end,
    address           = case when v_patch ? 'address' then r.address else t.address end,
    notes             = case when v_patch ? 'notes' then r.notes else t.notes end,
    is_active         = case when v_patch ? 'is_active' then r.is_active else t.is_active end,
    is_deacon         = case when v_patch ? 'is_deacon' then r.is_deacon else t.is_deacon end,
    latitude          = case when v_patch ? 'latitude' then r.latitude else t.latitude end,
    longitude         = case when v_patch ? 'longitude' then r.longitude else t.longitude end,
    class_id          = case when v_patch ? 'class_id' then r.class_id else t.class_id end
  where t.id = c.id;
end;
$$;

revoke all on function public.revert_child_change(bigint) from public, anon;
grant execute on function public.revert_child_change(bigint) to authenticated;

-- --------------------------------------------------------------- imports

create table if not exists public.import_batches (
  id           uuid primary key default gen_random_uuid(),
  actor_id     uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  inserted_ids uuid[] not null default '{}',
  before       jsonb not null default '[]'::jsonb,
  undone_at    timestamptz
);

-- Internal: read and written only by the functions below.
alter table public.import_batches enable row level security;
revoke all on public.import_batches from anon, authenticated;

create or replace function public.record_import_batch(p_inserted uuid[], p_before jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    return null;
  end if;
  insert into public.import_batches (actor_id, inserted_ids, before)
  values (auth.uid(), coalesce(p_inserted, '{}'), coalesce(p_before, '[]'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.record_import_batch(uuid[], jsonb) from public, anon;
grant execute on function public.record_import_batch(uuid[], jsonb) to authenticated;

create or replace function public.import_children(
  p_inserts jsonb default '[]'::jsonb,
  p_updates jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_ids      uuid[];
  v_before   jsonb;
  v_inserted integer := 0;
  v_updated  integer := 0;
  v_expected integer := coalesce(jsonb_array_length(p_updates), 0);
  v_batch    uuid;
begin
  -- How the children to be changed look now, for undo_import().
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'class_id', c.class_id, 'full_name', c.full_name,
           'gender', c.gender, 'birth_date', c.birth_date, 'mobile', c.mobile,
           'mother_name', c.mother_name, 'mother_mobile', c.mother_mobile,
           'father_name', c.father_name, 'father_mobile', c.father_mobile,
           'confession_father', c.confession_father, 'school', c.school,
           'address', c.address, 'notes', c.notes)), '[]'::jsonb)
    into v_before
  from public.children c
  where c.id in (
    select x.id
    from jsonb_to_recordset(coalesce(p_updates, '[]'::jsonb)) as x(id uuid));

  with ins as (
    insert into public.children (
      class_id, full_name, gender, is_active, birth_date, mobile,
      mother_name, mother_mobile, father_name, father_mobile,
      confession_father, school, address, notes)
    select x.class_id, x.full_name, x.gender, true, x.birth_date, x.mobile,
           x.mother_name, x.mother_mobile, x.father_name, x.father_mobile,
           x.confession_father, x.school, x.address, x.notes
    from jsonb_to_recordset(coalesce(p_inserts, '[]'::jsonb)) as x(
      class_id uuid, full_name text, gender public.person_gender,
      birth_date date, mobile text, mother_name text, mother_mobile text,
      father_name text, father_mobile text, confession_father text,
      school text, address text, notes text)
    returning id)
  select coalesce(array_agg(id), '{}'::uuid[]) into v_ids from ins;
  v_inserted := cardinality(v_ids);

  -- Only the columns a sheet carries. is_active, the deacon flag, the visit
  -- dates and the photo are left as they are.
  update public.children c
     set class_id          = x.class_id,
         full_name         = x.full_name,
         gender            = x.gender,
         birth_date        = x.birth_date,
         mobile            = x.mobile,
         mother_name       = x.mother_name,
         mother_mobile     = x.mother_mobile,
         father_name       = x.father_name,
         father_mobile     = x.father_mobile,
         confession_father = x.confession_father,
         school            = x.school,
         address           = x.address,
         notes             = x.notes
  from jsonb_to_recordset(coalesce(p_updates, '[]'::jsonb)) as x(
    id uuid, class_id uuid, full_name text, gender public.person_gender,
    birth_date date, mobile text, mother_name text, mother_mobile text,
    father_name text, father_mobile text, confession_father text,
    school text, address text, notes text)
  where c.id = x.id;
  get diagnostics v_updated = row_count;

  -- A child the caller cannot see or change is skipped by row security
  -- without an error. Say so, and undo everything.
  if v_updated <> v_expected then
    raise exception 'تعذر تحديث % من % مخدوم، لم يُحفظ شيء',
      v_expected - v_updated, v_expected using errcode = '42501';
  end if;

  if v_inserted > 0 or v_updated > 0 then
    v_batch := public.record_import_batch(v_ids, v_before);
  end if;

  return jsonb_build_object(
    'inserted', v_inserted, 'updated', v_updated, 'batch_id', v_batch);
end;
$$;

revoke all on function public.import_children(jsonb, jsonb) from public, anon;
grant execute on function public.import_children(jsonb, jsonb) to authenticated;

-- The imports the caller can still undo: their own, or all for an admin.
create or replace function public.recent_import_batches()
returns table (
  id         uuid,
  created_at timestamptz,
  actor_name text,
  inserted   integer,
  updated    integer
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select b.id, b.created_at, p.full_name,
         cardinality(b.inserted_ids), jsonb_array_length(b.before)
  from public.import_batches b
  left join public.profiles p on p.id = b.actor_id
  where b.undone_at is null
    and b.created_at > now() - interval '14 days'
    and (public.is_admin() or b.actor_id = auth.uid())
  order by b.created_at desc
  limit 10;
$$;

revoke all on function public.recent_import_batches() from public, anon;
grant execute on function public.recent_import_batches() to authenticated;

create or replace function public.undo_import(p_batch uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b         public.import_batches;
  v_deleted integer := 0;
  v_restored integer := 0;
begin
  select * into b from public.import_batches where id = p_batch for update;
  if not found then
    raise exception 'هذا الاستيراد غير موجود' using errcode = 'P0002';
  end if;
  if not (public.is_admin() or b.actor_id = auth.uid()) then
    raise exception 'غير مصرح لك بالتراجع عن هذا الاستيراد' using errcode = '42501';
  end if;
  if b.undone_at is not null then
    raise exception 'تم التراجع عن هذا الاستيراد من قبل' using errcode = 'P0001';
  end if;
  if b.created_at < now() - interval '14 days' then
    raise exception 'مرت أكثر من 14 يومًا على هذا الاستيراد' using errcode = 'P0001';
  end if;

  -- Edited since (the import itself stamps updated_at with its own start time).
  if exists (select 1 from public.children c
             where c.id = any (b.inserted_ids) and c.updated_at > b.created_at)
     or exists (select 1
                from jsonb_to_recordset(b.before) as x(id uuid)
                join public.children c on c.id = x.id
                where c.updated_at > b.created_at) then
    raise exception 'تم تعديل بعض المخدومين بعد الاستيراد، لا يمكن التراجع' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.attendance_records r
             where r.child_id = any (b.inserted_ids)) then
    raise exception 'سُجّل حضور لبعض المخدومين المضافين، لا يمكن التراجع' using errcode = 'P0001';
  end if;

  delete from public.children where id = any (b.inserted_ids);
  get diagnostics v_deleted = row_count;

  update public.children c
     set class_id          = x.class_id,
         full_name         = x.full_name,
         gender            = x.gender,
         birth_date        = x.birth_date,
         mobile            = x.mobile,
         mother_name       = x.mother_name,
         mother_mobile     = x.mother_mobile,
         father_name       = x.father_name,
         father_mobile     = x.father_mobile,
         confession_father = x.confession_father,
         school            = x.school,
         address           = x.address,
         notes             = x.notes
  from jsonb_to_recordset(b.before) as x(
    id uuid, class_id uuid, full_name text, gender public.person_gender,
    birth_date date, mobile text, mother_name text, mother_mobile text,
    father_name text, father_mobile text, confession_father text,
    school text, address text, notes text)
  where c.id = x.id;
  get diagnostics v_restored = row_count;

  update public.import_batches set undone_at = now() where id = b.id;

  return jsonb_build_object('deleted', v_deleted, 'restored', v_restored);
end;
$$;

revoke all on function public.undo_import(uuid) from public, anon;
grant execute on function public.undo_import(uuid) to authenticated;

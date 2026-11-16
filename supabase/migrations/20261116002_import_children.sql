-- Excel import as one transaction: every new child and every change is
-- written, or none is. Before, the app sent one request per updated child, so
-- a failure halfway left the sheet half imported (and the updates also wrote
-- the last phone / home visit fields as empty, since the sheet has no such
-- columns).
--
-- security invoker: the caller's own row rules and the children triggers
-- (code, stamps, audit log) apply exactly as for a single insert or update.
-- Child codes are issued by the database, so the sheet's code is not written.

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
  v_inserted integer := 0;
  v_updated  integer := 0;
  v_expected integer := coalesce(jsonb_array_length(p_updates), 0);
begin
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
    school text, address text, notes text);
  get diagnostics v_inserted = row_count;

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

  return jsonb_build_object('inserted', v_inserted, 'updated', v_updated);
end;
$$;

revoke all on function public.import_children(jsonb, jsonb) from public, anon;
grant execute on function public.import_children(jsonb, jsonb) to authenticated;

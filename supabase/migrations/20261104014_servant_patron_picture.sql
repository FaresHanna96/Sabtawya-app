-- A servant may change the patron picture of a class they serve (the name is
-- already editable through the classes update policy).
--
-- Objects live at <class_id>/<millis>.<ext>; a few early ones sit one folder
-- deeper under class-patrons/<class_id>/, so both layouts are understood.
create or replace function public.can_manage_patron_object(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_first  text := split_part(p_name, '/', 1);
  v_class  uuid;
begin
  if public.is_admin() then
    return true;
  end if;
  if v_first = 'class-patrons' then
    v_first := split_part(p_name, '/', 2);
  end if;
  begin
    v_class := v_first::uuid;
  exception when others then
    return false;
  end;
  return public.serves_class(v_class);
end;
$$;

revoke all on function public.can_manage_patron_object(text) from public, anon;
grant execute on function public.can_manage_patron_object(text) to authenticated;

drop policy if exists class_patrons_insert on storage.objects;
create policy class_patrons_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'class-patrons' and public.can_manage_patron_object(name));

drop policy if exists class_patrons_update on storage.objects;
create policy class_patrons_update on storage.objects
  for update to authenticated
  using (bucket_id = 'class-patrons' and public.can_manage_patron_object(name))
  with check (bucket_id = 'class-patrons' and public.can_manage_patron_object(name));

drop policy if exists class_patrons_delete on storage.objects;
create policy class_patrons_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'class-patrons' and public.can_manage_patron_object(name));

-- Lets an admin delete a servant account for good (profile, login, their own
-- preps, attendances, notifications and devices go with it).
--
-- Things the servant created for the whole service (events, competitions,
-- marks, payments, recorded attendances) are kept and handed to the admin who
-- deletes the account, instead of failing on a foreign key.

create or replace function public.admin_delete_servant(p_servant_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_admin uuid := auth.uid();
begin
  if not public.is_admin() then
    raise exception 'only an admin can delete a servant';
  end if;
  if p_servant_id = v_admin then
    raise exception 'you cannot delete your own account';
  end if;
  if not exists (select 1 from public.profiles where id = p_servant_id) then
    raise exception 'servant not found';
  end if;
  if exists (select 1 from public.profiles where id = p_servant_id and role = 'admin')
     and (select count(*) from public.profiles where role = 'admin') <= 1 then
    raise exception 'cannot delete the last admin';
  end if;

  update public.events               set created_by  = v_admin where created_by  = p_servant_id;
  update public.event_payments       set paid_by     = v_admin where paid_by     = p_servant_id;
  update public.competitions         set created_by  = v_admin where created_by  = p_servant_id;
  update public.competition_marks    set marked_by   = v_admin where marked_by   = p_servant_id;
  update public.servant_attendances  set recorded_by = v_admin where recorded_by = p_servant_id;
  update public.servant_lesson_preps set reviewed_by = null    where reviewed_by = p_servant_id;

  -- profiles (and everything that cascades from it) go with the login.
  delete from auth.users where id = p_servant_id;
end;
$$;

revoke all on function public.admin_delete_servant(uuid) from public, anon;
grant execute on function public.admin_delete_servant(uuid) to authenticated;

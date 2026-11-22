-- A servant can fix a lesson prep after أمين الخدمة comments on it, and send
-- it back for review. Until now a sent prep was read-only for the servant:
-- "يوجد تعليق" asked for a change nobody could make.
--
-- The servant already may add and delete their own prep's files (policies
-- slpp_insert / slpp_delete and the servant-submissions storage policies).
-- What was missing is putting the status back to "pending", which only an
-- admin may update; this function does just that, for the servant's own
-- commented prep that still has at least one file, and tells the admins.

create or replace function public.resubmit_prep(p_prep_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_prep public.servant_lesson_preps;
  v_name text;
begin
  select * into v_prep from public.servant_lesson_preps where id = p_prep_id;
  if v_prep.id is null or v_prep.servant_id is distinct from auth.uid() then
    raise exception 'هذا التحضير ليس لك' using errcode = '42501';
  end if;
  if v_prep.status <> 'commented' then
    raise exception 'التحضير ليس عليه تعليق ليُرسل من جديد' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.servant_lesson_prep_photos f
                 where f.prep_id = p_prep_id) then
    raise exception 'أضف ملفاً واحداً على الأقل' using errcode = 'P0001';
  end if;

  -- The comment stays, so both sides still see what was asked.
  update public.servant_lesson_preps
  set status = 'pending', reviewed_by = null, reviewed_at = null
  where id = p_prep_id;

  select full_name into v_name from public.profiles where id = v_prep.servant_id;
  perform public.notify_admins(
    'prep_submitted', 'تحضير معدّل للمراجعة',
    coalesce(v_name, 'خادم') || ' عدّل تحضير الدرس وأرسله من جديد',
    p_prep_id);
end;
$$;

revoke all on function public.resubmit_prep(uuid) from public, anon;
grant execute on function public.resubmit_prep(uuid) to authenticated;

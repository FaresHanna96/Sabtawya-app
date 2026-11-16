-- A lesson-prep notification now points at the preparation itself, so
-- tapping it opens that lesson. Before, "prep_submitted" carried the
-- servant's id (the app opened the servant's page) and "prep_reviewed" carried
-- nothing. The app reads the id as a preparation first and, when none has it,
-- as a servant, so entries already in the bell keep working.

create or replace function public.notify_prep_submitted()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text;
begin
  select full_name into v_name from public.profiles where id = new.servant_id;
  perform public.notify_admins(
    'prep_submitted', 'تحضير جديد للمراجعة',
    coalesce(v_name, 'خادم') || ' أرسل تحضير الدرس', new.id);
  return new;
exception when others then
  return new;
end;
$$;

create or replace function public.notify_prep_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body, ref_id)
  values (
    new.servant_id,
    'prep_reviewed',
    case new.status when 'accepted' then 'تم قبول تحضيرك' else 'تعليق على تحضيرك' end,
    case when new.status = 'commented' and new.admin_comment is not null
      then new.admin_comment else 'راجع الأدمن تحضير الدرس' end,
    new.id);
  return new;
exception when others then
  return new;
end;
$$;

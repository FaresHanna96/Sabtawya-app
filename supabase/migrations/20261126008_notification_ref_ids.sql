-- Notices now carry the id of the thing they are about, so tapping one opens it:
-- a sign-up (the person), a new activity, a new competition, and an edited lesson or
-- pulpit/hymns (a lesson of that week). Each function is as in 20261126006 apart from
-- the ref_id it stores. Apps that do not read it behave as before.


CREATE OR REPLACE FUNCTION public.notify_admins_of_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  perform public.notify_admins(
    'signup', 'طلب انضمام جديد 👋',
    new.full_name || ' عايز ينضم للخدمة',
    new.id);
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_event_added()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- The same people as notify_servants(), which cannot store an id.
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select id, 'event_added', 'نشاط جديد 🎉',
         new.title || ' — ' || to_char(new.event_date, 'YYYY-MM-DD'),
         new.id
  from public.profiles
  where is_active and role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_competition_added()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select id, 'competition_added', 'مسابقة جديدة 🏆',
         new.title || ' — ' || to_char(new.week_date, 'YYYY-MM-DD'),
         new.id
  from public.profiles
  where is_active and role = 'general_servant';
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_lesson_edited()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id, 'lesson_changed',
         'اتعدّل درس صف ' || new.grade,
         'درس ' || public.lesson_slot_label(new.coptic_month, new.week)
           || ' لصف ' || new.grade || ' بقى: ' || new.title
           || case when new.page is not null then ' (ص ' || new.page || ')' else '' end,
         new.id
  from public.profiles p
  where p.is_active and not p.is_hidden
    and (
      p.role = 'general_servant'
      or (p.role = 'servant' and exists (
            select 1
            from public.class_servants cs
            join public.classes c on c.id = cs.class_id and c.is_active
            where cs.servant_id = p.id
              and substring(c.name from '^\s*([3-6])') = new.grade::text))
    );
  return new;
exception when others then
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_extras_edited()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id, 'lesson_changed', 'المنبر والترانيم اتحدّثوا 🎵',
         'بص على المنبر والترانيم الجديدة لدرس ' || public.lesson_slot_label(new.coptic_month, new.week),
         (select l.id from public.lessons l
           where l.coptic_month = new.coptic_month and l.week = new.week
           order by l.grade limit 1)
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$function$;

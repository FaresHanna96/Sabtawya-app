-- Better notices when the lesson programme changes.
--
-- Before: editing a lesson's title or page told every servant "a lesson was edited" with
-- only the new title, changing a postponed week to cancelled (or back) told nobody, and
-- clearing a break (the lesson is back) told nobody.
--
--   edit a lesson      -> the servants of that grade's classes and the general servants,
--                         naming the week, the grade, the new title and page
--   edit pulpit/hymns  -> every servant (they are shared by all grades)
--   postponed <-> cancelled -> every servant, saying what it changed from and to
--   break cleared      -> every servant: the lesson is back
--
-- Everyone means active, visible servants and general servants (admins made the change).
-- A grade is the leading digit of a class name. A failed notice never blocks the edit.

create or replace function public.lesson_slot_label(p_month int, p_week int)
returns text
language sql
immutable
as $$
  select (array['توت','بابة','هاتور','كيهك','طوبة','أمشير','برمهات','برمودة','بشنس','بؤونة','أبيب','مسرى'])[p_month]
         || ' - الأسبوع ' || p_week;
$$;

create or replace function public.notify_lesson_edited()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed',
         'تعديل في درس صف ' || new.grade,
         'تم تعديل درس ' || public.lesson_slot_label(new.coptic_month, new.week)
           || ' لصف ' || new.grade || ': ' || new.title
           || case when new.page is not null then ' (ص ' || new.page || ')' else '' end
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
$$;

create or replace function public.notify_extras_edited()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed', 'تعديل المنبر والترانيم',
         'تم تعديل المنبر أو الترانيم لدرس ' || public.lesson_slot_label(new.coptic_month, new.week)
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists lesson_extras_notify_edit on public.lesson_extras;
drop trigger if exists lesson_extras_notify_new on public.lesson_extras;
create trigger lesson_extras_notify_new
  after insert on public.lesson_extras
  for each row execute function public.notify_extras_edited();
create trigger lesson_extras_notify_edit
  after update of pulpit, hymns on public.lesson_extras
  for each row
  when (old.pulpit is distinct from new.pulpit or old.hymns is distinct from new.hymns)
  execute function public.notify_extras_edited();

create or replace function public.notify_lesson_break_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed', 'تغيير في الدروس',
         case when new.shift
              then 'تغيّر درس يوم ' || to_char(new.break_date, 'YYYY-MM-DD')
                   || ' من إلغاء إلى تأجيل: الدروس بعده تتحرك أسبوع.'
              else 'تغيّر درس يوم ' || to_char(new.break_date, 'YYYY-MM-DD')
                   || ' من تأجيل إلى إلغاء: باقي الدروس في مواعيدها.' end
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists lesson_breaks_notify_change on public.lesson_breaks;
create trigger lesson_breaks_notify_change
  after update of shift on public.lesson_breaks
  for each row
  when (old.shift is distinct from new.shift)
  execute function public.notify_lesson_break_changed();

create or replace function public.notify_lesson_break_cleared()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed', 'رجع الدرس',
         'تم إرجاع درس يوم ' || to_char(old.break_date, 'YYYY-MM-DD')
           || ': مفيش تأجيل ولا إلغاء.'
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return old;
exception when others then
  return old;
end;
$$;

drop trigger if exists lesson_breaks_notify_clear on public.lesson_breaks;
create trigger lesson_breaks_notify_clear
  after delete on public.lesson_breaks
  for each row execute function public.notify_lesson_break_cleared();

revoke all on function public.notify_extras_edited(), public.notify_lesson_break_changed(),
  public.notify_lesson_break_cleared() from public, anon, authenticated;

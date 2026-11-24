-- The servants' notices for a no-lesson Saturday now know about a نشاط ترفيهي whose
-- children's attendance is taken (20261124006):
--  * the notice for a NEW break no longer says «مفيش حضور» for such a day;
--  * a notice is sent when the admin switches a day to or from «attendance taken»
--    (until now only a postpone <-> cancel change sent one).
-- Everything else is as in 20261121002 and 20261118016.

create or replace function public.notify_lesson_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reason text := case when new.kind = 'activity' then 'نشاط ترفيهي' else 'إجازة' end;
  v_lessons text := case when new.shift
    then 'الدروس بعده تتأجل أسبوع.'
    else 'باقي الدروس في مواعيدها.' end;
begin
  perform public.notify_servants(
    'lesson_changed',
    v_reason || ' يوم ' || to_char(new.break_date, 'YYYY-MM-DD'),
    case when new.kind = 'activity' and new.attendance_taken
      then 'مفيش درس، لكن حضور الأطفال بيتسجّل وبيتحسب يومها. ' || v_lessons
      else 'مفيش درس ولا حضور يومها. ' || v_lessons end);
  return new;
exception when others then
  return new;
end;
$$;

-- The admin switched the day to or from «the children's attendance is taken».
create or replace function public.notify_lesson_break_attendance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  select p.id, 'lesson_changed', 'تغيير في الحضور',
         case when new.attendance_taken
              then 'نشاط ترفيهي يوم ' || to_char(new.break_date, 'YYYY-MM-DD')
                   || ': مفيش درس، لكن حضور الأطفال بيتسجّل وبيتحسب.'
              else 'يوم ' || to_char(new.break_date, 'YYYY-MM-DD')
                   || ' مبقاش بيتسجّل فيه حضور: بيطلع من حسابات الأطفال.' end
  from public.profiles p
  where p.is_active and not p.is_hidden and p.role in ('servant', 'general_servant');
  return new;
exception when others then
  return new;
end;
$$;

revoke all on function public.notify_lesson_break_attendance() from public, anon, authenticated;

drop trigger if exists lesson_breaks_notify_attendance on public.lesson_breaks;
create trigger lesson_breaks_notify_attendance
  after update of attendance_taken on public.lesson_breaks
  for each row
  when (old.attendance_taken is distinct from new.attendance_taken)
  execute function public.notify_lesson_break_attendance();

-- In-app notifications (the bell) for admins and servants, each also pushed.

create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null,
  title      text not null,
  body       text,
  read_at    timestamptz,
  pushed_at  timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications
  for delete to authenticated using (user_id = auth.uid());

grant select, update, delete on public.notifications to authenticated;

-- Every new notification triggers the push; the edge function claims it once.
create or replace function public.push_notification()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  perform net.http_post(
    url := 'https://fxclufgfkvfrhdleyndf.supabase.co/functions/v1/push-admins',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('kind', 'notification', 'notification_id', new.id)
  );
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists notifications_push on public.notifications;
create trigger notifications_push
  after insert on public.notifications
  for each row execute function public.push_notification();

-- Helper: notify every active admin.
create or replace function public.notify_admins(
  p_kind text, p_title text, p_body text
) returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.notifications (user_id, kind, title, body)
  select id, p_kind, p_title, p_body
  from public.profiles
  where role = 'admin' and is_active;
$$;

revoke all on function public.notify_admins(text, text, text) from public, anon, authenticated;

-- A new sign-up waits for approval -> admins.
create or replace function public.notify_admins_of_signup()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.notify_admins(
    'signup', 'طلب انضمام جديد',
    new.full_name || ' يطلب الانضمام للخدمة');
  return new;
exception when others then
  return new;
end;
$$;

-- The admin decided on a sign-up -> that servant.
create or replace function public.notify_servant_of_decision()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_accepted boolean := new.is_active and new.rejected_at is null;
begin
  insert into public.notifications (user_id, kind, title, body)
  values (
    new.id,
    'decision',
    case when v_accepted then 'تم قبول طلبك' else 'بخصوص طلب الانضمام' end,
    case when v_accepted
      then 'تمت الموافقة على طلب انضمامك، يمكنك الآن تسجيل الدخول'
      else 'لم يتم قبول طلب انضمامك، تواصل مع أمين الخدمة' end);
  return new;
exception when others then
  return new;
end;
$$;

-- A servant sends a lesson preparation -> admins.
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
    coalesce(v_name, 'خادم') || ' أرسل تحضير الدرس');
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists preps_notify_submitted on public.servant_lesson_preps;
create trigger preps_notify_submitted
  after insert on public.servant_lesson_preps
  for each row execute function public.notify_prep_submitted();

-- The admin reviewed a preparation -> its servant.
create or replace function public.notify_prep_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  values (
    new.servant_id,
    'prep_reviewed',
    case new.status when 'accepted' then 'تم قبول تحضيرك' else 'تعليق على تحضيرك' end,
    case when new.status = 'commented' and new.admin_comment is not null
      then new.admin_comment else 'راجع الأدمن تحضير الدرس' end);
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists preps_notify_reviewed on public.servant_lesson_preps;
create trigger preps_notify_reviewed
  after update of status on public.servant_lesson_preps
  for each row
  when (new.status in ('accepted', 'commented') and old.status is distinct from new.status)
  execute function public.notify_prep_reviewed();

-- A lesson was postponed / cancelled / edited -> every active servant.
create or replace function public.notify_servants(
  p_kind text, p_title text, p_body text
) returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.notifications (user_id, kind, title, body)
  select id, p_kind, p_title, p_body
  from public.profiles
  where is_active and role in ('servant', 'general_servant');
$$;

revoke all on function public.notify_servants(text, text, text) from public, anon, authenticated;

create or replace function public.notify_lesson_break()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.notify_servants(
    'lesson_changed',
    case when new.shift then 'تأجيل الدروس' else 'إلغاء درس' end,
    case when new.shift
      then 'تم تأجيل الدروس ابتداءً من ' || to_char(new.break_date, 'YYYY-MM-DD')
      else 'تم إلغاء درس يوم ' || to_char(new.break_date, 'YYYY-MM-DD') end);
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists lesson_breaks_notify on public.lesson_breaks;
create trigger lesson_breaks_notify
  after insert on public.lesson_breaks
  for each row execute function public.notify_lesson_break();

create or replace function public.notify_lesson_edited()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.notify_servants(
    'lesson_changed', 'تعديل في الدروس',
    'تم تعديل درس: ' || new.title);
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists lessons_notify_edit on public.lessons;
create trigger lessons_notify_edit
  after update of title, page on public.lessons
  for each row
  when (old.title is distinct from new.title or old.page is distinct from new.page)
  execute function public.notify_lesson_edited();

-- Sign-up / decision now go through notifications (and its push), so the old
-- direct calls are dropped and re-pointed at the new functions.
drop trigger if exists profiles_notify_admins on public.profiles;
create trigger profiles_notify_admins
  after insert on public.profiles
  for each row
  when (new.role = 'servant' and not new.is_active)
  execute function public.notify_admins_of_signup();

drop trigger if exists profiles_notify_decision on public.profiles;
create trigger profiles_notify_decision
  after update on public.profiles
  for each row
  when (
    new.role = 'servant'
    and (
      (new.is_active and not old.is_active)
      or (new.rejected_at is not null and old.rejected_at is null)
    )
  )
  execute function public.notify_servant_of_decision();

-- ---------------------------------------------------------------------------
-- Daily birthday digest for the admins (children and servants).
-- ---------------------------------------------------------------------------
create or replace function public.notify_birthdays()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_today    date := (now() at time zone 'Africa/Cairo')::date;
  v_year     int  := extract(year from v_today);
  v_leap     boolean := (v_year % 4 = 0 and v_year % 100 <> 0) or v_year % 400 = 0;
  v_children text;
  v_servants text;
  v_body     text;
begin
  select string_agg(full_name, '، ' order by full_name) into v_children
  from public.children
  where is_active and birth_date is not null
    and (
      (extract(month from birth_date) = extract(month from v_today)
       and extract(day from birth_date) = extract(day from v_today))
      or (not v_leap and extract(month from birth_date) = 2
          and extract(day from birth_date) = 29
          and extract(month from v_today) = 2 and extract(day from v_today) = 28)
    );

  select string_agg(full_name, '، ' order by full_name) into v_servants
  from public.profiles
  where is_active and role in ('servant', 'general_servant') and birth_date is not null
    and (
      (extract(month from birth_date) = extract(month from v_today)
       and extract(day from birth_date) = extract(day from v_today))
      or (not v_leap and extract(month from birth_date) = 2
          and extract(day from birth_date) = 29
          and extract(month from v_today) = 2 and extract(day from v_today) = 28)
    );

  if v_children is null and v_servants is null then
    return;
  end if;

  v_body := concat_ws(E'\n',
    case when v_children is not null then 'المخدومين: ' || v_children end,
    case when v_servants is not null then 'الخدام: ' || v_servants end);

  -- One digest per admin per day, even if the job runs twice.
  insert into public.notifications (user_id, kind, title, body)
  select a.id, 'birthdays', 'أعياد ميلاد اليوم', v_body
  from public.profiles a
  where a.role = 'admin' and a.is_active
    and not exists (
      select 1 from public.notifications n
      where n.user_id = a.id and n.kind = 'birthdays'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
end;
$$;

revoke all on function public.notify_birthdays() from public, anon, authenticated;

create extension if not exists pg_cron;

select cron.unschedule('daily-birthdays')
where exists (select 1 from cron.job where jobname = 'daily-birthdays');

-- 05:00 UTC is 07:00 or 08:00 in Cairo.
select cron.schedule('daily-birthdays', '0 5 * * *', 'select public.notify_birthdays()');
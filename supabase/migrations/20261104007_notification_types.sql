-- More notification types, for admins and servants.

-- Admin: a servant (not an admin) added a child.
create or replace function public.notify_child_added()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_by   public.profiles;
  v_class text;
begin
  select * into v_by from public.profiles where id = new.created_by;
  if v_by.id is null or v_by.role = 'admin' then
    return new;
  end if;
  select name into v_class from public.classes where id = new.class_id;
  perform public.notify_admins(
    'child_added', 'مخدوم جديد',
    v_by.full_name || ' أضاف ' || new.full_name || coalesce(' في فصل ' || v_class, ''));
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists children_notify_added on public.children;
create trigger children_notify_added
  after insert on public.children
  for each row execute function public.notify_child_added();

-- Admin: a servant took attendance (one notice per class, session and day).
create or replace function public.notify_attendance_taken()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_by    public.profiles;
  v_class text;
  v_date  date;
  v_body  text;
begin
  select * into v_by from public.profiles where id = new.created_by;
  if v_by.id is null or v_by.role = 'admin' then
    return new;
  end if;
  select c.name, s.session_date into v_class, v_date
  from public.attendance_sessions s
  join public.classes c on c.id = s.class_id
  where s.id = new.session_id;

  v_body := v_by.full_name || ' سجّل حضور فصل ' || coalesce(v_class, '') ||
            ' ليوم ' || to_char(v_date, 'YYYY-MM-DD');

  if not exists (
    select 1 from public.notifications n
    where n.kind = 'attendance_taken' and n.body = v_body
      and n.created_at > now() - interval '1 day'
  ) then
    perform public.notify_admins('attendance_taken', 'تم تسجيل الحضور', v_body);
  end if;
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists attendance_notify_taken on public.attendance_records;
create trigger attendance_notify_taken
  after insert on public.attendance_records
  for each row execute function public.notify_attendance_taken();

-- Servants: a new event / trip.
create or replace function public.notify_event_added()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.notify_servants(
    'event_added', 'فعالية جديدة',
    new.title || ' — ' || to_char(new.event_date, 'YYYY-MM-DD'));
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists events_notify_added on public.events;
create trigger events_notify_added
  after insert on public.events
  for each row execute function public.notify_event_added();

-- Servants: a new competition.
create or replace function public.notify_competition_added()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.notify_servants(
    'competition_added', 'مسابقة جديدة',
    new.title || ' — ' || to_char(new.week_date, 'YYYY-MM-DD'));
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists competitions_notify_added on public.competitions;
create trigger competitions_notify_added
  after insert on public.competitions
  for each row execute function public.notify_competition_added();

-- Servant: assigned to a class.
create or replace function public.notify_class_assigned()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_class text;
begin
  select name into v_class from public.classes where id = new.class_id;
  insert into public.notifications (user_id, kind, title, body)
  values (new.servant_id, 'class_assigned', 'تم تعيينك في فصل',
          'أصبحت من خدام فصل ' || coalesce(v_class, ''));
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists class_servants_notify on public.class_servants;
create trigger class_servants_notify
  after insert on public.class_servants
  for each row execute function public.notify_class_assigned();


-- Birthdays: admins get everyone (see 006). Servants get the same digest:
-- the servants born today, plus the children of their own classes (a general
-- servant, who sees every class, gets all the children).
create or replace function public.notify_servant_birthdays()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Africa/Cairo')::date;
  v_year  int  := extract(year from v_today);
  v_leap  boolean := (v_year % 4 = 0 and v_year % 100 <> 0) or v_year % 400 = 0;
begin
  insert into public.notifications (user_id, kind, title, body)
  select s.id, 'birthdays', 'أعياد ميلاد اليوم',
         concat_ws(E'\n',
           case when kids.names is not null then 'المخدومين: ' || kids.names end,
           case when peers.names is not null then 'الخدام: ' || peers.names end)
  from public.profiles s
  left join lateral (
    select string_agg(ch.full_name, '، ' order by ch.full_name) as names
    from public.children ch
    where ch.is_active and ch.birth_date is not null
      and (s.role = 'general_servant'
           or ch.class_id in (select class_id from public.class_servants where servant_id = s.id))
      and (
        (extract(month from ch.birth_date) = extract(month from v_today)
         and extract(day from ch.birth_date) = extract(day from v_today))
        or (not v_leap and extract(month from ch.birth_date) = 2
            and extract(day from ch.birth_date) = 29
            and extract(month from v_today) = 2 and extract(day from v_today) = 28)
      )
  ) kids on true
  left join lateral (
    select string_agg(o.full_name, '، ' order by o.full_name) as names
    from public.profiles o
    where o.is_active and o.id <> s.id
      and o.role in ('servant', 'general_servant') and o.birth_date is not null
      and (
        (extract(month from o.birth_date) = extract(month from v_today)
         and extract(day from o.birth_date) = extract(day from v_today))
        or (not v_leap and extract(month from o.birth_date) = 2
            and extract(day from o.birth_date) = 29
            and extract(month from v_today) = 2 and extract(day from v_today) = 28)
      )
  ) peers on true
  where s.is_active and s.role in ('servant', 'general_servant')
    and (kids.names is not null or peers.names is not null)
    and not exists (
      select 1 from public.notifications n
      where n.user_id = s.id and n.kind = 'birthdays'
        and (n.created_at at time zone 'Africa/Cairo')::date = v_today
    );
end;
$$;

revoke all on function public.notify_servant_birthdays() from public, anon, authenticated;

select cron.unschedule('daily-servant-birthdays')
where exists (select 1 from cron.job where jobname = 'daily-servant-birthdays');

-- Right after the admins' digest (05:00 UTC = 07:00 or 08:00 in Cairo).
select cron.schedule(
  'daily-servant-birthdays', '2 5 * * *',
  'select public.notify_servant_birthdays()');
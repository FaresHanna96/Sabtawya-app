-- Notifications remember what they are about, so tapping one opens it.

alter table public.notifications add column if not exists ref_id uuid;

drop function if exists public.notify_admins(text, text, text);
create or replace function public.notify_admins(
  p_kind text, p_title text, p_body text, p_ref uuid default null
) returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select id, p_kind, p_title, p_body, p_ref
  from public.profiles
  where role = 'admin' and is_active;
$$;

revoke all on function public.notify_admins(text, text, text, uuid) from public, anon, authenticated;

-- A servant sent a lesson preparation: the ref is that servant.
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
    coalesce(v_name, 'خادم') || ' أرسل تحضير الدرس', new.servant_id);
  return new;
exception when others then
  return new;
end;
$$;

-- A servant added a child: the ref is the child.
create or replace function public.notify_child_added()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_by    public.profiles;
  v_class text;
begin
  select * into v_by from public.profiles where id = new.created_by;
  if v_by.id is null or v_by.role = 'admin' then
    return new;
  end if;
  select name into v_class from public.classes where id = new.class_id;
  perform public.notify_admins(
    'child_added', 'مخدوم جديد',
    v_by.full_name || ' أضاف ' || new.full_name || coalesce(' في فصل ' || v_class, ''),
    new.id);
  return new;
exception when others then
  return new;
end;
$$;

-- A servant took attendance: the ref is the class.
create or replace function public.notify_attendance_taken()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_by    public.profiles;
  v_class text;
  v_class_id uuid;
  v_date  date;
  v_body  text;
begin
  select * into v_by from public.profiles where id = new.created_by;
  if v_by.id is null or v_by.role = 'admin' then
    return new;
  end if;
  select c.name, c.id, s.session_date into v_class, v_class_id, v_date
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
    perform public.notify_admins('attendance_taken', 'تم تسجيل الحضور', v_body, v_class_id);
  end if;
  return new;
exception when others then
  return new;
end;
$$;

-- A servant was assigned to a class: the ref is the class.
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
  insert into public.notifications (user_id, kind, title, body, ref_id)
  values (new.servant_id, 'class_assigned', 'تم تعيينك في فصل',
          'أصبحت من خدام فصل ' || coalesce(v_class, ''), new.class_id);
  return new;
exception when others then
  return new;
end;
$$;

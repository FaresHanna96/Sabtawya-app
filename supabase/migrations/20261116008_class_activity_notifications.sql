-- When a servant of a class does something on that class, the other servants
-- of the class are told: attendance taken, a child added, moved, stopped or
-- edited, a visit written down, the class's own details changed.
--
-- Only an action by a servant OF that class counts. An admin's own changes
-- (an Excel import, the year promotion) do not notify anyone, the actor never
-- notifies themselves, and an entry like "X edited a child" is sent at most
-- once every 30 minutes per person, so a long editing session is one message,
-- not fifty.
--
-- The rows go into `notifications`, so they show in the bell (each one opens
-- the class, the child or the attendance sheet it is about) and the existing
-- trigger pushes them to the phones.

-- One notification per other active servant of the class.
create or replace function public.notify_class_servants(
  p_class_id uuid,
  p_actor    uuid,
  p_kind     text,
  p_title    text,
  p_body     text,
  p_ref      uuid,
  p_same_actor_prefix text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body, ref_id)
  select cs.servant_id, p_kind, p_title, p_body, p_ref
  from public.class_servants cs
  join public.profiles p
    on p.id = cs.servant_id and p.is_active and not p.is_hidden
  where cs.class_id = p_class_id
    and cs.servant_id is distinct from p_actor
    and not exists (
      select 1 from public.notifications n
      where n.user_id = cs.servant_id
        and n.kind = p_kind
        and n.created_at > now() - interval '30 minutes'
        and (n.body = p_body
             or (p_same_actor_prefix is not null
                 and n.body like p_same_actor_prefix || '%'))
    );
end;
$$;

revoke all on function public.notify_class_servants(uuid, uuid, text, text, text, uuid, text)
  from public, anon, authenticated;

create or replace function public.actor_serves_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.class_servants
    where class_id = p_class_id and servant_id = auth.uid()
  );
$$;

revoke all on function public.actor_serves_class(uuid) from public, anon;
grant execute on function public.actor_serves_class(uuid) to authenticated;

create or replace function public.actor_name()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select full_name from public.profiles where id = auth.uid()), 'خادم');
$$;

revoke all on function public.actor_name() from public, anon;
grant execute on function public.actor_name() to authenticated;

-- ── attendance taken ─────────────────────────────────────────────────────────
-- Same title and wording as the one admins get, so the bell opens the sheet of
-- that class on that Saturday.
create or replace function public.notify_coservants_attendance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_class_id   uuid;
  v_class_name text;
  v_date       date;
begin
  if auth.uid() is null then return new; end if;
  select c.id, c.name, s.session_date into v_class_id, v_class_name, v_date
  from public.attendance_sessions s
  join public.classes c on c.id = s.class_id
  where s.id = new.session_id;
  if v_class_id is null or not public.actor_serves_class(v_class_id) then
    return new;
  end if;
  perform public.notify_class_servants(
    v_class_id, auth.uid(), 'attendance_taken', 'تم تسجيل الحضور',
    public.actor_name() || ' سجّل حضور فصل ' || v_class_name ||
      ' ليوم ' || to_char(v_date, 'YYYY-MM-DD'),
    v_class_id);
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists attendance_notify_coservants on public.attendance_records;
create trigger attendance_notify_coservants
  after insert or update on public.attendance_records
  for each row execute function public.notify_coservants_attendance();

-- ── children: added, moved, stopped, edited ──────────────────────────────────
create or replace function public.notify_coservants_child()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_who   text;
  v_new_class text;
  v_old_class text;
begin
  if v_actor is null then return new; end if;
  v_who := public.actor_name();

  if tg_op = 'INSERT' then
    if public.actor_serves_class(new.class_id) then
      perform public.notify_class_servants(
        new.class_id, v_actor, 'child_added', 'مخدوم جديد',
        v_who || ' أضاف ' || new.full_name || ' في فصلكم', new.id);
    end if;
    return new;
  end if;

  if new.class_id is distinct from old.class_id then
    if public.actor_serves_class(old.class_id)
       or public.actor_serves_class(new.class_id) then
      select name into v_new_class from public.classes where id = new.class_id;
      select name into v_old_class from public.classes where id = old.class_id;
      perform public.notify_class_servants(
        old.class_id, v_actor, 'class_activity', 'تغيير في فصلك',
        v_who || ' نقل ' || new.full_name || ' إلى فصل ' || coalesce(v_new_class, ''),
        old.class_id);
      perform public.notify_class_servants(
        new.class_id, v_actor, 'class_activity', 'تغيير في فصلك',
        v_who || ' نقل ' || new.full_name || ' من فصل ' || coalesce(v_old_class, '') ||
          ' إلى فصلكم',
        new.class_id);
    end if;
    return new;
  end if;

  if not public.actor_serves_class(new.class_id) then return new; end if;

  if new.is_active is distinct from old.is_active then
    perform public.notify_class_servants(
      new.class_id, v_actor, 'class_activity', 'تغيير في فصلك',
      v_who || case when new.is_active then ' أعاد تفعيل ' else ' أوقف ' end ||
        new.full_name,
      new.class_id);
    return new;
  end if;

  -- The columns a servant edits (not the visit dates, which the visit entries
  -- below announce, and not the stamps and the code the database sets).
  if (old.full_name, old.gender, old.birth_date, old.mobile, old.mother_name,
      old.mother_mobile, old.father_name, old.father_mobile,
      old.confession_father, old.is_deacon, old.school, old.address, old.notes,
      old.photo_path)
     is distinct from
     (new.full_name, new.gender, new.birth_date, new.mobile, new.mother_name,
      new.mother_mobile, new.father_name, new.father_mobile,
      new.confession_father, new.is_deacon, new.school, new.address, new.notes,
      new.photo_path) then
    perform public.notify_class_servants(
      new.class_id, v_actor, 'class_activity', 'تغيير في فصلك',
      v_who || ' عدّل بيانات ' || new.full_name, new.class_id,
      v_who || ' عدّل بيانات');
  end if;
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists children_notify_coservants on public.children;
create trigger children_notify_coservants
  after insert or update on public.children
  for each row execute function public.notify_coservants_child();

-- ── a visit written down ─────────────────────────────────────────────────────
create or replace function public.notify_coservants_visit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name  text;
  v_class uuid;
begin
  if auth.uid() is null then return new; end if;
  select full_name, class_id into v_name, v_class
  from public.children where id = new.child_id;
  if v_class is null or not public.actor_serves_class(v_class) then
    return new;
  end if;
  perform public.notify_class_servants(
    v_class, auth.uid(), 'class_activity', 'تغيير في فصلك',
    public.actor_name() || ' سجّل افتقاد ' ||
      case new.visit_type when 'phone' then '(اتصال)' else '(زيارة)' end ||
      ' لـ ' || v_name,
    v_class);
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists visit_logs_notify_coservants on public.child_visit_logs;
create trigger visit_logs_notify_coservants
  after insert on public.child_visit_logs
  for each row execute function public.notify_coservants_visit();

-- ── the class's own details ──────────────────────────────────────────────────
create or replace function public.notify_coservants_class()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not public.actor_serves_class(new.id) then
    return new;
  end if;
  if (old.name, old.description, old.patron_name, old.patron_photo_path)
     is distinct from
     (new.name, new.description, new.patron_name, new.patron_photo_path) then
    perform public.notify_class_servants(
      new.id, auth.uid(), 'class_activity', 'تغيير في فصلك',
      public.actor_name() || ' عدّل بيانات الفصل', new.id,
      public.actor_name() || ' عدّل بيانات الفصل');
  end if;
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists classes_notify_coservants on public.classes;
create trigger classes_notify_coservants
  after update on public.classes
  for each row execute function public.notify_coservants_class();

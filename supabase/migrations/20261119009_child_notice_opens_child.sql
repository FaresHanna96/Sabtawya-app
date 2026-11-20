-- "تغيير في فصلك" about one child (edited, stopped / brought back, moved into
-- the class, a visit written down) now also keeps that child's id, so tapping
-- it in the bell opens the child's profile instead of the class. Notices about
-- the class itself (its details, attendance) and a child moved OUT of the
-- class (its old servants can no longer open them) still open the class.
-- Older notices have no child id and keep opening the class.

drop function if exists public.notify_class_servants(uuid, uuid, text, text, text, uuid, text);

create or replace function public.notify_class_servants(
  p_class_id uuid,
  p_actor    uuid,
  p_kind     text,
  p_title    text,
  p_body     text,
  p_ref      uuid,
  p_same_actor_prefix text default null,
  p_child_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, kind, title, body, ref_id, child_id)
  select cs.servant_id, p_kind, p_title, p_body, p_ref, p_child_id
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

revoke all on function public.notify_class_servants(uuid, uuid, text, text, text, uuid, text, uuid)
  from public, anon, authenticated;

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
      -- The old class can no longer open the child: its notice opens the class.
      perform public.notify_class_servants(
        old.class_id, v_actor, 'class_activity', 'تغيير في فصلك',
        v_who || ' نقل ' || new.full_name || ' إلى فصل ' || coalesce(v_new_class, ''),
        old.class_id);
      perform public.notify_class_servants(
        new.class_id, v_actor, 'class_activity', 'تغيير في فصلك',
        v_who || ' نقل ' || new.full_name || ' من فصل ' || coalesce(v_old_class, '') ||
          ' إلى فصلكم',
        new.class_id, null, new.id);
    end if;
    return new;
  end if;

  if not public.actor_serves_class(new.class_id) then return new; end if;

  if new.is_active is distinct from old.is_active then
    perform public.notify_class_servants(
      new.class_id, v_actor, 'class_activity', 'تغيير في فصلك',
      v_who || case when new.is_active then ' أعاد تفعيل ' else ' أوقف ' end ||
        new.full_name,
      new.class_id, null, new.id);
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
      v_who || ' عدّل بيانات', new.id);
  end if;
  return new;
exception when others then
  return new;
end;
$$;

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
    v_class, null, new.child_id);
  return new;
exception when others then
  return new;
end;
$$;

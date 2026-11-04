-- Servant: removed from a class. (Assigning already notifies; removing did not.)
create or replace function public.notify_class_removed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_class text;
begin
  -- When the whole account is being deleted there is nobody left to tell.
  if not exists (select 1 from public.profiles where id = old.servant_id) then
    return old;
  end if;
  select name into v_class from public.classes where id = old.class_id;
  insert into public.notifications (user_id, kind, title, body)
  values (old.servant_id, 'class_removed', 'تمت إزالتك من فصل',
          'لم تعد من خدام فصل ' || coalesce(v_class, ''));
  return old;
exception when others then
  return old;
end;
$$;

drop trigger if exists class_servants_notify_removed on public.class_servants;
create trigger class_servants_notify_removed
  after delete on public.class_servants
  for each row execute function public.notify_class_removed();

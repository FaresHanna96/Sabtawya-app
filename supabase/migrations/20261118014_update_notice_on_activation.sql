-- Someone who becomes active after a release went out (a new servant approved, or an
-- inactive one switched on) gets the same "install the new version" notice everyone else
-- got, so nobody misses it. Skipped when their app already reports the latest build, when
-- they already have that notice, or once the release's reminder window has ended.
create or replace function public.notify_update_on_activation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_version text;
  v_build   integer;
  v_until   date;
  v_body    text;
begin
  if not new.is_active or new.is_hidden then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.is_active then
    return new;
  end if;

  select nullif(value, '') into v_version from public.app_config where key = 'latest_app_version';
  select nullif(value, '')::integer into v_build from public.app_config where key = 'latest_app_build';
  select nullif(value, '')::date into v_until from public.app_config where key = 'update_reminder_until';
  if v_version is null or v_until is null or (now() at time zone 'Africa/Cairo')::date > v_until then
    return new;
  end if;
  if v_build is not null and exists (
       select 1 from public.user_app_builds b where b.user_id = new.id and b.build >= v_build) then
    return new;
  end if;

  v_body := 'اضغط لفتح التطبيق وتثبيت النسخة ' || v_version || '. التحديث مطلوب عشان التطبيق يفضل شغال.';
  if not exists (select 1 from public.notifications n
                 where n.user_id = new.id and n.kind = 'app_update' and n.body = v_body) then
    insert into public.notifications (user_id, kind, title, body)
    values (new.id, 'app_update', 'تحديث جديد لسبتاوية', v_body);
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_update_notice on public.profiles;
create trigger profiles_update_notice
  after insert or update of is_active on public.profiles
  for each row execute function public.notify_update_on_activation();

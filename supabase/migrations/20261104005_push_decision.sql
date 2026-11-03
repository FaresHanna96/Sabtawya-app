-- Push the admin's decision (accepted / rejected) to the servant who signed up.

alter table public.profiles
  add column if not exists push_decided_at timestamptz;

-- A device token can move between accounts on a shared device; the RLS policy
-- would block taking over another user's row, so registration goes through here.
create or replace function public.register_device_token(
  p_token text,
  p_platform text
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
$$;

revoke all on function public.register_device_token(text, text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;

create or replace function public.notify_servant_of_decision()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  perform net.http_post(
    url := 'https://fxclufgfkvfrhdleyndf.supabase.co/functions/v1/push-admins',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('profile_id', new.id, 'kind', 'decision')
  );
  return new;
exception when others then
  return new;
end;
$$;

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

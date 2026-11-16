-- Devices are now identified by their Firebase installation ID instead of a
-- registration token (see lib/core/services/push_service.dart). A phone that
-- already registered a token tells the server which one, so its old row is
-- dropped and the phone is not sent every push twice.
--
-- Only a row of the caller's own may be replaced.

drop function if exists public.register_device_token(text, text);

create or replace function public.register_device_token(
  p_token text,
  p_platform text,
  p_replaces text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();

  if p_replaces is not null and p_replaces <> p_token then
    delete from public.device_tokens
    where token = p_replaces and user_id = auth.uid();
  end if;
end;
$$;

revoke all on function public.register_device_token(text, text, text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;

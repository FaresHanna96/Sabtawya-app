-- Per-environment settings, so the same migrations serve production and dev.
-- Until now the notification trigger called a function URL hard-coded to
-- production.

create table if not exists public.app_config (
  key   text primary key,
  value text not null
);

-- No policies: clients can neither read nor change it. The security definer
-- functions below read it, and the dashboard / service role can edit it.
alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;

create or replace function public.push_notification()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_url text;
begin
  select value into v_url from public.app_config where key = 'functions_url';
  if v_url is null then
    return new; -- no push endpoint configured for this environment
  end if;

  perform net.http_post(
    url := v_url || '/push-admins',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('kind', 'notification', 'notification_id', new.id)
  );
  return new;
exception when others then
  return new;
end;
$$;

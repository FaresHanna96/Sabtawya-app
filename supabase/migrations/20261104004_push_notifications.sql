-- Push notifications for the admin when a servant sign-up arrives.

create extension if not exists pg_net with schema extensions;

-- FCM device tokens, one row per browser / phone.
create table if not exists public.device_tokens (
  token       text primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  platform    text,
  updated_at  timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy device_tokens_own on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Set once the admins were notified, so a request is pushed only one time.
alter table public.profiles
  add column if not exists push_notified_at timestamptz;

-- When a servant signs up and waits for approval, tell the edge function.
create or replace function public.notify_admins_of_signup()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  perform net.http_post(
    url := 'https://fxclufgfkvfrhdleyndf.supabase.co/functions/v1/push-admins',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('profile_id', new.id)
  );
  return new;
exception when others then
  -- A failed notification must never block the sign-up itself.
  return new;
end;
$$;

drop trigger if exists profiles_notify_admins on public.profiles;
create trigger profiles_notify_admins
  after insert on public.profiles
  for each row
  when (new.role = 'servant' and not new.is_active)
  execute function public.notify_admins_of_signup();

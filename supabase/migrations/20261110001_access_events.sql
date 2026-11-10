-- Counts of APK downloads and app/site opens. No personal data: only the kind
-- of event, the platform and the time. Anyone may add a row (the download page
-- and the app write before sign-in); only admins read; nobody edits or deletes.
create table if not exists public.access_events (
  id         bigint generated always as identity primary key,
  kind       text not null check (kind in ('apk_download', 'apk_page', 'app_open')),
  platform   text check (platform is null or char_length(platform) <= 20),
  created_at timestamptz not null default now()
);

create index if not exists access_events_kind_created_idx
  on public.access_events (kind, created_at desc);

alter table public.access_events enable row level security;

drop policy if exists access_events_insert on public.access_events;
create policy access_events_insert on public.access_events
  for insert to anon, authenticated
  with check (true);

drop policy if exists access_events_select_admin on public.access_events;
create policy access_events_select_admin on public.access_events
  for select to authenticated
  using (public.is_admin());

revoke all on public.access_events from anon, authenticated;
grant insert on public.access_events to anon, authenticated;
grant select on public.access_events to authenticated;

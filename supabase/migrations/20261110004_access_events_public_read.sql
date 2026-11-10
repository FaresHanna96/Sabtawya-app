-- The raw access_events rows are readable by anyone. They hold only the kind of
-- event, the platform and the time: nothing personal. Writes stay insert-only.
drop policy if exists access_events_select_public on public.access_events;
create policy access_events_select_public on public.access_events
  for select to anon, authenticated
  using (true);

grant select on public.access_events to anon, authenticated;

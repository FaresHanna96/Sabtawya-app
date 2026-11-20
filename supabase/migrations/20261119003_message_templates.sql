-- Message templates for the families (رسائل للأهالي): texts أمين الخدمة writes
-- once and every servant can pick when messaging the parents of a class or of
-- an event's children on WhatsApp. The app also has a few built-in ones; these
-- are the service's own. Placeholders such as {الطفل} are filled in the app.

create table if not exists public.message_templates (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (length(btrim(title)) between 1 and 80),
  body       text not null check (length(btrim(body)) between 1 and 1000),
  sort_order int  not null default 0,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.message_templates enable row level security;

drop policy if exists message_templates_select on public.message_templates;
create policy message_templates_select on public.message_templates
  for select to authenticated using (public.auth_role() is not null);

drop policy if exists message_templates_write on public.message_templates;
create policy message_templates_write on public.message_templates
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

revoke all on public.message_templates from anon;
grant select, insert, update, delete on public.message_templates to authenticated;

drop trigger if exists message_templates_touch on public.message_templates;
create trigger message_templates_touch
  before update on public.message_templates
  for each row execute function public.touch_updated_at();

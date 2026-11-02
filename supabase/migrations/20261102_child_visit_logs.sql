-- Log every pastoral visit (phone or home) made to a child.
-- Each save in the app appends one row so the full history is preserved.
create table if not exists public.child_visit_logs (
  id          uuid        primary key default gen_random_uuid(),
  child_id    uuid        not null references public.children(id) on delete cascade,
  visit_type  text        not null check (visit_type in ('phone', 'home')),
  visit_date  date        not null,
  notes       text,
  recorded_by uuid        references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

create index if not exists child_visit_logs_child_idx
  on public.child_visit_logs (child_id, visit_type, visit_date desc);

-- Servants may log and read visits for children in their classes; admins see all.
alter table public.child_visit_logs enable row level security;

create policy "select visit logs"
  on public.child_visit_logs for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.children c
      where c.id = child_visit_logs.child_id
        and public.can_access_class(c.class_id)
    )
  );

create policy "insert visit logs"
  on public.child_visit_logs for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.children c
      where c.id = child_visit_logs.child_id
        and public.can_access_class(c.class_id)
    )
  );

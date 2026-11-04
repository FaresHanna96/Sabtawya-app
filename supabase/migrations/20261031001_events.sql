-- =============================================================================
-- Events & Payments feature
-- Each event has a cost per child; children pay gradually in instalments.
-- Admin creates/edits/deletes events.
-- Servant records payments for their class; admin/general_servant for all.
-- =============================================================================

-- The policies below use is_general_servant(), which migration 20261031002
-- defines. On a database built from scratch this file runs first, so the role
-- and the helper are created here too (both are idempotent).
alter type public.app_role add value if not exists 'general_servant';

create or replace function public.is_general_servant()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select p.role::text = 'general_servant'
     from public.profiles p
     where p.id = auth.uid() and p.is_active),
    false
  );
$$;

grant execute on function public.is_general_servant() to authenticated;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  event_date   date not null,
  cost         numeric(10,2) not null check (cost > 0),
  year_id      uuid references public.attendance_years(id) on delete set null,
  created_by   uuid not null references public.profiles(id),
  created_at   timestamptz not null default now()
);

create table if not exists public.event_payments (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  child_id   uuid not null references public.children(id) on delete cascade,
  amount     numeric(10,2) not null check (amount > 0),
  paid_by    uuid not null references public.profiles(id),
  paid_at    timestamptz not null default now(),
  notes      text
);

-- ---------------------------------------------------------------------------
-- View: balance per child per event (every active child is auto-enrolled)
-- ---------------------------------------------------------------------------

create or replace view public.v_child_event_balances as
select
  e.id                                          as event_id,
  e.title                                       as event_title,
  e.cost,
  c.id                                          as child_id,
  c.full_name                                   as child_name,
  c.class_id,
  coalesce(sum(p.amount), 0)                    as total_paid,
  e.cost - coalesce(sum(p.amount), 0)           as remaining
from public.events e
cross join public.children c
left join public.event_payments p
       on p.event_id = e.id and p.child_id = c.id
where c.is_active = true
group by e.id, e.title, e.cost, c.id, c.full_name, c.class_id;

-- ---------------------------------------------------------------------------
-- RLS – events
-- ---------------------------------------------------------------------------

alter table public.events enable row level security;

drop policy if exists "events_select" on public.events;
create policy "events_select" on public.events
  for select using (auth.role() = 'authenticated');

drop policy if exists "events_insert" on public.events;
create policy "events_insert" on public.events
  for insert with check (public.is_admin());

drop policy if exists "events_update" on public.events;
create policy "events_update" on public.events
  for update using (public.is_admin());

drop policy if exists "events_delete" on public.events;
create policy "events_delete" on public.events
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------------
-- RLS – event_payments
-- ---------------------------------------------------------------------------

alter table public.event_payments enable row level security;

drop policy if exists "ep_select" on public.event_payments;
create policy "ep_select" on public.event_payments
  for select using (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1 from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid()
        and ch.id = event_payments.child_id
    )
  );

drop policy if exists "ep_insert" on public.event_payments;
create policy "ep_insert" on public.event_payments
  for insert with check (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1 from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid()
        and ch.id = event_payments.child_id
    )
  );

drop policy if exists "ep_delete" on public.event_payments;
create policy "ep_delete" on public.event_payments
  for delete using (
    public.is_admin()
    or paid_by = auth.uid()
  );

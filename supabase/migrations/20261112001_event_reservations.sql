-- A child can reserve a trip place now and pay later. Until now servants
-- recorded a 1 EGP payment as a booking marker; this records the booking
-- itself. Additive only: no existing rows are changed or removed.
create table if not exists public.event_reservations (
  event_id    uuid        not null references public.events(id) on delete cascade,
  child_id    uuid        not null references public.children(id) on delete cascade,
  reserved_by uuid        references public.profiles(id) on delete set null,
  reserved_at timestamptz not null default now(),
  primary key (event_id, child_id)
);

alter table public.event_reservations enable row level security;

-- Same rules as event_payments: admins and general servants for everyone,
-- a servant for the children of their own classes. Removing a reservation is
-- for the admin or whoever made it.
drop policy if exists er_select on public.event_reservations;
create policy er_select on public.event_reservations
  for select to authenticated
  using (
    public.is_admin() or public.is_general_servant() or exists (
      select 1 from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid() and ch.id = event_reservations.child_id
    )
  );

drop policy if exists er_insert on public.event_reservations;
create policy er_insert on public.event_reservations
  for insert to authenticated
  with check (
    public.is_admin() or public.is_general_servant() or exists (
      select 1 from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid() and ch.id = event_reservations.child_id
    )
  );

drop policy if exists er_delete on public.event_reservations;
create policy er_delete on public.event_reservations
  for delete to authenticated
  using (public.is_admin() or reserved_by = auth.uid());

grant select, insert, delete on public.event_reservations to authenticated;

-- The balances view gains a "reserved" flag at the end (existing columns are
-- unchanged, so the replace is safe). It keeps running as the caller.
create or replace view public.v_child_event_balances
with (security_invoker = true) as
select e.id as event_id,
       e.title as event_title,
       e.cost,
       c.id as child_id,
       c.full_name as child_name,
       c.class_id,
       coalesce(sum(p.amount), 0::numeric) as total_paid,
       e.cost - coalesce(sum(p.amount), 0::numeric) as remaining,
       exists (
         select 1 from public.event_reservations r
         where r.event_id = e.id and r.child_id = c.id
       ) as reserved
from public.events e
cross join public.children c
left join public.event_payments p on p.event_id = e.id and p.child_id = c.id
where c.is_active = true
group by e.id, e.title, e.cost, c.id, c.full_name, c.class_id;

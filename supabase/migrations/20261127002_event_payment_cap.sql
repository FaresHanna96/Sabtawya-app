-- Two servants could each take the rest of a child's fee for an event: only
-- the app checked what was left. The database now refuses a payment that takes
-- a child above the event's cost. Rows already saved are not touched.

create or replace function public.event_payments_cap()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cost numeric;
  v_paid numeric;
begin
  -- One payment at a time for this child and event, so two cannot both fit.
  perform pg_advisory_xact_lock(
    hashtextextended(new.event_id::text || new.child_id::text, 0));

  -- A payment sent again after its answer was lost: it is saved already, so
  -- leave it to the primary key, which the app reads as "saved".
  if exists (select 1 from public.event_payments p where p.id = new.id) then
    return new;
  end if;

  select e.cost into v_cost from public.events e where e.id = new.event_id;
  select coalesce(sum(p.amount), 0) into v_paid
    from public.event_payments p
   where p.event_id = new.event_id and p.child_id = new.child_id;

  if v_paid + new.amount > v_cost then
    raise exception 'المبلغ أكبر من المتبقي على المخدوم'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function public.event_payments_cap()
  from public, anon, authenticated;

drop trigger if exists event_payments_cap on public.event_payments;
create trigger event_payments_cap
  before insert on public.event_payments
  for each row execute function public.event_payments_cap();

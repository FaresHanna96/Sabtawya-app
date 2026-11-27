-- Gaps found in review: functions callable without signing in, and a
-- deactivated servant who could still read and add event money.
--
-- Supabase grants execute to `anon` on its own for every new function, so
-- `revoke ... from public` alone never closed one to signed-out callers.

-- 1. Told anyone whether an email has an account. The app does not call it.
drop function if exists public.check_email_registered(text);

-- 2. No permission check of its own: only for generate_sessions_for_year (which
--    checks for an admin) and the two backfill triggers, which run as the owner.
revoke all on function public.generate_sessions_internal(uuid, uuid)
  from public, anon, authenticated;

-- 3. Whole-service totals: active accounts only.
create or replace function public.service_weekly_attendance(
  p_year uuid,
  p_from date
)
returns table (
  session_date date,
  present      int,
  children     int
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select s.session_date,
         sum(s.present_count)::int   as present,
         sum(s.active_children)::int as children
    from public.v_class_session_summary s
   where public.auth_role() is not null
     and s.year_id = p_year
     and s.session_date >= p_from
     and s.session_date <= current_date
     and s.recorded_count > 0
   group by s.session_date
   order by s.session_date;
$$;

revoke all on function public.service_weekly_attendance(uuid, date)
  from public, anon;
grant execute on function public.service_weekly_attendance(uuid, date)
  to authenticated;

-- 4. New functions start closed to signed-out callers. One meant to be called
--    before signing in needs its own `grant execute ... to anon`.
--    PUBLIC's grant is a global default, so it cannot be revoked per schema.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public
  revoke execute on functions from anon;

-- 5. Event money and bookings: serves_class() also requires an active account;
--    the plain class_servants join did not.
drop policy if exists ep_select on public.event_payments;
create policy ep_select on public.event_payments
  for select to authenticated
  using (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1 from public.children ch
      where ch.id = event_payments.child_id
        and public.serves_class(ch.class_id)
    )
  );

drop policy if exists ep_insert on public.event_payments;
create policy ep_insert on public.event_payments
  for insert to authenticated
  with check (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1 from public.children ch
      where ch.id = event_payments.child_id
        and public.serves_class(ch.class_id)
    )
  );

drop policy if exists ep_delete on public.event_payments;
create policy ep_delete on public.event_payments
  for delete to authenticated
  using (
    public.is_admin()
    or (paid_by = auth.uid() and public.auth_role() is not null)
  );

drop policy if exists er_select on public.event_reservations;
create policy er_select on public.event_reservations
  for select to authenticated
  using (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1 from public.children ch
      where ch.id = event_reservations.child_id
        and public.serves_class(ch.class_id)
    )
  );

drop policy if exists er_insert on public.event_reservations;
create policy er_insert on public.event_reservations
  for insert to authenticated
  with check (
    public.is_admin()
    or public.is_general_servant()
    or exists (
      select 1 from public.children ch
      where ch.id = event_reservations.child_id
        and public.serves_class(ch.class_id)
    )
  );

drop policy if exists er_delete on public.event_reservations;
create policy er_delete on public.event_reservations
  for delete to authenticated
  using (
    public.is_admin()
    or (reserved_by = auth.uid() and public.auth_role() is not null)
  );

-- 6. The events themselves: not for waiting, refused or deactivated accounts.
drop policy if exists events_select on public.events;
create policy events_select on public.events
  for select to authenticated
  using (public.auth_role() is not null);

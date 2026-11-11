-- A servant correcting a follow-up note on the same day used to add a second
-- history row. The app now updates its own row for the same child, type and
-- date instead, so writers may update the rows they recorded (admins any).
-- Additive only: no rows are changed or removed by this migration.
drop policy if exists "update own visit logs" on public.child_visit_logs;
create policy "update own visit logs"
  on public.child_visit_logs for update to authenticated
  using (
    public.is_admin()
    or (
      recorded_by = auth.uid()
      and exists (
        select 1 from public.children c
        where c.id = child_visit_logs.child_id
          and public.can_access_class(c.class_id)
      )
    )
  )
  with check (
    public.is_admin()
    or (
      recorded_by = auth.uid()
      and exists (
        select 1 from public.children c
        where c.id = child_visit_logs.child_id
          and public.can_access_class(c.class_id)
      )
    )
  );

grant update on public.child_visit_logs to authenticated;

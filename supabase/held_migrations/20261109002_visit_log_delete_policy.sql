-- A visit entry made by mistake could only be removed with a database edit.
-- Allow the servant who wrote an entry, and admins, to delete it.
--
-- NOT applied to production yet: held back until the owner approves deleting
-- visit entries from the app (see _allowVisitDelete in child_profile_screen).
drop policy if exists "delete visit logs" on public.child_visit_logs;
create policy "delete visit logs"
  on public.child_visit_logs for delete
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
  );

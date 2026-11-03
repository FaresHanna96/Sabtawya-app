-- خادم عام may take attendance for any class. Only attendance: children,
-- classes and visits stay as they are.

drop policy if exists attendance_sessions_insert on public.attendance_sessions;
create policy attendance_sessions_insert on public.attendance_sessions
  for insert to authenticated
  with check (public.can_access_class(class_id) or public.is_general_servant());

drop policy if exists attendance_sessions_update on public.attendance_sessions;
create policy attendance_sessions_update on public.attendance_sessions
  for update to authenticated
  using (public.can_access_class(class_id) or public.is_general_servant())
  with check (public.can_access_class(class_id) or public.is_general_servant());

drop policy if exists attendance_records_insert on public.attendance_records;
create policy attendance_records_insert on public.attendance_records
  for insert to authenticated
  with check (
    public.is_general_servant()
    or exists (
      select 1 from public.attendance_sessions s
      where s.id = attendance_records.session_id
        and public.can_access_class(s.class_id)
    )
  );

drop policy if exists attendance_records_update on public.attendance_records;
create policy attendance_records_update on public.attendance_records
  for update to authenticated
  using (
    public.is_general_servant()
    or exists (
      select 1 from public.attendance_sessions s
      where s.id = attendance_records.session_id
        and public.can_access_class(s.class_id)
    )
  )
  with check (
    public.is_general_servant()
    or exists (
      select 1 from public.attendance_sessions s
      where s.id = attendance_records.session_id
        and public.can_access_class(s.class_id)
    )
  );

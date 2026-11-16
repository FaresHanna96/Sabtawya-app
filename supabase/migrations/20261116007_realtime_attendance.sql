-- The attendance sheet updates live: a mark a co-servant saves appears on the
-- other phones without reloading. The app subscribes to changes of
-- attendance_records for the Saturdays it shows; row level security applies,
-- so a servant only receives the classes they serve.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'attendance_records'
     ) then
    alter publication supabase_realtime add table public.attendance_records;
  end if;
end $$;

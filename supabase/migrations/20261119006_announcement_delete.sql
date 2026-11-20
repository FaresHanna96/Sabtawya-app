-- أمين الخدمة can take an announcement back (sent by mistake, or no longer
-- true): deleting it also removes it from every recipient's bell.

drop policy if exists announcements_delete on public.announcements;
create policy announcements_delete on public.announcements
  for delete to authenticated using (public.is_admin());

grant delete on public.announcements to authenticated;

create or replace function public.announcement_deleted()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.notifications
  where kind = 'announcement' and ref_id = old.id;
  return old;
end;
$$;

revoke all on function public.announcement_deleted() from public, anon, authenticated;

drop trigger if exists announcements_clear_bells on public.announcements;
create trigger announcements_clear_bells
  after delete on public.announcements
  for each row execute function public.announcement_deleted();

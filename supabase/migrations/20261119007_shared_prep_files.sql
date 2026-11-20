-- Fix for 20261119005: the policy letting every servant read a shared prep's
-- files looked the prep up as the reader, whose own policy on
-- servant_lesson_preps hides other servants' preps, so it never matched.
-- The lookup now runs as the owner, through a function that only answers
-- "is the prep this file belongs to shared?".

create or replace function public.prep_file_is_shared(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.servant_lesson_preps p
    where p.id::text = split_part(p_object_name, '/', 1)
      and p.shared_at is not null
  );
$$;

revoke all on function public.prep_file_is_shared(text) from public, anon;
grant execute on function public.prep_file_is_shared(text) to authenticated;

drop policy if exists ss_select_shared on storage.objects;
create policy ss_select_shared on storage.objects
  for select to authenticated
  using (
    bucket_id = 'servant-submissions'
    and public.auth_role() is not null
    and public.prep_file_is_shared(name)
  );

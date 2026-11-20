-- An announcement that would reach nobody (e.g. chosen classes with no
-- servant) is refused instead of being saved with "قرأه 0 من 0". The error is
-- in Arabic because the app shows the database's message as it is, and the
-- whole send is rolled back, so nothing is stored.

create or replace function public.send_announcement(
  p_title     text,
  p_body      text,
  p_audience  text,
  p_class_ids uuid[] default '{}'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id    uuid;
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'only the admin can send announcements' using errcode = '42501';
  end if;

  insert into public.announcements (title, body, audience, class_ids, created_by)
  values (btrim(p_title), btrim(p_body), p_audience,
          coalesce(p_class_ids, '{}'), auth.uid())
  returning id into v_id;

  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id, 'announcement', btrim(p_title), btrim(p_body), v_id
  from public.profiles p
  where p.is_active
    and not p.is_hidden
    and p.id <> auth.uid()
    and case p_audience
          when 'all'      then true
          when 'servants' then p.role = 'servant'
          when 'general'  then p.role = 'general_servant'
          when 'classes'  then exists (
                 select 1 from public.class_servants cs
                 where cs.servant_id = p.id
                   and cs.class_id = any (p_class_ids))
          else false
        end;
  get diagnostics v_count = row_count;

  if v_count = 0 then
    raise exception 'مفيش حد هيوصله الإعلان ده (مفيش خدام في الاختيار ده). اختار جمهور تاني.'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object('id', v_id, 'recipients', v_count);
end;
$$;

revoke all on function public.send_announcement(text, text, text, uuid[]) from public, anon;
grant execute on function public.send_announcement(text, text, text, uuid[]) to authenticated;

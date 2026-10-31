-- =============================================================================
-- Update handle_new_user to read requested_role from sign-up metadata.
-- Only 'servant' and 'general_servant' are accepted; 'admin' is always ignored.
-- The invite role still wins when a matching invite exists.
-- =============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invite public.servant_invites;
  v_name   text;
  v_gender public.person_gender;
  v_active boolean;
  v_role   public.app_role;
begin
  select * into v_invite
  from public.servant_invites
  where lower(email) = lower(new.email)
    and accepted_at is null
  limit 1;

  v_name := coalesce(
    nullif(btrim(v_invite.full_name), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    split_part(coalesce(new.email, 'user'), '@', 1)
  );

  begin
    v_gender := coalesce(
      v_invite.gender,
      nullif(btrim(new.raw_user_meta_data ->> 'gender'), '')::public.person_gender
    );
  exception
    when invalid_text_representation then
      v_gender := v_invite.gender;
  end;

  -- Invite role always wins. Self-signup may request servant or general_servant;
  -- any other value (including 'admin') falls back to 'servant'.
  begin
    v_role := coalesce(
      v_invite.role,
      case nullif(btrim(new.raw_user_meta_data ->> 'requested_role'), '')
        when 'general_servant' then 'general_servant'::public.app_role
        when 'servant'         then 'servant'::public.app_role
        else null
      end,
      'servant'::public.app_role
    );
  exception
    when others then
      v_role := coalesce(v_invite.role, 'servant'::public.app_role);
  end;

  v_active := v_invite.id is not null;

  insert into public.profiles (id, full_name, email, mobile, gender, role, is_active)
  values (
    new.id,
    v_name,
    new.email,
    coalesce(v_invite.mobile, nullif(btrim(new.raw_user_meta_data ->> 'mobile'), '')),
    v_gender,
    v_role,
    v_active
  )
  on conflict (id) do nothing;

  if v_invite.id is not null then
    insert into public.class_servants (class_id, servant_id, assigned_by)
    select unnest(v_invite.class_ids), new.id, v_invite.created_by
    on conflict (class_id, servant_id) do nothing;

    update public.servant_invites
    set accepted_at = now(), accepted_profile_id = new.id
    where id = v_invite.id;
  end if;

  if not v_active then
    insert into public.activity_log (actor_id, actor_name, action, entity, entity_id, details)
    values (
      new.id,
      v_name,
      'signup',
      'profiles',
      new.id::text,
      jsonb_build_object('name', v_name, 'email', new.email, 'role', v_role)
    );
  end if;

  return new;
end;
$$;

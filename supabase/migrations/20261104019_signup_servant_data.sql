-- Sign-up collects address, confessor and study/work too; they go to servant_details.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invite    public.servant_invites;
  v_name      text;
  v_gender    public.person_gender;
  v_active    boolean;
  v_class     uuid;
  v_birthdate date;
  v_role      public.app_role;
  v_address    text;
  v_confessor  text;
  v_occupation text;
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

  begin
    v_birthdate := coalesce(
      v_invite.birth_date,
      nullif(btrim(new.raw_user_meta_data ->> 'birth_date'), '')::date
    );
  exception
    when others then
      v_birthdate := v_invite.birth_date;
  end;

  -- The invite's role always wins. A self sign-up may ask for servant or
  -- general_servant (خادم / خادمة / خادم عام); anything else, 'admin' included,
  -- falls back to servant.
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
  v_class := case
    when v_invite.id is not null and cardinality(v_invite.class_ids) > 0
      then v_invite.class_ids[1]
    else null
  end;

  insert into public.profiles (id, full_name, email, mobile, gender, birth_date, role, is_active)
  values (
    new.id,
    v_name,
    new.email,
    coalesce(v_invite.mobile, nullif(btrim(new.raw_user_meta_data ->> 'mobile'), '')),
    v_gender,
    v_birthdate,
    v_role,
    v_active
  )
  on conflict (id) do nothing;

  -- Address, confessor and study/work: the invite's values win, otherwise what
  -- the person typed on the sign-up form (sent in the auth metadata).
  v_address    := coalesce(v_invite.address,    nullif(btrim(new.raw_user_meta_data ->> 'address'), ''));
  v_confessor  := coalesce(v_invite.confessor,  nullif(btrim(new.raw_user_meta_data ->> 'confessor'), ''));
  v_occupation := coalesce(v_invite.occupation, nullif(btrim(new.raw_user_meta_data ->> 'occupation'), ''));
  if v_address is not null or v_confessor is not null or v_occupation is not null then
    insert into public.servant_details (profile_id, address, confessor, occupation)
    values (new.id, v_address, v_confessor, v_occupation)
    on conflict (profile_id) do nothing;
  end if;

  if v_class is not null then
    insert into public.class_servants (class_id, servant_id, assigned_by)
    values (v_class, new.id, v_invite.created_by)
    on conflict do nothing;
  end if;

  if v_invite.id is not null then
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
      jsonb_build_object('name', v_name, 'email', new.email, 'gender', v_gender)
    );
  end if;

  return new;
end;
$$;

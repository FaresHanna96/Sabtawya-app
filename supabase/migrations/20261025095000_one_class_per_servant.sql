-- A servant serves exactly one class. A class may still have several servants.
-- The unique index is the rule; the app only hides the extra choices.

delete from public.class_servants cs
using public.class_servants kept
where cs.servant_id = kept.servant_id
  and cs.ctid <> kept.ctid
  and cs.assigned_at > kept.assigned_at;

drop index if exists public.class_servants_one_class_per_servant;
create unique index class_servants_one_class_per_servant
  on public.class_servants (servant_id);

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
  v_class  uuid;
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

  v_active := v_invite.id is not null;
  v_class := case
    when v_invite.id is not null and cardinality(v_invite.class_ids) > 0
      then v_invite.class_ids[1]
    else null
  end;

  insert into public.profiles (id, full_name, email, mobile, gender, role, is_active)
  values (
    new.id,
    v_name,
    new.email,
    coalesce(v_invite.mobile, nullif(btrim(new.raw_user_meta_data ->> 'mobile'), '')),
    v_gender,
    coalesce(v_invite.role, 'servant'),
    v_active
  )
  on conflict (id) do nothing;

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

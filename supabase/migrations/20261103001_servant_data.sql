-- بيانات الخدام: address, confessor, study/work and service year for each
-- servant, visible to أمين الخدمة (admin) only.
--
-- These live in their own table instead of on profiles: profiles_select lets a
-- servant read the co-servants of their class, and hiding single columns would
-- break every `select *` on profiles. A separate admin-only table keeps the
-- data private without touching that policy.

create table if not exists public.servant_details (
  profile_id   uuid primary key references public.profiles (id) on delete cascade,
  address      text,
  confessor    text,
  occupation   text,
  service_year text,
  updated_at   timestamptz not null default now()
);

alter table public.servant_details enable row level security;

drop policy if exists servant_details_all on public.servant_details;
create policy servant_details_all on public.servant_details
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

-- The invite carries the same data until that email signs up.
alter table public.servant_invites
  add column if not exists birth_date   date,
  add column if not exists address      text,
  add column if not exists confessor    text,
  add column if not exists occupation   text,
  add column if not exists service_year text;

-- handle_new_user: as in 20261102003_servant_birthdate.sql, plus the invite's
-- birth date fallback and the servant_details row.
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
    coalesce(v_invite.role, 'servant'),
    v_active
  )
  on conflict (id) do nothing;

  if v_invite.id is not null and (
    v_invite.address is not null or v_invite.confessor is not null
    or v_invite.occupation is not null or v_invite.service_year is not null
  ) then
    insert into public.servant_details (profile_id, address, confessor, occupation, service_year)
    values (new.id, v_invite.address, v_invite.confessor, v_invite.occupation, v_invite.service_year)
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

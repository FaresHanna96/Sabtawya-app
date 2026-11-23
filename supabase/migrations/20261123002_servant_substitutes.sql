-- «مين غطّى؟»: a servant who covered an absent class servant's class on a
-- Saturday. The substitute is credited with «خدمة» (a sunday_school mark)
-- in the same call, and undoing the record takes the mark away again.

create table if not exists public.servant_substitutes (
  id                    uuid        primary key default gen_random_uuid(),
  date                  date        not null,
  class_id              uuid        not null references public.classes(id) on delete cascade,
  absent_servant_id     uuid        not null references public.profiles(id) on delete cascade,
  substitute_servant_id uuid        not null references public.profiles(id) on delete cascade,
  created_by            uuid        references public.profiles(id) on delete set null,
  created_at            timestamptz not null default now(),
  check (absent_servant_id <> substitute_servant_id),
  unique (date, class_id, substitute_servant_id)
);

create index if not exists servant_substitutes_absent_idx
  on public.servant_substitutes (absent_servant_id, date);
create index if not exists servant_substitutes_substitute_idx
  on public.servant_substitutes (substitute_servant_id, date);

alter table public.servant_substitutes enable row level security;

drop policy if exists ss_select on public.servant_substitutes;
create policy ss_select on public.servant_substitutes
for select to authenticated
using (
  public.is_admin()
  or auth.uid() = absent_servant_id
  or auth.uid() = substitute_servant_id
);

drop policy if exists ss_insert on public.servant_substitutes;
create policy ss_insert on public.servant_substitutes
for insert to authenticated
with check (public.is_admin());

drop policy if exists ss_delete on public.servant_substitutes;
create policy ss_delete on public.servant_substitutes
for delete to authenticated
using (public.is_admin());

-- Records the substitute and their «خدمة» mark together (the mark may
-- already exist). Runs as the caller, so the admin-only policies apply.
create or replace function public.record_substitute(
  p_date date,
  p_class_id uuid,
  p_absent_servant_id uuid,
  p_substitute_servant_id uuid
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.servant_substitutes
    (date, class_id, absent_servant_id, substitute_servant_id, created_by)
  values
    (p_date, p_class_id, p_absent_servant_id, p_substitute_servant_id, auth.uid())
  returning id into v_id;

  insert into public.servant_attendances
    (servant_id, activity_type, date, recorded_by)
  values
    (p_substitute_servant_id, 'sunday_school', p_date, auth.uid())
  on conflict (servant_id, activity_type, date) do nothing;

  return v_id;
end;
$$;

-- Undoes one substitute record and the «خدمة» mark it gave, unless the
-- same servant still covers another class that day.
create or replace function public.remove_substitute(p_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row public.servant_substitutes;
begin
  delete from public.servant_substitutes where id = p_id
  returning * into v_row;
  if v_row.id is null then
    return;
  end if;

  if not exists (
    select 1 from public.servant_substitutes
    where substitute_servant_id = v_row.substitute_servant_id
      and date = v_row.date
  ) then
    delete from public.servant_attendances
    where servant_id = v_row.substitute_servant_id
      and activity_type = 'sunday_school'
      and date = v_row.date;
  end if;
end;
$$;

grant execute on function public.record_substitute(date, uuid, uuid, uuid) to authenticated;
grant execute on function public.remove_substitute(uuid) to authenticated;

-- Deleting a servant: their substitute rows go with them (cascade); rows
-- they created keep going with created_by cleared.

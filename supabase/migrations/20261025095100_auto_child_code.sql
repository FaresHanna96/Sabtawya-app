-- Child codes are issued by the database. The client never chooses them.

create sequence if not exists public.children_code_seq;

select setval(
  'public.children_code_seq',
  greatest(
    coalesce((
      select max((regexp_match(code, '^C([0-9]+)$'))[1]::int)
      from public.children
      where code ~ '^C[0-9]+$'
    ), 0),
    0
  )
);

create or replace function public.children_stamp()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, auth.uid());
    new.created_at := now();
    new.code := 'C' || lpad(nextval('public.children_code_seq')::text, 3, '0');
  else
    new.code := old.code;
  end if;

  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  new.full_name  := btrim(new.full_name);

  if new.birth_date is not null and new.birth_date > current_date then
    raise exception 'تاريخ الميلاد لا يمكن أن يكون في المستقبل' using errcode = '23514';
  end if;

  return new;
end;
$$;

update public.children
set code = 'C' || lpad(nextval('public.children_code_seq')::text, 3, '0')
where code is null or btrim(code) = '';

alter table public.children alter column code set not null;

drop index if exists public.children_code_key;
create unique index children_code_key on public.children (code);

comment on column public.children.code is
  'Auto-issued business key (C001, C002, …). Used by Excel import to match an existing child.';

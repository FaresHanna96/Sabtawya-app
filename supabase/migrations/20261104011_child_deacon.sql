-- شماس: a flag on a boy's details page.
alter table public.children
  add column if not exists is_deacon boolean not null default false;

comment on column public.children.is_deacon is
  'True when the (boy) child serves as a deacon.';

-- Track pastoral visits per child: last phone visit and last home visit,
-- each with an optional free-text notes field.
alter table public.children
  add column if not exists last_phone_visit_date  date,
  add column if not exists last_phone_visit_notes text,
  add column if not exists last_home_visit_date   date,
  add column if not exists last_home_visit_notes  text;

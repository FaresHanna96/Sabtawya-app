-- =============================================================================
-- 14 - Birthdays by month
-- =============================================================================
-- Month and day are projected as integers so the app can filter by month
-- without string work, and age_turning is the age the child reaches in the
-- current calendar year, which is what a birthday list is actually about.
-- =============================================================================

create or replace view public.v_child_birthdays
with (security_invoker = true) as
select
  ch.id                                            as child_id,
  ch.full_name                                     as child_name,
  ch.gender,
  ch.photo_path,
  ch.class_id,
  c.name                                           as class_name,
  ch.birth_date,
  extract(month from ch.birth_date)::int           as birth_month,
  extract(day   from ch.birth_date)::int           as birth_day,
  (extract(year from current_date)
     - extract(year from ch.birth_date))::int      as age_turning
from public.children ch
join public.classes c on c.id = ch.class_id
where ch.is_active
  and ch.birth_date is not null;

revoke all on public.v_child_birthdays from anon;
grant select on public.v_child_birthdays to authenticated;

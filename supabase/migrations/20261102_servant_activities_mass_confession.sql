-- Extend servant_attendances to include mass and confession activity types.
alter table public.servant_attendances
  drop constraint if exists servant_attendances_activity_type_check;

alter table public.servant_attendances
  add constraint servant_attendances_activity_type_check
  check (activity_type in ('sunday_school', 'servant_meeting', 'lesson_prep', 'mass', 'confession'));

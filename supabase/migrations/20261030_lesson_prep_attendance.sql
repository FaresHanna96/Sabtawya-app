-- Allow 'lesson_prep' as a manual-attendance activity type so admins can mark
-- lesson-prep attendance even when the servant did not submit a digital prep.

alter table public.servant_attendances
  drop constraint servant_attendances_activity_type_check;

alter table public.servant_attendances
  add constraint servant_attendances_activity_type_check
  check (activity_type in ('sunday_school', 'servant_meeting', 'lesson_prep'));

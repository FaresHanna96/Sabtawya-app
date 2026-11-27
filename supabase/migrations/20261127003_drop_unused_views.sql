-- Views no screen, function or page reads any more. Dropped without cascade:
-- if something did depend on one, this fails instead of taking it along.
drop view if exists public.v_child_commitment;
drop view if exists public.v_child_sunday_school;
drop view if exists public.v_child_birthdays;

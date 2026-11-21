-- The whole service's attendance per Saturday, for a servant's home page to
-- compare their class with («فصلك 60% • الخدمة كلها 51%»). A servant can read
-- only their own classes, so this runs as the owner and returns totals only:
-- no class names, no children, nothing about any one class.
--
-- A class that did not take attendance that Saturday is left out (not counted
-- as absent), the same rule as the weekly chart.

create or replace function public.service_weekly_attendance(
  p_year uuid,
  p_from date
)
returns table (
  session_date date,
  present      int,
  children     int
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select s.session_date,
         sum(s.present_count)::int   as present,
         sum(s.active_children)::int as children
    from public.v_class_session_summary s
   where s.year_id = p_year
     and s.session_date >= p_from
     and s.session_date <= current_date
     and s.recorded_count > 0
   group by s.session_date
   order by s.session_date;
$$;

revoke all on function public.service_weekly_attendance(uuid, date) from public;
grant execute on function public.service_weekly_attendance(uuid, date) to authenticated;

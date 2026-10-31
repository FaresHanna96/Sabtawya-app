-- Fix v_child_event_balances to respect children table RLS for servants.
-- Without security_invoker the view runs as the postgres superuser (SECURITY
-- DEFINER), bypassing the children RLS policies entirely so every servant
-- could see every active child.  PostgreSQL 15+ supports setting this on an
-- existing view without recreating it.
alter view public.v_child_event_balances set (security_invoker = true);

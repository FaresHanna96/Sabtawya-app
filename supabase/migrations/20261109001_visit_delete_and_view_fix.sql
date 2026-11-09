-- Security: v_child_competition_scores ignored row-level security and was
-- readable by anonymous visitors (anyone holding the public key). Make it
-- run as the caller, so competition_marks' policies decide who sees what,
-- and take anonymous access away. Removes access only; no data is touched.
alter view public.v_child_competition_scores set (security_invoker = true);
revoke all on public.v_child_competition_scores from anon;
grant select on public.v_child_competition_scores to authenticated;

-- Same hygiene for the event balances view (already security_invoker, so the
-- tables' policies protected it, but anon has no business with it).
revoke all on public.v_child_event_balances from anon;
grant select on public.v_child_event_balances to authenticated;

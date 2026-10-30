-- =============================================================================
-- check_email_registered : callable by anon for the forgot-password flow
-- =============================================================================
-- The profiles table is not accessible to unauthenticated (anon) users.
-- This SECURITY DEFINER function lets the forgot-password screen verify that
-- the email is registered before sending the reset link, without exposing the
-- table or allowing email enumeration via direct SQL.
-- =============================================================================

create or replace function public.check_email_registered(p_email text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1 from public.profiles
    where lower(email) = lower(trim(p_email))
  );
end;
$$;

grant execute on function public.check_email_registered(text) to anon;

-- Name check for the sign-up form: is this name already used by an account?
--
-- Names are compared the way the app sorts them (ArabicSort.key in
-- lib/core/utils/arabic_sort.dart): spaces trimmed and collapsed, diacritics
-- and tatweel dropped, أ إ آ ٱ read as ا, ى as ي, ة as ه. So "ناهد يسرى شوقى"
-- and "ناهد يسري شوقي" count as the same name.
create or replace function public.person_name_key(p_name text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select lower(regexp_replace(
           translate(
             regexp_replace(btrim(coalesce(p_name, '')), '[ً-ٰٟـ]', '', 'g'),
             'أإآٱىة', 'اااايه'),
           '\s+', ' ', 'g'));
$$;

-- True when an account (other than a refused sign-up request) already has
-- this name. Callable before signing in, because the sign-up form has no
-- session yet; it answers yes or no and reveals nothing else.
create or replace function public.servant_name_taken(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles p
    where p.rejected_at is null
      and public.person_name_key(p.full_name) = public.person_name_key(p_name)
  );
$$;

revoke all on function public.servant_name_taken(text) from public;
grant execute on function public.servant_name_taken(text) to anon, authenticated;

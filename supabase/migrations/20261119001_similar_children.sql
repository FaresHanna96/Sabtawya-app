-- Duplicate child warning: before a child is added (one by one or from Excel),
-- the app asks whether a child that looks the same is already registered in
-- ANY class. A servant only sees their own classes, and a duplicate usually
-- sits in another one (added under the wrong grade, or by another servant),
-- so this is a narrow security-definer exception like servant_directory: it
-- returns the name, the class and why it matched, nothing else.
--
-- What counts as "the same child" (names go through person_name_key, which
-- drops diacritics and unifies alef / ya / ta marbuta):
--   * the same whole name, or
--   * the same first name, and the same second name (the father's) or a
--     shared phone number (child, mother or father, compared by last 10 digits).
-- Brothers and sisters share the parents' numbers but not the first name, so
-- they are not flagged.

-- The last ten digits of a phone number, Arabic digits included; null when it
-- is too short to be one.
create or replace function public.phone_key(p_raw text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case when length(d) >= 10 then right(d, 10) end
  from (
    select regexp_replace(
             translate(coalesce(p_raw, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
                       '01234567890123456789'),
             '[^0-9]', '', 'g') as d
  ) x;
$$;

-- The name as words to compare: person_name_key, with "عبد" joined to the
-- word after it, so "عبد المسيح" and "عبد الملاك" differ in their first word.
create or replace function public.child_name_words(p_name text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select regexp_replace(public.person_name_key(p_name), '(^| )عبد ', '\1عبد', 'g');
$$;

-- p_candidates: [{ "key": "...", "name": "...", "mobiles": ["010..", ...],
--                  "exclude_id": "<uuid or null>" }, ...]
create or replace function public.similar_children(p_candidates jsonb)
returns table (
  key        text,
  child_id   uuid,
  full_name  text,
  class_id   uuid,
  class_name text,
  is_active  boolean,
  reason     text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with cand as (
    select
      c->>'key'                                  as key,
      public.person_name_key(c->>'name')         as name_key,
      nullif(c->>'exclude_id', '')::uuid         as exclude_id,
      coalesce(array(
        select public.phone_key(m)
        from jsonb_array_elements_text(coalesce(c->'mobiles', '[]'::jsonb)) m
        where public.phone_key(m) is not null
      ), '{}'::text[])                           as phones
    from jsonb_array_elements(coalesce(p_candidates, '[]'::jsonb)) c
    where public.auth_role() is not null
      and length(btrim(coalesce(c->>'name', ''))) > 0
  ),
  cand_words as (
    select cand.*,
           split_part(public.child_name_words(name_key), ' ', 1) as w1,
           split_part(public.child_name_words(name_key), ' ', 2) as w2
    from cand
  ),
  kids as (
    select ch.id, ch.full_name, ch.class_id, ch.is_active,
           public.person_name_key(ch.full_name) as name_key,
           public.child_name_words(ch.full_name) as words,
           array_remove(array[
             public.phone_key(ch.mobile),
             public.phone_key(ch.mother_mobile),
             public.phone_key(ch.father_mobile)
           ], null) as phones
    from public.children ch
  ),
  matched as (
    select
      cw.key,
      k.id, k.full_name, k.class_id, k.is_active,
      case
        when k.name_key = cw.name_key then 'same_name'
        when cw.w2 <> '' and split_part(k.words, ' ', 2) = cw.w2
          then 'same_first_and_father'
        else 'same_first_and_phone'
      end as reason
    from cand_words cw
    join kids k
      on (cw.exclude_id is null or k.id <> cw.exclude_id)
     and (
          k.name_key = cw.name_key
       or (
            split_part(k.words, ' ', 1) = cw.w1
        and (
              (cw.w2 <> '' and split_part(k.words, ' ', 2) = cw.w2)
           or k.phones && cw.phones
            )
          )
         )
  ),
  ranked as (
    select m.*,
           row_number() over (
             partition by m.key
             order by (m.reason = 'same_name') desc, m.is_active desc, m.full_name
           ) as n
    from matched m
  )
  select r.key, r.id, r.full_name, r.class_id, cl.name, r.is_active, r.reason
  from ranked r
  join public.classes cl on cl.id = r.class_id
  where r.n <= 3
  order by r.key, r.n;
$$;

revoke all on function public.similar_children(jsonb) from public, anon;
grant execute on function public.similar_children(jsonb) to authenticated;

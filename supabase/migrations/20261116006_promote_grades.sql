-- New-year promotion of the classes as one transaction. The app used to do it
-- with a dozen separate requests, so a failure halfway left some classes moved
-- up and others not, and running it twice moved everybody up twice.
--
-- A class moves up as a whole (children, servants, patron and picture stay
-- with it): the 6 class is archived with its children (renamed with the year's
-- name, which frees the name and takes it out of the lists), 5 becomes 6, 4
-- becomes 5, 3 becomes 4, and fresh 3 classes are added, for boys ("ولاد")
-- and girls ("بنات") alike.
--
--   p_dry_run = true   changes nothing and returns what would happen (the
--                      preview the app shows before asking)
--
-- It refuses to run twice for the same year: once classes archived under that
-- name exist, the promotion is done.

create or replace function public.promote_grades(
  p_archive_suffix text,
  p_dry_run boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_suffix   text := btrim(coalesce(p_archive_suffix, ''));
  v_genders  text[] := array['ولاد', 'بنات'];
  v_gender   text;
  v_grade    int;
  v_class    public.classes;
  v_count    int;
  v_moves    jsonb := '[]'::jsonb;
  v_archived jsonb := '[]'::jsonb;
  v_created  jsonb := '[]'::jsonb;
begin
  if not public.is_admin() then
    raise exception 'غير مصرح لك بترقية الفصول' using errcode = '42501';
  end if;
  if v_suffix = '' then
    raise exception 'اسم السنة مطلوب' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.classes
    where name in ('6 ولاد ' || v_suffix, '6 بنات ' || v_suffix)
  ) then
    raise exception 'تمت ترقية الفصول لهذه السنة من قبل' using errcode = '23505';
  end if;

  foreach v_gender in array v_genders loop
    -- Graduating: the 6 class leaves the lists with its children.
    select * into v_class from public.classes
    where is_active and name = '6 ' || v_gender;
    if found then
      select count(*) into v_count
      from public.children where class_id = v_class.id and is_active;
      v_archived := v_archived || jsonb_build_object(
        'name', v_class.name,
        'to', v_class.name || ' ' || v_suffix,
        'children', v_count);
      if not p_dry_run then
        update public.children set is_active = false where class_id = v_class.id;
        update public.classes
           set name = v_class.name || ' ' || v_suffix,
               sort_order = 100 + (6 - 3) * 2 + case when v_gender = 'ولاد' then 1 else 2 end,
               is_active = false
         where id = v_class.id;
      end if;
    end if;

    -- 5 to 6, 4 to 5, 3 to 4: highest first, so each name is free in turn.
    for v_grade in select g from generate_series(5, 3, -1) as g loop
      select * into v_class from public.classes
      where is_active and name = v_grade || ' ' || v_gender;
      if found then
        select count(*) into v_count
        from public.children where class_id = v_class.id and is_active;
        v_moves := v_moves || jsonb_build_object(
          'from', v_class.name,
          'to', (v_grade + 1) || ' ' || v_gender,
          'children', v_count);
        if not p_dry_run then
          update public.classes
             set name = (v_grade + 1) || ' ' || v_gender,
                 sort_order = (v_grade + 1 - 3) * 2 + case when v_gender = 'ولاد' then 1 else 2 end
           where id = v_class.id;
        end if;
      end if;
    end loop;

    -- A fresh 3 class.
    v_created := v_created || to_jsonb('3 ' || v_gender);
    if not p_dry_run then
      insert into public.classes (name, sort_order)
      values ('3 ' || v_gender, case when v_gender = 'ولاد' then 1 else 2 end);
    end if;
  end loop;

  return jsonb_build_object(
    'dryRun', p_dry_run,
    'archived', v_archived,
    'moves', v_moves,
    'created', v_created);
end;
$$;

revoke all on function public.promote_grades(text, boolean) from public, anon;
grant execute on function public.promote_grades(text, boolean) to authenticated;

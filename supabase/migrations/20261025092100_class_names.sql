-- =============================================================================
-- 10 - Real class names: grade and gender
-- =============================================================================
-- The service covers primary grades 3 to 6, each split into a boys' class and a
-- girls' class, so "الفصل 1" is renamed to the name the servants actually use.
-- Matching is by sort_order, which the seed set to 1..8.
-- =============================================================================

update public.classes c
   set name = v.name
  from (values
    (1, '3 ولاد'),
    (2, '3 بنات'),
    (3, '4 ولاد'),
    (4, '4 بنات'),
    (5, '5 ولاد'),
    (6, '5 بنات'),
    (7, '6 ولاد'),
    (8, '6 بنات')
  ) as v(sort_order, name)
 where c.sort_order = v.sort_order
   and c.name = 'الفصل ' || v.sort_order::text;

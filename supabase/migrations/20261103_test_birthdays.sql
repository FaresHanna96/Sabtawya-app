-- Test data: set birth_date to Nov 2 for two servants so today's birthday
-- section is populated during development.
update public.profiles
  set birth_date = '1990-11-02'
  where id in (
    'cf3f57d6-70be-45c8-8d5f-c018dc883ab0',  -- مينا الخادم
    'f31ae33f-3a2c-42a9-af50-6ddcced1a2c9'   -- فرج اسعد
  );

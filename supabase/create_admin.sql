-- ============================================================
-- One-time script: create the first admin account
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================
-- Credentials for the new admin account:
--   Email   : admin@sabtawya.app
--   Password: jOZ7yfUCJzsU2Drw
-- (delete this file after the account is confirmed working)
-- ============================================================

DO $$
BEGIN
  -- Only insert if the user doesn't already exist
  IF NOT EXISTS (
    SELECT 1 FROM auth.users WHERE lower(email) = 'admin@sabtawya.app'
  ) THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role
    )
    VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000000',
      'admin@sabtawya.app',
      crypt('jOZ7yfUCJzsU2Drw', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"أمين خدمة"}',
      'authenticated',
      'authenticated'
    );
  END IF;
END;
$$;

SELECT public.promote_to_admin('admin@sabtawya.app');

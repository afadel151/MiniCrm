-- T0001__tenant_isolation.sql — businesses (custom id-keyed policy) + the 3 standard tenant tables.
\set ON_ERROR_STOP on
BEGIN;

-- user_a = 99999999-9999-9999-9999-999999999999, biz_a = 11111111-1111-1111-1111-111111111111
-- biz_b = 22222222-2222-2222-2222-222222222222, member_a = 33333333-3333-3333-3333-333333333333

SET ROLE identity_access_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO users (id, email, email_normalized, full_name) VALUES
  ('99999999-9999-9999-9999-999999999999', 'a@example.com', 'a@example.com', 'Alice');
INSERT INTO businesses (id, name, slug, created_by) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Biz A', 'biz-a', '99999999-9999-9999-9999-999999999999');
INSERT INTO business_members (id, business_id, user_id, role) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111',
   '99999999-9999-9999-9999-999999999999', 'owner');
RESET ROLE;

SET ROLE identity_access_app;
SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM businesses WHERE id = '11111111-1111-1111-1111-111111111111') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s businesses row';
  END IF;
  IF EXISTS (SELECT 1 FROM business_members WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s business_members row';
  END IF;
END $$;

SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM businesses WHERE id = '11111111-1111-1111-1111-111111111111') THEN
    RAISE EXCEPTION 'FAIL: tenant A cannot see its own businesses row';
  END IF;
END $$;
RESET ROLE;

-- users is a PLATFORM table (no RLS, doc's "honest gap") — confirm it is reachable regardless of tenant, which
-- is intentional, not a bug: login must work before any business is chosen.
SET ROLE identity_access_app;
SELECT set_config('app.business_id', NULL, true);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = '99999999-9999-9999-9999-999999999999') THEN
    RAISE EXCEPTION 'FAIL: users must be readable with no tenant context (pre-login)';
  END IF;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0001__tenant_isolation';

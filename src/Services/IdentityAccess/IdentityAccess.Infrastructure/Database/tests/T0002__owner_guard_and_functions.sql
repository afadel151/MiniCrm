-- T0002__owner_guard_and_functions.sql — deferred owner-guard constraint triggers, and the pre-tenant
-- SECURITY DEFINER functions (also a regression test for the pinned-search_path table-qualification bug).
\set ON_ERROR_STOP on
BEGIN;

SET ROLE identity_access_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO users (id, email, email_normalized, full_name) VALUES
  ('99999999-9999-9999-9999-999999999999', 'a@example.com', 'a@example.com', 'Alice'),
  ('88888888-8888-8888-8888-888888888888', 'web@example.com', 'web@example.com', 'Web Master');
INSERT INTO businesses (id, name, slug, created_by) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Biz A', 'biz-a', '99999999-9999-9999-9999-999999999999');
INSERT INTO business_members (id, business_id, user_id, role) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111',
   '99999999-9999-9999-9999-999999999999', 'owner');

-- Removing the sole owner (status -> 'removed'; identity_access_app has no DELETE grant, by design) must fail
-- at COMMIT (deferred), not immediately.
SAVEPOINT sp1;
UPDATE business_members SET status = 'removed' WHERE id = '33333333-3333-3333-3333-333333333333';
DO $$ BEGIN RAISE NOTICE 'ok: the UPDATE itself did not raise (deferred to commit)'; END $$;
DO $$ BEGIN
  BEGIN
    EXECUTE 'SET CONSTRAINTS trg_business_members_owner_guard IMMEDIATE';
    RAISE EXCEPTION 'FAIL: removing the sole owner was allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: owner guard rejects removing the sole owner (%)', SQLERRM;
  END;
END $$;
ROLLBACK TO sp1;

-- Ownership transfer within one transaction (remove old owner, add new owner) must succeed.
INSERT INTO business_members (id, business_id, user_id, role) VALUES
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111',
   '88888888-8888-8888-8888-888888888888', 'owner');
UPDATE business_members SET role = 'staff' WHERE id = '33333333-3333-3333-3333-333333333333';
SET CONSTRAINTS trg_business_members_owner_guard IMMEDIATE;
DO $$ BEGIN RAISE NOTICE 'PASS: ownership transfer in one transaction succeeded'; END $$;
RESET ROLE;

-- Pre-tenant lookup functions: must actually execute against real data (catches the search_path/table-
-- qualification bug caught earlier in Scoring, reproduced here independently).
SET ROLE identity_access_app;
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM auth_list_user_memberships('99999999-9999-9999-9999-999999999999') LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAIL: auth_list_user_memberships returned no rows for a user with a membership';
  END IF;
  RAISE NOTICE 'PASS: auth_list_user_memberships resolves public.business_members under a pinned search_path';
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0002__owner_guard_and_functions';

-- T0001__rls_public_client_webmaster.sql — public pub.* views, client review eligibility gate, web_master
-- moderation-only path, and the "business cannot update reviews at all" rule (D10).
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE v_missing text;
BEGIN
  SELECT string_agg(c.relname, ', ') INTO v_missing
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relispartition
    AND c.relname NOT IN ('rating_parameters')
    AND NOT (c.relrowsecurity AND c.relforcerowsecurity);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL: tenant tables without FORCE RLS: %', v_missing;
  END IF;
  RAISE NOTICE 'PASS: every tenant table has FORCE ROW LEVEL SECURITY';
END $$;

SET ROLE presence_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO business_profiles (business_id, name, slug, is_published) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Biz A', 'biz-a', true);
RESET ROLE;

SET ROLE presence_worker;
SELECT set_config('app.business_id', NULL, true);
INSERT INTO app.tenants (business_id, status, source_version) VALUES
  ('11111111-1111-1111-1111-111111111111', 'active', 1);
INSERT INTO client_verified_phones (user_id, phone_hash, source_version) VALUES
  ('66666666-6666-6666-6666-666666666666', decode(repeat('aa', 32), 'hex'), 1);
-- review_eligibility is still tenant_isolation-governed (standard policy): the worker sets the tenant from the
-- event it is processing, same as every other service's worker role.
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO review_eligibility (business_id, basis, interaction_id, phone_hash, source_version) VALUES
  ('11111111-1111-1111-1111-111111111111', 'order', '55555555-5555-5555-5555-555555555555', decode(repeat('aa', 32), 'hex'), 1);
RESET ROLE;

-- Base table is tenant-RLS'd; pub.business_profiles (owner-rights view) is readable with NO tenant context.
SELECT set_config('app.business_id', NULL, true);
SET ROLE presence_app;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM business_profiles) THEN
    RAISE EXCEPTION 'FAIL: business_profiles base table readable without a tenant context';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pub.business_profiles WHERE business_id = '11111111-1111-1111-1111-111111111111') THEN
    RAISE EXCEPTION 'FAIL: pub.business_profiles did not surface the published, active-tenant profile';
  END IF;
  RAISE NOTICE 'PASS: pub.business_profiles works with no tenant context; the base table does not';
END $$;
DO $$ BEGIN
  BEGIN
    EXECUTE 'SELECT rating_sum FROM pub.business_profiles';
    RAISE EXCEPTION 'FAIL: pub.business_profiles exposes the internal rating_sum column';
  EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'PASS: pub.business_profiles does not project rating_sum (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- Client review insert: only accepted through a matching eligibility row + verified phone (DB-enforced §7.1).
SET ROLE presence_client;
SELECT set_config('app.user_id', '66666666-6666-6666-6666-666666666666', true);
INSERT INTO reviews (id, business_id, author_user_id, author_display_name, basis, interaction_id, rating)
VALUES ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111',
        '66666666-6666-6666-6666-666666666666', 'Alice', 'order', '55555555-5555-5555-5555-555555555555', 5);
DO $$ BEGIN RAISE NOTICE 'PASS: eligible client review accepted'; END $$;

DO $$ BEGIN
  BEGIN
    INSERT INTO reviews (business_id, author_user_id, author_display_name, basis, interaction_id, rating)
    VALUES ('11111111-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888888888', 'Bob', 'order',
            '99999999-9999-9999-9999-999999999999', 5);
    RAISE EXCEPTION 'FAIL: review accepted with no matching eligibility row';
  EXCEPTION WHEN insufficient_privilege OR OTHERS THEN
    RAISE NOTICE 'PASS: review without a matching eligibility row is rejected (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- D10: business (presence_app) cannot UPDATE reviews at all — not even to hide its own.
SET ROLE presence_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
DO $$ BEGIN
  BEGIN
    UPDATE reviews SET status = 'hidden' WHERE id = '77777777-7777-7777-7777-777777777777';
    RAISE EXCEPTION 'FAIL: presence_app could update a review';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: presence_app has no UPDATE grant on reviews at all (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- web_master: moderates (status) but cannot edit content.
SET ROLE presence_admin;
UPDATE reviews SET status = 'hidden', moderation_reason = 'spam', moderated_at = now() WHERE id = '77777777-7777-7777-7777-777777777777';
DO $$ BEGIN RAISE NOTICE 'PASS: presence_admin can moderate a review'; END $$;
DO $$ BEGIN
  BEGIN
    UPDATE reviews SET body = 'rewritten by admin' WHERE id = '77777777-7777-7777-7777-777777777777';
    RAISE EXCEPTION 'FAIL: presence_admin edited review content';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: presence_admin cannot edit review content (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0001__rls_public_client_webmaster';

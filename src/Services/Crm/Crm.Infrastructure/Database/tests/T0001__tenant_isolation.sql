-- T0001__tenant_isolation.sql — structural completeness (every table in the catalogue has FORCE RLS) plus a
-- concrete attack on representative tables (plain, composite-FK, and partitioned).
\set ON_ERROR_STOP on
BEGIN;

-- Structural: every ordinary table in `public` must have RLS enabled AND forced. Catches "forgot to call
-- app.enable_tenant_rls on table N" without having to attack all 20 tables individually. Partitions are excluded
-- (RLS isn't inherited to them; they're protected by app.lock_partitions revoking privilege outright instead —
-- checked separately below).
DO $$
DECLARE v_missing text;
BEGIN
  SELECT string_agg(c.relname, ', ') INTO v_missing
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relispartition
    AND NOT (c.relrowsecurity AND c.relforcerowsecurity);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL: tables without FORCE RLS: %', v_missing;
  END IF;
  RAISE NOTICE 'PASS: every public table has FORCE ROW LEVEL SECURITY';
END $$;

-- biz_a = 11111111-1111-1111-1111-111111111111, biz_b = 22222222-2222-2222-2222-222222222222
-- contact_a = 33333333-3333-3333-3333-333333333333

SET ROLE crm_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO contacts (id, business_id, kind, full_name) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'person', 'Alice');
SELECT create_default_pipeline('11111111-1111-1111-1111-111111111111');
INSERT INTO opportunities (business_id, contact_id, pipeline_id, stage_id, status, title)
SELECT '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', p.id, s.id, 'open', 'Deal 1'
FROM pipelines p JOIN pipeline_stages s ON s.pipeline_id = p.id AND s.system_key = 'new'
WHERE p.business_id = '11111111-1111-1111-1111-111111111111' AND p.is_default;

SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM contacts WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s contact';
  END IF;
  IF EXISTS (SELECT 1 FROM opportunities WHERE title = 'Deal 1') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s opportunity';
  END IF;
END $$;

-- X3 regression: tenant B cannot attach a task to tenant A's contact by reusing its id.
DO $$ BEGIN
  BEGIN
    INSERT INTO tasks (business_id, contact_id, title) VALUES
      ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'steal');
    RAISE EXCEPTION 'FAIL: cross-tenant contact_id accepted into tasks';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS: composite FK rejects cross-tenant contact_id (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- Partitioned table (interactions): tenant isolation and direct-partition lockout.
SET ROLE crm_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO interactions (business_id, contact_id, type, summary) VALUES
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'note', 'first contact');
SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM interactions WHERE summary = 'first contact') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s interaction';
  END IF;
END $$;
DO $$
DECLARE v_part text;
BEGIN
  SELECT c.relname INTO v_part FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
   WHERE i.inhparent = 'interactions'::regclass AND c.relname NOT LIKE '%default' LIMIT 1;
  BEGIN
    EXECUTE format('SELECT 1 FROM %I', v_part);
    RAISE EXCEPTION 'FAIL: crm_app can read the interactions partition % directly', v_part;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: interactions partition % is locked (%)', v_part, SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0001__tenant_isolation';

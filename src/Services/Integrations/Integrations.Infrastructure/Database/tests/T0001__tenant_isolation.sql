-- T0001__tenant_isolation.sql — structural RLS completeness + composite-FK attack + partition lockout.
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE v_missing text;
BEGIN
  SELECT string_agg(c.relname, ', ') INTO v_missing
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relispartition
    AND c.relname NOT IN ('carriers', 'carrier_status_mapping_sets', 'carrier_status_mappings', 'carrier_geo_codes')
    AND NOT (c.relrowsecurity AND c.relforcerowsecurity);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL: tenant tables without FORCE RLS: %', v_missing;
  END IF;
  RAISE NOTICE 'PASS: every tenant table has FORCE ROW LEVEL SECURITY';
END $$;

SET ROLE integrations_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO integration_connections (id, business_id, kind, route_key) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'shopify', 'route-a');

SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM integration_connections WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s connection';
  END IF;
END $$;
DO $$ BEGIN
  BEGIN
    INSERT INTO external_refs (business_id, connection_id, entity_type, entity_id, external_id) VALUES
      ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'contact', gen_random_uuid(), 'shop-1');
    RAISE EXCEPTION 'FAIL: cross-tenant connection_id accepted into external_refs';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS: composite FK rejects cross-tenant connection_id (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- Pre-tenant route resolution works regardless of tenant setting (platform bridge, BYPASSRLS).
SELECT set_config('app.business_id', NULL, true);
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM resolve_webhook_connection_by_route('route-a');
  IF NOT FOUND OR r.business_id <> '11111111-1111-1111-1111-111111111111' THEN
    RAISE EXCEPTION 'FAIL: resolve_webhook_connection_by_route did not resolve with no tenant set';
  END IF;
  RAISE NOTICE 'PASS: resolve_webhook_connection_by_route resolves pre-tenant';
END $$;

SET ROLE integrations_app;
DO $$
DECLARE v_part text;
BEGIN
  SELECT c.relname INTO v_part FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
   WHERE i.inhparent = 'webhook_events'::regclass AND c.relname NOT LIKE '%default' LIMIT 1;
  BEGIN
    EXECUTE format('SELECT 1 FROM %I', v_part);
    RAISE EXCEPTION 'FAIL: integrations_app can read the webhook_events partition % directly', v_part;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: webhook_events partition % is locked (%)', v_part, SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0001__tenant_isolation';

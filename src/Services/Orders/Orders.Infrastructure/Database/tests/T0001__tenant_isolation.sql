-- T0001__tenant_isolation.sql — structural RLS completeness + a composite-FK attack.
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE v_missing text;
BEGIN
  SELECT string_agg(c.relname, ', ') INTO v_missing
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relispartition
    AND c.relname NOT IN ('order_status_transitions', 'return_reason_codes') -- platform read-only, no RLS by design
    AND NOT (c.relrowsecurity AND c.relforcerowsecurity);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL: tenant tables without FORCE RLS: %', v_missing;
  END IF;
  RAISE NOTICE 'PASS: every tenant table has FORCE ROW LEVEL SECURITY';
END $$;

-- biz_a = 11111111-1111-1111-1111-111111111111, biz_b = 22222222-2222-2222-2222-222222222222
SET ROLE orders_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO orders (id, business_id, order_seq, order_number, customer_name, phone_raw, phone_e164, phone_hash, status, cash_status)
VALUES ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 1, 'A-000001',
        'Alice', '0555000000', '+213555000000', decode(repeat('aa', 32), 'hex'), 'pending_confirmation', 'pending_collection');
INSERT INTO order_status_history (business_id, order_id, machine, from_status, to_status, source, order_version) VALUES
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'order', NULL, 'pending_confirmation', 'system', 1),
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'cash', NULL, 'pending_collection', 'system', 1);

SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM orders WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s order';
  END IF;
END $$;

DO $$ BEGIN
  BEGIN
    INSERT INTO order_items (business_id, order_id, qty, unit_price, line_total) VALUES
      ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 1, 100, 100);
    RAISE EXCEPTION 'FAIL: cross-tenant order_id accepted into order_items';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS: composite FK rejects cross-tenant order_id (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0001__tenant_isolation';

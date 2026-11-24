-- T0003__claim_and_mapping_freeze.sql — SECURITY DEFINER claim functions return ids+business_id only, work
-- cross-tenant, and never double-claim; carrier_status_mappings freeze once their set leaves draft.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE integrations_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO integration_connections (id, business_id, kind, route_key) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'shopify', 'route-a');
SELECT ingest_webhook_event('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
  'webhook', 'evt-1', 'provider', '{}'::jsonb, '{}'::jsonb);
RESET ROLE;

SET ROLE integrations_worker;
SELECT set_config('app.business_id', NULL, true); -- worker is cross-tenant by design
DO $$
DECLARE r record; v_count int := 0;
BEGIN
  FOR r IN SELECT * FROM claim_webhook_events(10) LOOP
    v_count := v_count + 1;
    IF r.business_id <> '11111111-1111-1111-1111-111111111111' THEN
      RAISE EXCEPTION 'FAIL: claim_webhook_events returned the wrong business_id';
    END IF;
  END LOOP;
  IF v_count <> 1 THEN RAISE EXCEPTION 'FAIL: expected to claim exactly 1 event, got %', v_count; END IF;
  RAISE NOTICE 'PASS: claim_webhook_events claimed the pending event cross-tenant';

  SELECT count(*) INTO v_count FROM claim_webhook_events(10);
  IF v_count <> 0 THEN RAISE EXCEPTION 'FAIL: the same event was claimed twice (lease not respected)'; END IF;
  RAISE NOTICE 'PASS: an already-leased event is not claimed again';
END $$;
RESET ROLE;

-- Mapping-set freeze: rows are editable while draft, frozen once activated.
SET ROLE integrations_migrator;
INSERT INTO carrier_status_mapping_sets (id, carrier_code, version, status) VALUES
  ('44444444-4444-4444-4444-444444444444', 'yalidine', 1, 'draft');
INSERT INTO carrier_status_mappings (set_id, raw_status, normalized_status) VALUES
  ('44444444-4444-4444-4444-444444444444', 'EN COURS', 'in_transit');
DO $$ BEGIN RAISE NOTICE 'PASS: mapping row insert allowed while set is draft'; END $$;

UPDATE carrier_status_mapping_sets SET status = 'active', activated_at = now() WHERE id = '44444444-4444-4444-4444-444444444444';
DO $$ BEGIN
  BEGIN
    UPDATE carrier_status_mappings SET normalized_status = 'delivered' WHERE set_id = '44444444-4444-4444-4444-444444444444';
    RAISE EXCEPTION 'FAIL: mapping row was editable after its set left draft';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: mapping rows are frozen once their set is active (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0003__claim_and_mapping_freeze';

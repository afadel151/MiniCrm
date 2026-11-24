-- T0002__ingest_dedup.sql — ingest_webhook_event dedup (D4/D5) and the D6 forged-signature/no-dedup-key path.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE integrations_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO integration_connections (id, business_id, kind, route_key) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'shopify', 'route-a');

DO $$
DECLARE v_id1 uuid; v_id2 uuid; v_count int;
BEGIN
  v_id1 := ingest_webhook_event('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
    'webhook', 'evt-1', 'provider', '{}'::jsonb, '{"order_id": 1}'::jsonb);
  IF v_id1 IS NULL THEN RAISE EXCEPTION 'FAIL: first ingest of evt-1 should succeed'; END IF;

  -- Redelivery of the same external_event_id must be dropped by the dedup key, not stored twice.
  v_id2 := ingest_webhook_event('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
    'webhook', 'evt-1', 'provider', '{}'::jsonb, '{"order_id": 1}'::jsonb);
  IF v_id2 IS NOT NULL THEN RAISE EXCEPTION 'FAIL: redelivery of evt-1 was not deduped'; END IF;

  SELECT count(*) INTO v_count FROM webhook_events WHERE external_event_id = 'evt-1';
  IF v_count <> 1 THEN RAISE EXCEPTION 'FAIL: evt-1 should be stored exactly once, got %', v_count; END IF;
  RAISE NOTICE 'PASS: webhook redelivery is deduped (webhook_event_keys), event stored once';
END $$;

-- D6: a forged/invalid-signature event is ignored and takes NO dedup key, so the genuine evt-2 can still arrive.
DO $$
DECLARE v_forged uuid; v_genuine uuid;
BEGIN
  v_forged := ingest_webhook_event('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
    'webhook', 'evt-2', 'provider', '{}'::jsonb, '{}'::jsonb, 'ignored', 'bad_signature', false);
  IF v_forged IS NULL THEN RAISE EXCEPTION 'FAIL: ignored event insert itself should not be blocked'; END IF;

  v_genuine := ingest_webhook_event('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
    'webhook', 'evt-2', 'provider', '{}'::jsonb, '{"real": true}'::jsonb);
  IF v_genuine IS NULL THEN
    RAISE EXCEPTION 'FAIL: the genuine evt-2 was blocked by the forged one''s non-existent dedup key';
  END IF;
  RAISE NOTICE 'PASS: a forged (ignored) event never occupies the genuine event''s dedup slot';
END $$;
RESET ROLE;

DO $$ BEGIN
  BEGIN
    PERFORM ingest_webhook_event('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333',
      'webhook', 'evt-3', 'provider', '{}'::jsonb, '{}'::jsonb);
    RAISE EXCEPTION 'FAIL: ingest_webhook_event worked for a mismatched tenant';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: ingest_webhook_event refuses a mismatched tenant (%)', SQLERRM;
  END;
END $$;

ROLLBACK;
SELECT 'PASS T0002__ingest_dedup';

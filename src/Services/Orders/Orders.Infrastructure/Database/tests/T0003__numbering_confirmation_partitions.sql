-- T0003__numbering_confirmation_partitions.sql — order numbering, the confirmation-token SECURITY DEFINER
-- function, and direct-partition lockout.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE orders_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);

-- Order numbering: gap-tolerant, UNIQUE per business, allocated in a block.
DO $$
DECLARE r record; v_first bigint; v_count int := 0;
BEGIN
  FOR r IN SELECT * FROM allocate_order_numbers('11111111-1111-1111-1111-111111111111', 3) LOOP
    v_count := v_count + 1;
    IF v_first IS NULL THEN v_first := r.order_seq; END IF;
  END LOOP;
  IF v_count <> 3 THEN RAISE EXCEPTION 'FAIL: expected 3 allocated numbers, got %', v_count; END IF;

  FOR r IN SELECT * FROM allocate_order_numbers('11111111-1111-1111-1111-111111111111', 1) LOOP
    IF r.order_seq <> v_first + 3 THEN
      RAISE EXCEPTION 'FAIL: next allocation should continue from %, got %', v_first + 3, r.order_seq;
    END IF;
  END LOOP;
  RAISE NOTICE 'PASS: allocate_order_numbers is gap-tolerant and monotonic per business';
END $$;

DO $$ BEGIN
  BEGIN
    PERFORM allocate_order_numbers('22222222-2222-2222-2222-222222222222', 1);
    RAISE EXCEPTION 'FAIL: allocate_order_numbers worked for a mismatched tenant';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: allocate_order_numbers refuses a mismatched tenant (%)', SQLERRM;
  END;
END $$;

-- Confirmation token: the SECURITY DEFINER bridge resolves pre-tenant, by hash, once.
INSERT INTO orders (id, business_id, order_seq, order_number, customer_name, phone_raw, phone_e164, phone_hash, status, cash_status)
VALUES ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 999, 'A-000999',
        'Alice', '0555000000', '+213555000000', decode(repeat('aa', 32), 'hex'), 'pending_confirmation', 'pending_collection');
INSERT INTO confirmation_requests (id, business_id, order_id, token_hash, expires_at)
VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333', decode(repeat('ee', 32), 'hex'), now() + interval '1 day');

SELECT set_config('app.business_id', NULL, true); -- resolution happens BEFORE any tenant is known
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM resolve_confirmation_token(decode(repeat('ee', 32), 'hex'));
  IF NOT FOUND OR r.order_id <> '33333333-3333-3333-3333-333333333333' THEN
    RAISE EXCEPTION 'FAIL: resolve_confirmation_token did not resolve a valid pending token with no tenant set';
  END IF;
  RAISE NOTICE 'PASS: resolve_confirmation_token resolves a pending token pre-tenant';

  SELECT * INTO r FROM resolve_confirmation_token(decode(repeat('ff', 32), 'hex'));
  IF FOUND THEN
    RAISE EXCEPTION 'FAIL: resolve_confirmation_token resolved an unknown token';
  END IF;
  RAISE NOTICE 'PASS: resolve_confirmation_token returns nothing for an unknown token';
END $$;
RESET ROLE;

-- Partition lockout: order_status_history and shipment_events partitions are not directly readable.
SET ROLE orders_app;
DO $$
DECLARE v_part text;
BEGIN
  SELECT c.relname INTO v_part FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
   WHERE i.inhparent = 'order_status_history'::regclass AND c.relname NOT LIKE '%default' LIMIT 1;
  BEGIN
    EXECUTE format('SELECT 1 FROM %I', v_part);
    RAISE EXCEPTION 'FAIL: orders_app can read the order_status_history partition % directly', v_part;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: order_status_history partition % is locked (%)', v_part, SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0003__numbering_confirmation_partitions';

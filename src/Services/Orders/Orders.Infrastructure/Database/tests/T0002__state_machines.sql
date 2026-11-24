-- T0002__state_machines.sql — order + cash machine guards: happy path, illegal edge, unlogged change, stale
-- version, override path, and the return-case machine.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE orders_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);

-- Happy path: an order is created at version 1 with BOTH machines logged in the same transaction.
INSERT INTO orders (id, business_id, order_seq, order_number, customer_name, phone_raw, phone_e164, phone_hash, status, cash_status)
VALUES ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 1, 'A-000001',
        'Alice', '0555000000', '+213555000000', decode(repeat('aa', 32), 'hex'), 'pending_confirmation', 'pending_collection');
INSERT INTO order_status_history (business_id, order_id, machine, from_status, to_status, source, order_version) VALUES
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'order', NULL, 'pending_confirmation', 'system', 1),
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'cash', NULL, 'pending_collection', 'system', 1);
SET CONSTRAINTS trg_orders_history_ins IMMEDIATE;
DO $$ BEGIN RAISE NOTICE 'PASS: order creation with both machines logged at version 1 committed'; END $$;

-- Illegal edge: pending_confirmation -> delivered is not a legal order-machine edge.
DO $$ BEGIN
  BEGIN
    INSERT INTO order_status_history (business_id, order_id, machine, from_status, to_status, source, order_version)
    VALUES ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'order', 'pending_confirmation', 'delivered', 'manual', 2);
    RAISE EXCEPTION 'FAIL: illegal edge pending_confirmation -> delivered was accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: trg_osh_validate rejects an illegal edge (%)', SQLERRM;
  END;
END $$;

-- Unlogged change: updating orders.status without a matching history row must fail at COMMIT (deferred).
SAVEPOINT sp1;
UPDATE orders SET status = 'confirmed', confirmation_status = 'confirmed', version = 2 WHERE id = '33333333-3333-3333-3333-333333333333';
DO $$ BEGIN
  BEGIN
    SET CONSTRAINTS trg_orders_history_upd IMMEDIATE;
    RAISE EXCEPTION 'FAIL: unlogged status change was accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: trg_orders_history_upd rejects an unlogged status change (%)', SQLERRM;
  END;
END $$;
ROLLBACK TO sp1;

-- Correct version: log first, then update — and a stale (non-incrementing) version is rejected by its own guard.
-- Only the order machine needs a row here: cash_status is not changing, and the guard only checks the machine(s)
-- whose value actually changes at this version.
INSERT INTO order_status_history (business_id, order_id, machine, from_status, to_status, source, order_version) VALUES
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'order', 'pending_confirmation', 'confirmed', 'manual', 2);
DO $$ BEGIN
  BEGIN
    UPDATE orders SET status = 'confirmed', confirmation_status = 'confirmed', version = 1 WHERE id = '33333333-3333-3333-3333-333333333333';
    RAISE EXCEPTION 'FAIL: non-incrementing version was accepted';
  EXCEPTION WHEN SQLSTATE '40001' THEN
    RAISE NOTICE 'PASS: trg_orders_version rejects a stale version (%)', SQLERRM;
  END;
END $$;
UPDATE orders SET status = 'confirmed', confirmation_status = 'confirmed', version = 2 WHERE id = '33333333-3333-3333-3333-333333333333';
SET CONSTRAINTS trg_orders_history_upd IMMEDIATE;
DO $$ BEGIN RAISE NOTICE 'PASS: logged status+version change committed'; END $$;

-- Override: skips the edge check but demands note + actor + source='manual'.
DO $$ BEGIN
  BEGIN
    INSERT INTO order_status_history (business_id, order_id, machine, from_status, to_status, source, order_version, is_override)
    VALUES ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'order', 'confirmed', 'cancelled', 'webhook', 3, true);
    RAISE EXCEPTION 'FAIL: override accepted without note/actor/source=manual';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: override requires note+actor+source=manual (%)', SQLERRM;
  END;
END $$;
INSERT INTO order_status_history (business_id, order_id, machine, from_status, to_status, source, order_version, is_override, note, actor_member_id)
VALUES ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'order', 'confirmed', 'cancelled', 'manual', 3, true, 'duplicate order, manual override', gen_random_uuid());
DO $$ BEGIN RAISE NOTICE 'PASS: a correctly-formed override is accepted even for a non-edge transition'; END $$;

-- Return-case machine: its own AFTER trigger validates + logs in one step.
INSERT INTO return_cases (id, business_id, order_id, reason_code, fault_class)
VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333', 'REFUSED_AT_DOOR', 'customer');
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM return_case_history WHERE return_case_id = '44444444-4444-4444-4444-444444444444' AND to_status = 'open') THEN
    RAISE EXCEPTION 'FAIL: return case creation was not logged';
  END IF;
END $$;
UPDATE return_cases SET status = 'received', received_at = now() WHERE id = '44444444-4444-4444-4444-444444444444'; -- "Mark received" (spec §5.7)
DO $$ BEGIN
  BEGIN
    UPDATE return_cases SET status = 'restocked', closed_at = now() WHERE id = '44444444-4444-4444-4444-444444444444'; -- received -> restocked, legal
    RAISE NOTICE 'PASS: return case legal edges accepted and logged';
  END;
END $$;
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM return_case_history WHERE return_case_id = '44444444-4444-4444-4444-444444444444';
  IF v_count < 3 THEN
    RAISE EXCEPTION 'FAIL: expected at least 3 return_case_history rows (open, received, restocked), got %', v_count;
  END IF;
  RAISE NOTICE 'PASS: return case history has % rows', v_count;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0002__state_machines';

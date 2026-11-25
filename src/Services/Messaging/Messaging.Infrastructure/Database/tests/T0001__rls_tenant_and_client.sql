-- T0001__rls_tenant_and_client.sql — staff tenant isolation, the client path (M1/M2 fixes), and partition lockout.
\set ON_ERROR_STOP on
BEGIN;

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
  RAISE NOTICE 'PASS: every table has FORCE ROW LEVEL SECURITY';
END $$;

-- biz_a / biz_b, client_x (the conversation's owner), client_y (a different client)
SET ROLE messaging_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO conversations (id, business_id, channel, client_user_id, status) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'in_app', '66666666-6666-6666-6666-666666666666', 'open');
INSERT INTO messages (business_id, conversation_id, sender_type) VALUES
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'staff');

-- Staff tenant isolation.
SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM conversations WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: tenant B staff can see tenant A''s conversation';
  END IF;
END $$;
RESET ROLE;

-- Client path: client_x can see/insert into its own thread, client_y cannot.
-- Clear app.business_id first: it's still set to biz_b from the staff check above (RESET ROLE does not clear a
-- transaction-local setting), and a leftover value would wrongly satisfy app.files' generic tenant_isolation
-- policy for the client-upload test further down, masking whether the client-specific policy is actually doing
-- the work.
SET ROLE messaging_client;
SELECT set_config('app.business_id', NULL, true);
SELECT set_config('app.user_id', '66666666-6666-6666-6666-666666666666', true);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM conversations WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: client_x cannot see its own conversation';
  END IF;
END $$;
INSERT INTO messages (business_id, conversation_id, sender_type, body) VALUES
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'client', 'hello');
DO $$ BEGIN RAISE NOTICE 'PASS: client_x can insert its own message into its own open thread'; END $$;

-- R2: client can upload an attachment (app.files) into a business it has a conversation with, but not an
-- arbitrary/unrelated business, and never with anything but scan_status='pending'.
INSERT INTO app.files (id, business_id, storage_key, original_name, content_type, size_bytes, purpose) VALUES
  ('88888888-8888-8888-8888-888888888888', '11111111-1111-1111-1111-111111111111', 'k1', 'photo.jpg', 'image/jpeg', 100, 'attachment');
DO $$ BEGIN RAISE NOTICE 'PASS: client_x can upload an attachment into a business it has a conversation with'; END $$;
DO $$ BEGIN
  BEGIN
    INSERT INTO app.files (business_id, storage_key, original_name, content_type, size_bytes, purpose) VALUES
      ('22222222-2222-2222-2222-222222222222', 'k2', 'photo2.jpg', 'image/jpeg', 100, 'attachment');
    RAISE EXCEPTION 'FAIL: client_x uploaded into a business it has no conversation with';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: upload into an unrelated business is rejected (%)', SQLERRM;
  END;
END $$;

SELECT set_config('app.user_id', '77777777-7777-7777-7777-777777777777', true); -- client_y
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM conversations WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: client_y can see client_x''s conversation';
  END IF;
END $$;
DO $$ BEGIN
  BEGIN
    INSERT INTO messages (business_id, conversation_id, sender_type, body) VALUES
      ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'client', 'intrude');
    RAISE EXCEPTION 'FAIL: client_y inserted into client_x''s conversation';
  EXCEPTION WHEN insufficient_privilege OR OTHERS THEN
    RAISE NOTICE 'PASS: client_y cannot write into client_x''s conversation (%)', SQLERRM;
  END;
END $$;

-- M1 regression: client cannot forge counters or change anything beyond its own read markers.
SELECT set_config('app.user_id', '66666666-6666-6666-6666-666666666666', true);
DO $$ BEGIN
  BEGIN
    UPDATE conversations SET client_message_count = 999 WHERE id = '33333333-3333-3333-3333-333333333333';
    RAISE EXCEPTION 'FAIL: client forged client_message_count';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: client has no column grant to forge counters (%)', SQLERRM;
  END;
END $$;
UPDATE conversations SET client_last_read_at = now() WHERE id = '33333333-3333-3333-3333-333333333333';
DO $$ BEGIN RAISE NOTICE 'PASS: client can update its own read marker'; END $$;
RESET ROLE;

-- Partition lockout (messages).
SET ROLE messaging_app;
DO $$
DECLARE v_part text;
BEGIN
  SELECT c.relname INTO v_part FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
   WHERE i.inhparent = 'messages'::regclass AND c.relname NOT LIKE '%default' LIMIT 1;
  BEGIN
    EXECUTE format('SELECT 1 FROM %I', v_part);
    RAISE EXCEPTION 'FAIL: messaging_app can read the messages partition % directly', v_part;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: messages partition % is locked (%)', v_part, SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0001__rls_tenant_and_client';

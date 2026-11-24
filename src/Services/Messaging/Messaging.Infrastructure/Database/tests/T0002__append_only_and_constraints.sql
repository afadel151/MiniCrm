-- T0002__append_only_and_constraints.sql — message redaction guard, consent version guard + sticky STOP.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE messaging_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO conversations (id, business_id, channel, client_user_id, status) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'in_app', '66666666-6666-6666-6666-666666666666', 'open');
INSERT INTO messages (id, business_id, conversation_id, sender_type, body, sent_at) VALUES
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333333', 'client', 'secret body', now());

DO $$ BEGIN
  BEGIN
    UPDATE messages SET body = 'tampered' WHERE id = '44444444-4444-4444-4444-444444444444';
    RAISE EXCEPTION 'FAIL: message body was rewritten to a non-NULL value';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: guard_message_redaction rejects a non-NULL body rewrite (%)', SQLERRM;
  END;
END $$;

UPDATE messages SET body = NULL, redacted_at = now() WHERE id = '44444444-4444-4444-4444-444444444444';
DO $$ BEGIN RAISE NOTICE 'PASS: redaction to NULL with redacted_at set is accepted'; END $$;

DO $$ BEGIN
  BEGIN
    UPDATE messages SET body = 'resurrected' WHERE id = '44444444-4444-4444-4444-444444444444';
    RAISE EXCEPTION 'FAIL: a second redaction-path change was accepted (should be irreversible/once only)';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: redaction is irreversible — a second body change is rejected (%)', SQLERRM;
  END;
END $$;

DO $$ BEGIN
  BEGIN
    DELETE FROM messages WHERE id = '44444444-4444-4444-4444-444444444444';
    RAISE EXCEPTION 'FAIL: messages row was deleted (append-only)';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: messages has no DELETE grant for messaging_app (%)', SQLERRM;
  END;
END $$;

-- Consent: version guard + sticky STOP (S6-style: withdrawal wins over a later "granted" event).
INSERT INTO channel_consent_states (business_id, phone_hash, channel, purpose, decision, source_version) VALUES
  ('11111111-1111-1111-1111-111111111111', decode(repeat('aa', 32), 'hex'), 'whatsapp', 'marketing', 'granted', 1);
UPDATE channel_consent_states SET decision = 'withdrawn', stop_received_at = now(), source_version = 2
 WHERE business_id = '11111111-1111-1111-1111-111111111111' AND phone_hash = decode(repeat('aa', 32), 'hex')
   AND channel = 'whatsapp' AND purpose = 'marketing';
UPDATE channel_consent_states SET decision = 'granted', source_version = 3
 WHERE business_id = '11111111-1111-1111-1111-111111111111' AND phone_hash = decode(repeat('aa', 32), 'hex')
   AND channel = 'whatsapp' AND purpose = 'marketing';
DO $$
DECLARE v_decision text;
BEGIN
  SELECT decision INTO v_decision FROM channel_consent_states
   WHERE business_id = '11111111-1111-1111-1111-111111111111' AND phone_hash = decode(repeat('aa', 32), 'hex')
     AND channel = 'whatsapp' AND purpose = 'marketing';
  IF v_decision <> 'withdrawn' THEN
    RAISE EXCEPTION 'FAIL: a later granted event overrode a sticky STOP, decision = %', v_decision;
  END IF;
  RAISE NOTICE 'PASS: sticky STOP keeps the number withdrawn even after a later "granted" event';
END $$;
DO $$ BEGIN
  BEGIN
    UPDATE channel_consent_states SET source_version = 2
     WHERE business_id = '11111111-1111-1111-1111-111111111111' AND phone_hash = decode(repeat('aa', 32), 'hex')
       AND channel = 'whatsapp' AND purpose = 'marketing';
    RAISE EXCEPTION 'FAIL: a stale consent version was accepted';
  EXCEPTION WHEN SQLSTATE '40001' THEN
    RAISE NOTICE 'PASS: trg_consent_version rejects a stale version (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0002__append_only_and_constraints';

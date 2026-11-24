-- T0002__rules_and_helpers.sql — declarative state rules, score-cache layer lock, and the helper functions.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE crm_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO contacts (id, business_id, kind, full_name) VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'person', 'Alice');
SELECT create_default_pipeline('11111111-1111-1111-1111-111111111111');

-- Opportunity rule: status must match the stage's type (declarative composite FK), and the CHECK on won/lost
-- timestamps + lost_reason.
DO $$
DECLARE v_pipeline uuid; v_open_stage uuid; v_won_stage uuid;
BEGIN
  SELECT id INTO v_pipeline FROM pipelines WHERE business_id = '11111111-1111-1111-1111-111111111111' AND is_default;
  SELECT id INTO v_open_stage FROM pipeline_stages WHERE pipeline_id = v_pipeline AND system_key = 'new';
  SELECT id INTO v_won_stage FROM pipeline_stages WHERE pipeline_id = v_pipeline AND system_key = 'won';

  BEGIN
    INSERT INTO opportunities (business_id, contact_id, pipeline_id, stage_id, status, title)
    VALUES ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', v_pipeline, v_won_stage, 'open', 'bad');
    RAISE EXCEPTION 'FAIL: status=open accepted against a won-type stage';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS: declarative stage-type FK rejects status/stage-type mismatch (%)', SQLERRM;
  END;

  BEGIN
    INSERT INTO opportunities (business_id, contact_id, pipeline_id, stage_id, status, title, won_at)
    VALUES ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', v_pipeline, v_open_stage, 'open', 'bad2', now());
    RAISE EXCEPTION 'FAIL: open status accepted with won_at set';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: ck_opportunities_state rejects open+won_at (%)', SQLERRM;
  END;
END $$;

-- Score cache: layer is structurally pinned to 'tenant'; a global row can never be inserted.
DO $$ BEGIN
  BEGIN
    INSERT INTO contact_score_cache (business_id, phone_hash, layer, tier, confidence, source_version)
    VALUES ('11111111-1111-1111-1111-111111111111', decode(repeat('aa', 32), 'hex'), 'global', 'B', 'high', 1);
    RAISE EXCEPTION 'FAIL: layer=global accepted into contact_score_cache';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: contact_score_cache.layer is structurally pinned to tenant (%)', SQLERRM;
  END;
END $$;

-- Call rule: disposition='answered' requires outcome+answered_at, and vice versa.
INSERT INTO call_attempt_groups (id, business_id, contact_id, purpose) VALUES
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'confirmation');
DO $$
DECLARE v_n int;
BEGIN
  v_n := next_call_attempt_no('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444');
  IF v_n <> 1 THEN RAISE EXCEPTION 'FAIL: first attempt_no should be 1, got %', v_n; END IF;
  v_n := next_call_attempt_no('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444');
  IF v_n <> 2 THEN RAISE EXCEPTION 'FAIL: second attempt_no should be 2, got %', v_n; END IF;
  RAISE NOTICE 'PASS: next_call_attempt_no increments under a row lock';

  BEGIN
    INSERT INTO interactions (id, business_id, type, occurred_at) VALUES
      ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'call', now());
    INSERT INTO call_logs (interaction_id, occurred_at, business_id, attempt_group_id, attempt_no, phone_hash, disposition)
    VALUES ('55555555-5555-5555-5555-555555555555', now(), '11111111-1111-1111-1111-111111111111',
            '44444444-4444-4444-4444-444444444444', 1, decode(repeat('bb', 32), 'hex'), 'answered');
    RAISE EXCEPTION 'FAIL: disposition=answered accepted without outcome/answered_at';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: call rule rejects answered without outcome+answered_at (%)', SQLERRM;
  END;
END $$;

-- erase_contact: structural erasure end to end.
INSERT INTO contact_phones (business_id, contact_id, phone_raw, phone_e164, phone_hash) VALUES
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', '0555000000', '+213555000000', decode(repeat('cc', 32), 'hex'));
SELECT erase_contact('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', NULL, 'owner request');
DO $$
DECLARE r contacts;
BEGIN
  SELECT * INTO r FROM contacts WHERE id = '33333333-3333-3333-3333-333333333333';
  IF r.full_name IS NOT NULL OR r.anonymised_at IS NULL THEN
    RAISE EXCEPTION 'FAIL: erase_contact did not anonymise the contact';
  END IF;
  IF EXISTS (SELECT 1 FROM contact_phones WHERE contact_id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: erase_contact left a phone behind';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM contact_erasures WHERE contact_id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: erase_contact did not record contact_erasures';
  END IF;
  RAISE NOTICE 'PASS: erase_contact anonymised the contact and deleted its phone';
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0002__rules_and_helpers';

-- T0003__lookup_and_otp_flow.sql — functional test of public.lookup_score's abuse gates and the OTP self-view
-- flow, against real data (not just grants). Literal UUIDs/hashes throughout.
\set ON_ERROR_STOP on
BEGIN;

-- Fixture: one phone identity, one epoch, one business known_phones row (order old enough to qualify).
SET ROLE scoring_engine;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO net.phone_identities (id, phone_hash, pepper_version)
VALUES ('44444444-4444-4444-4444-444444444444', decode(repeat('ee', 32), 'hex'), 1);
INSERT INTO net.phone_epochs (phone_identity_id, epoch, reason, started_at)
VALUES ('44444444-4444-4444-4444-444444444444', 1, 'initial', now() - interval '60 days');
INSERT INTO public.known_phones (id, business_id, phone_hash, has_order, last_seen_at, created_at)
VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111',
        decode(repeat('ee', 32), 'hex'), true, now(), now() - interval '48 hours');
RESET ROLE;

SET ROLE scoring_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);

-- 1. No consent yet -> refused_consent, surfaced to the caller as not_enough_data.
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM public.lookup_score(decode(repeat('ee', 32), 'hex'));
  IF r.band <> 'not_enough_data' OR r.confidence <> 'not_enough_data' THEN
    RAISE EXCEPTION 'FAIL: expected not_enough_data before consent, got %/%', r.band, r.confidence;
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.score_lookups WHERE result = 'refused_consent') THEN
    RAISE EXCEPTION 'FAIL: refused_consent was not recorded in the audit trail';
  END IF;
END $$;
RESET ROLE;

-- 2. Grant consent, but k-gate still fails (0 eligible contributors besides the requester).
SET ROLE scoring_engine;
SELECT set_config('app.business_id', NULL, true);
INSERT INTO net.consents (phone_identity_id, purpose, decision, seq, wording_text, wording_sha256)
VALUES ('44444444-4444-4444-4444-444444444444', 'global_scoring', 'granted', 1, 'v1 wording', digest('v1 wording', 'sha256'));
RESET ROLE;

SET ROLE scoring_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM public.lookup_score(decode(repeat('ee', 32), 'hex'));
  IF r.band <> 'not_enough_data' THEN
    RAISE EXCEPTION 'FAIL: expected refusal before the k-gate is satisfied, got %', r.band;
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.score_lookups WHERE result = 'refused_k_gate') THEN
    RAISE EXCEPTION 'FAIL: refused_k_gate was not recorded';
  END IF;
END $$;
RESET ROLE;

-- 3. Satisfy k (min_contributors_k = 3, seeded), compute a global score -> now scored.
SET ROLE scoring_engine;
SELECT set_config('app.business_id', NULL, true);
INSERT INTO net.phone_contributors (phone_identity_id, phone_epoch, business_id, eligible_at) VALUES
  ('44444444-4444-4444-4444-444444444444', 1, '66666666-6666-6666-6666-666666666666', now() - interval '1 day'),
  ('44444444-4444-4444-4444-444444444444', 1, '77777777-7777-7777-7777-777777777777', now() - interval '1 day'),
  ('44444444-4444-4444-4444-444444444444', 1, '88888888-8888-8888-8888-888888888888', now() - interval '1 day');
INSERT INTO net.global_scores (phone_identity_id, phone_epoch, band, confidence, effective_n, model_version)
VALUES ('44444444-4444-4444-4444-444444444444', 1, 'B', 'high', 5, '1.0');
RESET ROLE;

SET ROLE scoring_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM public.lookup_score(decode(repeat('ee', 32), 'hex'));
  IF r.band <> 'B' OR r.confidence <> 'high' OR r.model_version <> '1.0' THEN
    RAISE EXCEPTION 'FAIL: expected B/high/1.0 once every gate is satisfied, got %/%/%', r.band, r.confidence, r.model_version;
  END IF;
  RAISE NOTICE 'PASS: lookup_score returns the band once all gates pass';
END $$;
RESET ROLE;

-- 4. S4/S7 regression: global_scores cannot be updated once frozen, and a stale version write is rejected.
SET ROLE scoring_engine;
SELECT set_config('app.business_id', NULL, true);
UPDATE net.global_scores SET frozen_until = now() + interval '1 day', version = version + 1 WHERE phone_identity_id = '44444444-4444-4444-4444-444444444444';
DO $$ BEGIN
  BEGIN
    UPDATE net.global_scores SET band = 'D', version = 99 WHERE phone_identity_id = '44444444-4444-4444-4444-444444444444';
    RAISE EXCEPTION 'FAIL: frozen global_scores row was updated';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: trg_dispute_freeze rejects a band change while frozen (%)', SQLERRM;
  END;
END $$;
DO $$ BEGIN
  BEGIN
    UPDATE net.global_scores SET version = 1 WHERE phone_identity_id = '44444444-4444-4444-4444-444444444444'; -- same version, no band change
    RAISE EXCEPTION 'FAIL: stale/non-incrementing version write was accepted';
  EXCEPTION WHEN SQLSTATE '40001' THEN
    RAISE NOTICE 'PASS: trg_global_scores_version rejects a non-incrementing version (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- 5. OTP self-view flow, end to end, as scoring_portal.
SET ROLE scoring_portal;
DO $$
DECLARE v_verification_id uuid; v_token bytea; v_otp_hash bytea := digest('123456', 'sha256'); v_rows int;
BEGIN
  SELECT public.owner_start_verification(decode(repeat('ee', 32), 'hex'), v_otp_hash, 1) INTO v_verification_id;

  BEGIN
    PERFORM public.owner_submit_otp(v_verification_id, digest('000000', 'sha256'));
    RAISE EXCEPTION 'FAIL: wrong OTP accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: wrong OTP rejected (%)', SQLERRM;
  END;

  SELECT public.owner_submit_otp(v_verification_id, v_otp_hash) INTO v_token;
  IF v_token IS NULL OR octet_length(v_token) <> 32 THEN
    RAISE EXCEPTION 'FAIL: owner_submit_otp did not return a 256-bit session token';
  END IF;

  SELECT count(*) INTO v_rows FROM public.owner_view_score(v_verification_id, v_token);
  RAISE NOTICE 'PASS: OTP flow completed, owner_view_score returned % month row(s)', v_rows;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0003__lookup_and_otp_flow';

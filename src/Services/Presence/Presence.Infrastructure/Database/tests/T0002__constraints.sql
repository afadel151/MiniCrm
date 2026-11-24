-- T0002__constraints.sql — rating aggregate maintenance, source_version guards, reports anti-spam unique.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE presence_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO business_profiles (business_id, name, slug, is_published) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Biz A', 'biz-a', true);
RESET ROLE;

SET ROLE presence_worker;
SELECT set_config('app.business_id', NULL, true);
INSERT INTO client_verified_phones (user_id, phone_hash, source_version) VALUES
  ('66666666-6666-6666-6666-666666666666', decode(repeat('aa', 32), 'hex'), 1);
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO review_eligibility (business_id, basis, interaction_id, phone_hash, source_version) VALUES
  ('11111111-1111-1111-1111-111111111111', 'order', '55555555-5555-5555-5555-555555555555', decode(repeat('aa', 32), 'hex'), 1);
RESET ROLE;

-- Rating aggregate is trigger-maintained; staff has no write path to it at all.
SET ROLE presence_client;
SELECT set_config('app.user_id', '66666666-6666-6666-6666-666666666666', true);
INSERT INTO reviews (id, business_id, author_user_id, author_display_name, basis, interaction_id, rating)
VALUES ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111',
        '66666666-6666-6666-6666-666666666666', 'Alice', 'order', '55555555-5555-5555-5555-555555555555', 4);
RESET ROLE;
DO $$
DECLARE r record;
BEGIN
  SELECT rating_sum, rating_count INTO r FROM business_profiles WHERE business_id = '11111111-1111-1111-1111-111111111111';
  IF r.rating_sum <> 4 OR r.rating_count <> 1 THEN
    RAISE EXCEPTION 'FAIL: rating aggregate not updated by trg_reviews_maintain_rating, got sum=% count=%', r.rating_sum, r.rating_count;
  END IF;
  RAISE NOTICE 'PASS: rating aggregate maintained by trigger on insert';
END $$;

SET ROLE presence_admin;
UPDATE reviews SET status = 'hidden' WHERE id = '77777777-7777-7777-7777-777777777777';
RESET ROLE;
DO $$
DECLARE r record;
BEGIN
  SELECT rating_sum, rating_count INTO r FROM business_profiles WHERE business_id = '11111111-1111-1111-1111-111111111111';
  IF r.rating_sum <> 0 OR r.rating_count <> 0 THEN
    RAISE EXCEPTION 'FAIL: hiding a review did not retract it from the rating aggregate, sum=% count=%', r.rating_sum, r.rating_count;
  END IF;
  RAISE NOTICE 'PASS: hiding a review retracts it from the rating aggregate';
END $$;

-- source_version guard on the read models.
SET ROLE presence_worker;
SELECT set_config('app.business_id', NULL, true);
DO $$ BEGIN
  BEGIN
    UPDATE client_verified_phones SET source_version = 1 WHERE user_id = '66666666-6666-6666-6666-666666666666';
    RAISE EXCEPTION 'FAIL: a non-incrementing source_version was accepted on client_verified_phones';
  EXCEPTION WHEN SQLSTATE '40001' THEN
    RAISE NOTICE 'PASS: client_verified_phones rejects a stale source_version (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- Reports: anti-spam one-open-report-per-reporter-per-target.
SET ROLE presence_client;
SELECT set_config('app.user_id', '88888888-8888-8888-8888-888888888888', true);
INSERT INTO reports (target_type, review_id, target_business_id, reporter_user_id, reason)
VALUES ('review', '77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111',
        '88888888-8888-8888-8888-888888888888', 'offensive');
DO $$ BEGIN
  BEGIN
    INSERT INTO reports (target_type, review_id, target_business_id, reporter_user_id, reason)
    VALUES ('review', '77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111',
            '88888888-8888-8888-8888-888888888888', 'again');
    RAISE EXCEPTION 'FAIL: a second open report from the same reporter/target was accepted';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS: ux_reports_open_per_reporter blocks a duplicate open report (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0002__constraints';

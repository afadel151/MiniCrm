-- T0003__role_matrix.sql — column-grant restrictions (I1/I2) and the admin-only feature-flag path.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE identity_access_app;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO users (id, email, email_normalized, full_name) VALUES
  ('99999999-9999-9999-9999-999999999999', 'a@example.com', 'a@example.com', 'Alice');
INSERT INTO businesses (id, name, slug, created_by) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Biz A', 'biz-a', '99999999-9999-9999-9999-999999999999');

DO $$ BEGIN
  BEGIN
    UPDATE users SET platform_role = 'web_master' WHERE id = '99999999-9999-9999-9999-999999999999';
    RAISE EXCEPTION 'FAIL: identity_access_app can grant itself platform_role';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: identity_access_app cannot write users.platform_role (%)', SQLERRM;
  END;
END $$;

DO $$ BEGIN
  BEGIN
    UPDATE businesses SET trust_weight = 0.01 WHERE id = '11111111-1111-1111-1111-111111111111';
    RAISE EXCEPTION 'FAIL: identity_access_app can write trust_weight';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: identity_access_app cannot write businesses.trust_weight (%)', SQLERRM;
  END;
END $$;

DO $$ BEGIN
  BEGIN
    INSERT INTO feature_flags (key, business_id, enabled) VALUES ('x', NULL, true);
    RAISE EXCEPTION 'FAIL: identity_access_app can write feature_flags directly';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: identity_access_app cannot write feature_flags directly (%)', SQLERRM;
  END;
END $$;

DO $$ BEGIN
  BEGIN
    PERFORM set_feature_flag('global_score_visible', NULL, true, '99999999-9999-9999-9999-999999999999');
    RAISE EXCEPTION 'FAIL: identity_access_app can call set_feature_flag';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: identity_access_app cannot call set_feature_flag (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- Non-web_master actor is rejected by the function's own check, not just by the grant.
INSERT INTO users (id, email, email_normalized, full_name) VALUES
  ('77777777-7777-7777-7777-777777777777', 'notadmin@example.com', 'notadmin@example.com', 'Not Admin');
SET ROLE identity_access_admin;
DO $$ BEGIN
  BEGIN
    PERFORM set_feature_flag('global_score_visible', NULL, true, '77777777-7777-7777-7777-777777777777');
    RAISE EXCEPTION 'FAIL: set_feature_flag accepted a non-web_master actor';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: set_feature_flag rejects a non-web_master actor (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- A real web_master actor succeeds and the trigger emits the outbox event.
UPDATE users SET platform_role = 'web_master' WHERE id = '77777777-7777-7777-7777-777777777777';
SET ROLE identity_access_admin;
SELECT set_feature_flag('global_score_visible', NULL, true, '77777777-7777-7777-7777-777777777777');
RESET ROLE;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM app.outbox WHERE event_type = 'identity.feature_flag.changed') THEN
    RAISE EXCEPTION 'FAIL: set_feature_flag did not emit identity.feature_flag.changed';
  END IF;
  RAISE NOTICE 'PASS: set_feature_flag by a real web_master emitted the outbox event';
END $$;

ROLLBACK;
SELECT 'PASS T0003__role_matrix';

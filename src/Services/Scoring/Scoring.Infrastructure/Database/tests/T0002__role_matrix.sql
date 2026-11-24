-- T0002__role_matrix.sql — asserts the allowed/refused operations for scoring_app, scoring_engine, scoring_portal,
-- scoring_admin (fix-brief validation requirement). Literal UUIDs throughout (see T0001 for why).
\set ON_ERROR_STOP on
BEGIN;

-- S9: scoring_app has no USAGE on net at all, so even a fully-qualified reference fails to resolve.
SET ROLE scoring_app;
DO $$ BEGIN
  BEGIN
    PERFORM * FROM net.phone_identities LIMIT 1;
    RAISE EXCEPTION 'FAIL: scoring_app can read net.phone_identities';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_app has no access to schema net (%)', SQLERRM;
  END;
END $$;
DO $$ BEGIN
  BEGIN
    INSERT INTO public.known_phones (business_id, phone_hash) VALUES (gen_random_uuid(), decode(repeat('bb', 32), 'hex'));
    RAISE EXCEPTION 'FAIL: scoring_app can write known_phones directly';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_app cannot write known_phones directly (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- scoring_portal has no table grants anywhere — only EXECUTE on the 5 owner_* functions.
SET ROLE scoring_portal;
DO $$ BEGIN
  BEGIN
    PERFORM * FROM net.owner_verifications LIMIT 1;
    RAISE EXCEPTION 'FAIL: scoring_portal can read net.owner_verifications directly';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_portal has no direct table access (%)', SQLERRM;
  END;
END $$;
DO $$ BEGIN
  BEGIN
    PERFORM public.lookup_score(decode(repeat('cc', 32), 'hex'));
    RAISE EXCEPTION 'FAIL: scoring_portal can call lookup_score';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_portal cannot call lookup_score (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- scoring_app cannot call the owner_* functions either (S9: separate role from the portal).
SET ROLE scoring_app;
DO $$ BEGIN
  BEGIN
    PERFORM public.owner_start_verification(decode(repeat('cc', 32), 'hex'), decode(repeat('dd', 32), 'hex'), 1);
    RAISE EXCEPTION 'FAIL: scoring_app can call owner_start_verification';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_app cannot call owner_start_verification (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- scoring_engine: explicit net grants work (SELECT on pepper_versions; rotation itself is admin-only via
-- net.admin_rotate_pepper, so engine must NOT have INSERT/UPDATE there).
SET ROLE scoring_engine;
SELECT set_config('app.business_id', NULL, true);
DO $$ BEGIN
  PERFORM * FROM net.pepper_versions LIMIT 1; -- sanity: engine can read net tables it was explicitly granted
EXCEPTION WHEN insufficient_privilege THEN
  RAISE EXCEPTION 'FAIL: scoring_engine should have SELECT on net.pepper_versions: %', SQLERRM;
END $$;
DO $$ BEGIN
  BEGIN
    INSERT INTO net.pepper_versions (version, status) VALUES (999, 'retired');
    RAISE EXCEPTION 'FAIL: scoring_engine can rotate the pepper directly (should be admin-only)';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_engine cannot write net.pepper_versions (%)', SQLERRM;
  END;
END $$;
-- Append-only regression: engine cannot UPDATE a disallowed column, and cannot DELETE outside an erasure.
DO $$ BEGIN
  BEGIN
    UPDATE net.consents SET wording_text = 'tampered' WHERE false;
    RAISE EXCEPTION 'FAIL: scoring_engine has UPDATE on append-only net.consents';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_engine cannot UPDATE net.consents (%)', SQLERRM;
  END;
END $$;
DO $$ BEGIN
  BEGIN
    DELETE FROM net.consents WHERE false;
    RAISE EXCEPTION 'FAIL: scoring_engine has a DELETE grant on net.consents (it should only ever delete via net.erase_phone, which runs as the migrator)';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_engine has no direct DELETE grant on net.consents (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

-- scoring_admin: no raw UPDATE on the state-machine tables (disputes, DSR) — only through admin_* functions.
SET ROLE scoring_admin;
DO $$ BEGIN
  BEGIN
    UPDATE net.disputes SET status = 'upheld' WHERE false;
    RAISE EXCEPTION 'FAIL: scoring_admin has raw UPDATE on net.disputes';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: scoring_admin has no raw UPDATE on net.disputes (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0002__role_matrix';

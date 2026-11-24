-- T0004__platform_tables_readonly.sql — carriers/mapping/geo tables: runtime roles may only SELECT.
\set ON_ERROR_STOP on
BEGIN;

SET ROLE integrations_app;
DO $$ BEGIN
  BEGIN
    INSERT INTO carriers (code, name, api_family) VALUES ('fake', 'Fake Carrier', 'fake');
    RAISE EXCEPTION 'FAIL: integrations_app can write carriers';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: integrations_app cannot write carriers (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

SET ROLE integrations_worker;
DO $$ BEGIN
  BEGIN
    UPDATE carriers SET status = 'disabled' WHERE code = 'yalidine';
    RAISE EXCEPTION 'FAIL: integrations_worker can write carriers';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'PASS: integrations_worker cannot write carriers (%)', SQLERRM;
  END;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM carriers WHERE code = 'yalidine') THEN
    RAISE EXCEPTION 'FAIL: integrations_worker cannot even SELECT carriers';
  END IF;
  RAISE NOTICE 'PASS: integrations_worker can SELECT carriers';
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0004__platform_tables_readonly';

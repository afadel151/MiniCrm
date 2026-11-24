-- T0001__tenant_isolation.sql — run as superuser (bootstrap script); SET ROLE before every tenant check since
-- superusers BYPASS RLS and would pass for the wrong reason otherwise.
-- (plain literals throughout, not psql variables: psql does not interpolate :vars inside $$...$$ bodies)
\set ON_ERROR_STOP on
BEGIN;

-- biz_a = 11111111-1111-1111-1111-111111111111, biz_b = 22222222-2222-2222-2222-222222222222
-- known_phones row = 33333333-3333-3333-3333-333333333333

-- Even the engine is FORCE RLS-governed by tenant_isolation (NOBYPASSRLS): it sets the tenant from whichever
-- event it is currently processing, one tenant at a time — it is not a blanket exemption from RLS.
SET ROLE scoring_engine;
SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
INSERT INTO public.known_phones (id, business_id, phone_hash, has_order, created_at)
VALUES ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111',
        decode(repeat('aa', 32), 'hex'), true, now() - interval '2 days');
RESET ROLE;

SET ROLE scoring_app;
SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.known_phones WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: tenant B can see tenant A''s known_phones row';
  END IF;
END $$;

SELECT set_config('app.business_id', '11111111-1111-1111-1111-111111111111', true);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.known_phones WHERE id = '33333333-3333-3333-3333-333333333333') THEN
    RAISE EXCEPTION 'FAIL: tenant A cannot see its own known_phones row';
  END IF;
END $$;

SELECT set_config('app.business_id', NULL, true);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.known_phones) THEN
    RAISE EXCEPTION 'FAIL: unset tenant context must see zero rows (fail closed)';
  END IF;
END $$;
RESET ROLE;

-- X3 regression: tenant B cannot attach a tenant_scores row to tenant A's known_phones row by reusing its id.
SET ROLE scoring_engine;
SELECT set_config('app.business_id', '22222222-2222-2222-2222-222222222222', true);
DO $$ BEGIN
  BEGIN
    INSERT INTO public.tenant_scores (known_phone_id, business_id, tier, confidence, model_version)
    VALUES ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'A', 'none', '1.0');
    RAISE EXCEPTION 'FAIL: cross-tenant known_phone_id accepted into tenant_scores';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS: composite FK rejects cross-tenant known_phone_id (%)', SQLERRM;
  END;
END $$;
RESET ROLE;

ROLLBACK;
SELECT 'PASS T0001__tenant_isolation';

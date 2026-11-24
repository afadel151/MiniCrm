-- C0001__app_base.sql — core helpers shared by every service database (ADR-0003, ADR-0006).
-- Applied once per database, as <db>_migrator, before any service migration.
--
-- Role matrix set up by this file (ADR-0006; schema `public` default privileges only — schema `app` has NONE,
-- its grants are explicit per table in C0002 and in each service migration):
--   <db>_migrator  owner of schema public and every app.* object; BYPASSRLS; migration job only.
--   <db>_app       default privileges on public: SELECT/INSERT/UPDATE/DELETE on tables, USAGE/SELECT on sequences,
--                  EXECUTE on functions. USAGE on schema app (no blanket grant on app.* tables).
--   <db>_worker    same default privileges on public as _app (consumers/relay/jobs act on domain tables too).
--   <db>_admin     NOTHING by default on public or app — every admin power is an explicit grant in the service
--                  migration (web-master console actions only).
--   <db>_<extra>   roles declared in Database/roles.conf get NOTHING by default; the service migration grants
--                  exactly what that role needs.

CREATE SCHEMA IF NOT EXISTS app;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Tenant context (settings only NARROW; they never grant a power — ADR-0006 rule 2)
-- ---------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.current_business_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN current_setting('app.business_id', true) IS NULL OR current_setting('app.business_id', true) = ''
      THEN NULL
    ELSE current_setting('app.business_id', true)::uuid
  END
$$;

CREATE OR REPLACE FUNCTION app.current_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN current_setting('app.user_id', true) IS NULL OR current_setting('app.user_id', true) = ''
      THEN NULL
    ELSE current_setting('app.user_id', true)::uuid
  END
$$;

-- Fail closed: unset tenant => NULL => tenant_isolation policy matches no rows.
CREATE OR REPLACE FUNCTION app.enable_tenant_rls(p_table regclass) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', p_table);
  EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY', p_table);
  EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %s', p_table);
  EXECUTE format(
    'CREATE POLICY tenant_isolation ON %s USING (business_id = app.current_business_id()) WITH CHECK (business_id = app.current_business_id())',
    p_table);
END;
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. updated_at
-- ---------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION app.add_updated_at_trigger(p_table regclass) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('DROP TRIGGER IF EXISTS trg_set_updated_at ON %s', p_table);
  EXECUTE format(
    'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION app.set_updated_at()',
    p_table);
END;
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Append-only (privilege revoke + trigger — two layers, per ADR-0003; blocks TRUNCATE too, X5 fix)
-- ---------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.guard_append_only_block() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'append-only: % not permitted on %', TG_OP, TG_TABLE_NAME USING ERRCODE = '55000';
END;
$$;

-- Row-level: compares OLD/NEW after removing the whitelisted columns from both sides; any other change is rejected.
CREATE OR REPLACE FUNCTION app.guard_append_only_update() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  old_j jsonb := to_jsonb(OLD);
  new_j jsonb := to_jsonb(NEW);
  i int;
BEGIN
  FOR i IN 0 .. TG_NARGS - 1 LOOP
    old_j := old_j - TG_ARGV[i];
    new_j := new_j - TG_ARGV[i];
  END LOOP;
  IF old_j IS DISTINCT FROM new_j THEN
    RAISE EXCEPTION 'append-only: only % may change on %', TG_ARGV, TG_TABLE_NAME USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;

-- p_allowed_update_columns: columns that MAY change on UPDATE (e.g. phone_signals.is_valid). Pass '{}' to block
-- UPDATE entirely. Revokes DELETE/UPDATE/TRUNCATE from PUBLIC and the three standard roles; whitelisted columns
-- are granted back to _app and _worker only (fix-brief: never to _admin or extra roles by this call — grant those
-- explicitly in the service migration if a console action genuinely needs it).
CREATE OR REPLACE FUNCTION app.make_append_only(p_table regclass, p_allowed_update_columns text[] DEFAULT '{}')
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  db text := current_database();
  args text;
BEGIN
  EXECUTE format('REVOKE DELETE, TRUNCATE, UPDATE ON %s FROM PUBLIC, %I, %I, %I',
    p_table, db || '_app', db || '_worker', db || '_admin');

  IF array_length(p_allowed_update_columns, 1) > 0 THEN
    EXECUTE format('GRANT UPDATE (%s) ON %s TO %I, %I',
      array_to_string(p_allowed_update_columns, ', '), p_table, db || '_app', db || '_worker');
  END IF;

  EXECUTE format('DROP TRIGGER IF EXISTS trg_append_only_block_delete ON %s', p_table);
  EXECUTE format(
    'CREATE TRIGGER trg_append_only_block_delete BEFORE DELETE ON %s FOR EACH STATEMENT EXECUTE FUNCTION app.guard_append_only_block()',
    p_table);

  EXECUTE format('DROP TRIGGER IF EXISTS trg_append_only_block_truncate ON %s', p_table);
  EXECUTE format(
    'CREATE TRIGGER trg_append_only_block_truncate BEFORE TRUNCATE ON %s FOR EACH STATEMENT EXECUTE FUNCTION app.guard_append_only_block()',
    p_table);

  EXECUTE format('DROP TRIGGER IF EXISTS trg_append_only_guard_update ON %s', p_table);
  IF array_length(p_allowed_update_columns, 1) > 0 THEN
    SELECT string_agg(quote_literal(c), ', ') INTO args FROM unnest(p_allowed_update_columns) c;
    EXECUTE format(
      'CREATE TRIGGER trg_append_only_guard_update BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION app.guard_append_only_update(%s)',
      p_table, args);
  ELSE
    EXECUTE format(
      'CREATE TRIGGER trg_append_only_guard_update BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION app.guard_append_only_block()',
      p_table);
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Monthly partitioning (no pg_partman, D2) + partition lock (2026-11-20 security fix, R3 generalised)
-- ---------------------------------------------------------------------------------------------------------------

-- Revokes every non-owner grant (not only PUBLIC/_app) on every partition of p_parent: partitions do not inherit
-- the parent's RLS or grants, so a default privilege or stray GRANT on a partition is a cross-tenant read that
-- bypasses the parent's RLS entirely. Query the parent only — this is called after every partition is created.
CREATE OR REPLACE FUNCTION app.lock_partitions(p_parent regclass) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  part regclass;
  owner_oid oid;
  g record;
BEGIN
  SELECT relowner INTO owner_oid FROM pg_class WHERE oid = p_parent;

  FOR part IN SELECT inhrelid::regclass FROM pg_inherits WHERE inhparent = p_parent LOOP
    EXECUTE format('REVOKE ALL ON %s FROM PUBLIC', part);
    FOR g IN
      SELECT DISTINCT (aclexplode(c.relacl)).grantee AS grantee_oid
      FROM pg_class c WHERE c.oid = part AND c.relacl IS NOT NULL
    LOOP
      CONTINUE WHEN g.grantee_oid IN (0, owner_oid); -- 0 = PUBLIC (already revoked above)
      EXECUTE format('REVOKE ALL ON %s FROM %I', part, g.grantee_oid::regrole::text);
    END LOOP;
  END LOOP;
END;
$$;

-- Creates monthly RANGE partitions for the current month through p_months_ahead, plus a DEFAULT partition as a
-- safety net (CLAUDE.md §4 — alert when it is non-empty is an operational concern, not implemented in SQL).
-- p_parent must already be declared PARTITION BY RANGE on a single timestamptz/date column.
CREATE OR REPLACE FUNCTION app.ensure_monthly_partitions(p_parent regclass, p_months_ahead int DEFAULT 3)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  schema_name text;
  table_name text;
  partkey_col text;
  i int;
  month_start date;
  month_end date;
  part_name text;
  default_name text;
BEGIN
  SELECT n.nspname, c.relname INTO schema_name, table_name
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.oid = p_parent;

  -- partattrs is an int2vector, which (unlike a normal array) is 0-indexed when subscripted.
  SELECT a.attname INTO partkey_col
  FROM pg_partitioned_table pt
  JOIN pg_attribute a ON a.attrelid = pt.partrelid AND a.attnum = pt.partattrs[0]
  WHERE pt.partrelid = p_parent;

  IF partkey_col IS NULL THEN
    RAISE EXCEPTION '% is not RANGE partitioned on a single column', p_parent;
  END IF;

  FOR i IN 0 .. p_months_ahead LOOP
    month_start := (date_trunc('month', now()) + (i || ' months')::interval)::date;
    month_end := (month_start + interval '1 month')::date;
    part_name := format('%s_%s', table_name, to_char(month_start, 'YYYY_MM'));
    IF NOT EXISTS (
      SELECT 1 FROM pg_class WHERE relname = part_name
        AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = schema_name)
    ) THEN
      EXECUTE format('CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L)',
        schema_name, part_name, schema_name, table_name, month_start, month_end);
    END IF;
  END LOOP;

  default_name := table_name || '_default';
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = default_name
      AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = schema_name)
  ) THEN
    EXECUTE format('CREATE TABLE %I.%I PARTITION OF %I.%I DEFAULT', schema_name, default_name, schema_name, table_name);
  END IF;

  PERFORM app.lock_partitions(p_parent);
END;
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Default privileges for schema public (schema app grants are explicit, set up in C0002)
-- ---------------------------------------------------------------------------------------------------------------

DO $$
DECLARE
  db text := current_database();
BEGIN
  EXECUTE format('GRANT USAGE ON SCHEMA public TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');
  EXECUTE format('GRANT USAGE ON SCHEMA app TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');

  EXECUTE format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I, %I',
    db || '_migrator', db || '_app', db || '_worker');
  EXECUTE format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO %I, %I',
    db || '_migrator', db || '_app', db || '_worker');
  EXECUTE format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO %I, %I',
    db || '_migrator', db || '_app', db || '_worker');
END;
$$;

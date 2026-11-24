-- C0002__outbox_inbox_audit_files.sql — transactional outbox, idempotent inbox, audit log, file metadata,
-- tenant read model (ADR-0003, ADR-0005 platform-table placement, ADR-0006 roles).
-- Fixes applied from the 2026-11-20 phase 2 review (docs/02-data/reviews/2026-11-20-phase2-review.md):
--   X2 — outbox/inbox/tenants had no RLS and full DML for the API role (cross-tenant forgery, inbox replay).
--   X4 — app.files.scan_status was updatable by every runtime role.
-- Event envelope columns match CLAUDE.md §3 (CloudEvents-style): eventId, type, source, subject, occurredAt,
-- tenantId, correlationId, causationId, traceparent, schemaVersion.

DO $$ DECLARE db text := current_database(); BEGIN

-- ---------------------------------------------------------------------------------------------------------------
-- app.outbox — written in the same transaction as the business change; relay (worker) publishes to RabbitMQ.
-- Never exposed by an API (ADR-0003 consequence: it is readable by the runtime worker role in-process).
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.outbox (
  id uuid NOT NULL DEFAULT uuidv7(),
  event_id uuid NOT NULL DEFAULT uuidv7(),
  event_type text NOT NULL,
  source text NOT NULL,
  subject text,
  aggregate_id uuid,
  aggregate_version bigint,
  tenant_id uuid,                              -- NULL = platform event (identity-access, scoring global layer, ...)
  correlation_id uuid,
  causation_id uuid,
  traceparent text,
  schema_version int NOT NULL DEFAULT 1,
  payload jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  attempts int NOT NULL DEFAULT 0,
  last_error text,
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE UNIQUE INDEX IF NOT EXISTS ux_outbox_event_id ON app.outbox (event_id, occurred_at);
CREATE INDEX IF NOT EXISTS ix_outbox_unpublished ON app.outbox (occurred_at) WHERE published_at IS NULL;

ALTER TABLE app.outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.outbox FORCE ROW LEVEL SECURITY;
EXECUTE format('DROP POLICY IF EXISTS outbox_app_insert ON app.outbox');
EXECUTE format('DROP POLICY IF EXISTS outbox_worker_all ON app.outbox');
EXECUTE format(
  'CREATE POLICY outbox_app_insert ON app.outbox FOR INSERT TO %I WITH CHECK (tenant_id = app.current_business_id() AND tenant_id IS NOT NULL)',
  db || '_app');
EXECUTE format(
  'CREATE POLICY outbox_worker_all ON app.outbox FOR ALL TO %I, %I USING (true) WITH CHECK (true)',
  db || '_worker', db || '_admin');

EXECUTE format('GRANT INSERT ON app.outbox TO %I', db || '_app'); -- no SELECT: the API never reads the outbox
EXECUTE format('GRANT SELECT, INSERT, UPDATE ON app.outbox TO %I, %I', db || '_worker', db || '_admin');

-- ---------------------------------------------------------------------------------------------------------------
-- app.inbox — idempotent consumers. PK (event_id, consumer, occurred_at): a redelivery carries the SAME
-- occurred_at as the original, so it collides in the same partition even across a month boundary (ADR-0003 —
-- keying on received_at instead would let a redelivery slip through as a "new" row). Worker-only; no DELETE.
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.inbox (
  event_id uuid NOT NULL,
  consumer text NOT NULL,
  occurred_at timestamptz NOT NULL,
  tenant_id uuid,
  event_type text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  attempts int NOT NULL DEFAULT 0,
  last_error text,
  payload jsonb,
  PRIMARY KEY (event_id, consumer, occurred_at)
) PARTITION BY RANGE (occurred_at);

ALTER TABLE app.inbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.inbox FORCE ROW LEVEL SECURITY;
EXECUTE format('DROP POLICY IF EXISTS inbox_worker_all ON app.inbox');
EXECUTE format(
  'CREATE POLICY inbox_worker_all ON app.inbox FOR ALL TO %I, %I USING (true) WITH CHECK (true)',
  db || '_worker', db || '_admin');
-- _app gets NO grant at all on app.inbox (fix-brief: "writes = worker only" means no access, not read-only).
EXECUTE format('GRANT SELECT, INSERT, UPDATE ON app.inbox TO %I, %I', db || '_worker', db || '_admin');

-- ---------------------------------------------------------------------------------------------------------------
-- app.audit_log — ADR-0005: audit is written in the same transaction as the action, so it lives per service,
-- not in a central platform service. actor_kind includes phone_owner for services with an owner self-view (R4).
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.audit_log (
  id uuid NOT NULL DEFAULT uuidv7(),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  tenant_id uuid,                              -- NULL = platform-level action
  actor_kind text NOT NULL CHECK (actor_kind IN ('system', 'app_user', 'admin_user', 'phone_owner')),
  actor_id uuid,
  action text NOT NULL,
  entity text,
  entity_id uuid,
  details jsonb,
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

ALTER TABLE app.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.audit_log FORCE ROW LEVEL SECURITY;
EXECUTE format('DROP POLICY IF EXISTS audit_log_tenant_select ON app.audit_log');
EXECUTE format('DROP POLICY IF EXISTS audit_log_app_insert ON app.audit_log');
EXECUTE format('DROP POLICY IF EXISTS audit_log_worker_all ON app.audit_log');
EXECUTE format(
  'CREATE POLICY audit_log_tenant_select ON app.audit_log FOR SELECT TO %I USING (tenant_id = app.current_business_id())',
  db || '_app');
EXECUTE format(
  'CREATE POLICY audit_log_app_insert ON app.audit_log FOR INSERT TO %I WITH CHECK (tenant_id = app.current_business_id() AND tenant_id IS NOT NULL)',
  db || '_app');
EXECUTE format(
  'CREATE POLICY audit_log_worker_all ON app.audit_log FOR ALL TO %I, %I USING (true) WITH CHECK (true)',
  db || '_worker', db || '_admin');
EXECUTE format('GRANT SELECT, INSERT ON app.audit_log TO %I', db || '_app');
EXECUTE format('GRANT SELECT, INSERT, UPDATE ON app.audit_log TO %I, %I', db || '_worker', db || '_admin');
PERFORM app.make_append_only('app.audit_log'); -- fully immutable; tightens the UPDATE grant above right back down

-- ---------------------------------------------------------------------------------------------------------------
-- app.files — metadata only; bytes live behind IFileStorage. X4 fix: _app may only INSERT scan_status='pending'
-- and may never set it afterwards; only the worker (virus-scan consumer) can flip scan_status.
-- UNIQUE (business_id, id) lets other tables FK in as (business_id, file_id) REFERENCES app.files (business_id, id).
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.files (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid, -- NULL = platform-owned file (e.g. a user avatar in identity-access, which isn't tenant-scoped)
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  storage_key text NOT NULL,
  original_name text NOT NULL,
  content_type text NOT NULL,
  size_bytes bigint NOT NULL CHECK (size_bytes >= 0),
  purpose text NOT NULL,
  scan_status text NOT NULL DEFAULT 'pending' CHECK (scan_status IN ('pending', 'clean', 'infected', 'error')),
  scanned_at timestamptz,
  deleted_at timestamptz,
  UNIQUE (business_id, id)
);

PERFORM app.add_updated_at_trigger('app.files');
PERFORM app.enable_tenant_rls('app.files'); -- tenant_isolation: covers business_id = app.current_business_id()
EXECUTE format('DROP POLICY IF EXISTS files_platform_all ON app.files');
EXECUTE format(
  'CREATE POLICY files_platform_all ON app.files FOR ALL TO %I, %I, %I USING (business_id IS NULL) WITH CHECK (business_id IS NULL)',
  db || '_app', db || '_worker', db || '_admin'); -- OR'd with tenant_isolation: either a matching tenant or no tenant at all
EXECUTE format('DROP POLICY IF EXISTS files_app_insert_pending ON app.files');
EXECUTE format(
  'CREATE POLICY files_app_insert_pending ON app.files AS RESTRICTIVE FOR INSERT TO %I WITH CHECK (scan_status = ''pending'')',
  db || '_app');

EXECUTE format('GRANT SELECT, INSERT ON app.files TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');
EXECUTE format('GRANT UPDATE (original_name, purpose, deleted_at) ON app.files TO %I', db || '_app');
EXECUTE format('GRANT UPDATE ON app.files TO %I, %I', db || '_worker', db || '_admin'); -- incl. scan_status

-- ---------------------------------------------------------------------------------------------------------------
-- app.tenants — read model of identity.business.* (ADR-0002: no FK to it anywhere). X2 fix: worker-only writes,
-- enforced twice (grant + a version-guard trigger so a stale/duplicate event can never roll status backwards).
-- No RLS: every row is a different tenant's own metadata; access is controlled by grants, not a tenant policy
-- (00-conventions §4 — platform tables have no business_id-scoped policy).
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.tenants (
  business_id uuid PRIMARY KEY,
  status text NOT NULL CHECK (status IN ('active', 'suspended', 'closed')),
  display_name text,
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

EXECUTE format('GRANT SELECT ON app.tenants TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');
EXECUTE format('GRANT INSERT, UPDATE ON app.tenants TO %I, %I', db || '_worker', db || '_admin');

END $$;

CREATE OR REPLACE FUNCTION app.guard_tenant_version() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.source_version <= OLD.source_version THEN
    RAISE EXCEPTION 'app.tenants: stale version % <= %', NEW.source_version, OLD.source_version USING ERRCODE = '40001';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tenants_version_guard ON app.tenants;
CREATE TRIGGER trg_tenants_version_guard BEFORE UPDATE ON app.tenants
FOR EACH ROW EXECUTE FUNCTION app.guard_tenant_version();

-- These three are shared building-block tables, so the building blocks (not each service) own their partitions.
SELECT app.ensure_monthly_partitions('app.outbox');
SELECT app.ensure_monthly_partitions('app.inbox');
SELECT app.ensure_monthly_partitions('app.audit_log');

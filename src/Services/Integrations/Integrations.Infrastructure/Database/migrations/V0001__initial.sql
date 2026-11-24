-- V0001__initial.sql — integrations schema (docs/02-data/integrations.md). Anti-corruption layer: connections,
-- webhook inbox with leases, carrier vocabulary mapping, idempotent carrier ops, CSV/XLSX imports.
-- Roles: standard trio only.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- digest() for payload_sha256

-- =================================================================================================================
-- 1. Platform: carrier catalogue, status vocabulary mapping, geo codes (app SELECT only; migrator writes)
-- =================================================================================================================

CREATE TABLE carriers (
  code text PRIMARY KEY,
  name text NOT NULL,
  api_family text NOT NULL, -- e.g. 'ecotrack' hosts several carriers under one integration shape (open Q4)
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE carrier_status_mapping_sets (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  carrier_code text NOT NULL REFERENCES carriers (code),
  version int NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'retired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz,
  retired_at timestamptz,
  UNIQUE (carrier_code, version)
);
CREATE UNIQUE INDEX ux_csms_one_active ON carrier_status_mapping_sets (carrier_code) WHERE status = 'active';

-- 13-value normalised vocabulary (D7) + unknown. Shared with carrier_shipments.status below.
CREATE TABLE carrier_status_mappings (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  set_id uuid NOT NULL REFERENCES carrier_status_mapping_sets (id),
  raw_status text NOT NULL,
  normalized_status text NOT NULL CHECK (normalized_status IN (
    'requested', 'created', 'creation_failed', 'picked_up', 'in_transit', 'out_for_delivery',
    'awaiting_customer_pickup', 'delivered', 'failed', 'returned', 'cancelled', 'lost', 'unknown'
  )),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_csm_set_raw ON carrier_status_mappings (set_id, raw_status);

-- Frozen once its set is no longer draft (reproducibility of normalised history — D1).
CREATE OR REPLACE FUNCTION guard_mapping_set_frozen() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status text; v_set_id uuid := COALESCE(NEW.set_id, OLD.set_id);
BEGIN
  SELECT status INTO v_status FROM carrier_status_mapping_sets WHERE id = v_set_id;
  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'carrier_status_mappings: set % is % (not draft), rows are frozen', v_set_id, v_status USING ERRCODE = '55000';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_mapping_frozen BEFORE INSERT OR UPDATE OR DELETE ON carrier_status_mappings
FOR EACH ROW EXECUTE FUNCTION guard_mapping_set_frozen();

CREATE TABLE carrier_geo_codes (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  carrier_code text NOT NULL REFERENCES carriers (code),
  geo_dataset_version int NOT NULL,
  wilaya_code text NOT NULL,
  commune_code text, -- NULL = wilaya-level code only
  carrier_wilaya_value text NOT NULL,
  carrier_commune_value text,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (geo_dataset_version, wilaya_code) REFERENCES ref.wilayas (dataset_version, code),
  FOREIGN KEY (geo_dataset_version, commune_code, wilaya_code) REFERENCES ref.communes (dataset_version, code, wilaya_code)
);
CREATE UNIQUE INDEX ux_cgc_current ON carrier_geo_codes (carrier_code, geo_dataset_version, wilaya_code, commune_code) NULLS NOT DISTINCT;
CREATE INDEX ix_cgc_inbound ON carrier_geo_codes (carrier_code, carrier_commune_value);

DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('GRANT SELECT ON carriers, carrier_status_mapping_sets, carrier_status_mappings, carrier_geo_codes TO %I, %I, %I',
    db || '_app', db || '_worker', db || '_admin');
  EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON carriers, carrier_status_mapping_sets, carrier_status_mappings, carrier_geo_codes FROM %I, %I',
    db || '_app', db || '_worker');
END $$;

-- =================================================================================================================
-- 2. Connections and secrets
-- =================================================================================================================

CREATE TABLE integration_connections (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('manual', 'csv', 'custom_api', 'shopify', 'whatsapp', 'carrier')),
  carrier_code text REFERENCES carriers (code), -- only for kind='carrier'
  external_account_id text,
  route_key text NOT NULL, -- 128-bit random hex; resolves the tenant pre-RLS from the public webhook URL
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'error', 'disabled')),
  created_by uuid, -- opaque ref: identity_access.business_members
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  CHECK (kind = 'carrier' OR carrier_code IS NULL)
);
-- D11: global, not business_id-first — resolved before any tenant is known.
CREATE UNIQUE INDEX uq_ic_route_key ON integration_connections (route_key);
CREATE UNIQUE INDEX ux_ic_external_account ON integration_connections (kind, carrier_code, external_account_id)
  WHERE status <> 'disabled' AND external_account_id IS NOT NULL;
SELECT app.add_updated_at_trigger('integration_connections');
SELECT app.enable_tenant_rls('integration_connections');

CREATE TABLE connection_secrets (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  connection_id uuid NOT NULL,
  purpose text NOT NULL CHECK (purpose IN ('webhook_verify', 'api_auth')),
  method text NOT NULL CHECK (method IN ('secret_store', 'envelope', 'sha256_hash')),
  secret_store_ref text,
  envelope_ciphertext bytea,
  envelope_dek_wrapped bytea,
  kek_id text,
  sha256_hash bytea CHECK (sha256_hash IS NULL OR octet_length(sha256_hash) = 32),
  display_hint text CHECK (display_hint IS NULL OR length(display_hint) <= 8),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'retired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, connection_id) REFERENCES integration_connections (business_id, id) ON DELETE CASCADE,
  CHECK (
    (method = 'secret_store' AND secret_store_ref IS NOT NULL) OR
    (method = 'envelope' AND envelope_ciphertext IS NOT NULL AND envelope_dek_wrapped IS NOT NULL AND kek_id IS NOT NULL) OR
    (method = 'sha256_hash' AND sha256_hash IS NOT NULL)
  )
);
CREATE INDEX ix_cs_live ON connection_secrets (business_id, connection_id, purpose) WHERE status = 'active';
SELECT app.enable_tenant_rls('connection_secrets');

-- =================================================================================================================
-- 3. Webhook inbox (partitioned, append-only except the processing columns)
-- =================================================================================================================

CREATE TABLE webhook_events (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  connection_id uuid NOT NULL,
  channel text NOT NULL CHECK (channel IN ('webhook', 'poll', 'replay')),
  external_id_kind text CHECK (external_id_kind IN ('provider', 'derived')),
  external_event_id text,
  headers jsonb,
  payload jsonb,
  payload_sha256 bytea,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'processed', 'failed', 'ignored', 'dead')),
  ignored_reason text, -- D6: invalid signature -> ignored, no dedup key taken
  attempts int NOT NULL DEFAULT 0,
  next_attempt_at timestamptz,
  lease_until timestamptz,
  processed_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, received_at),
  FOREIGN KEY (business_id, connection_id) REFERENCES integration_connections (business_id, id)
) PARTITION BY RANGE (received_at);
CREATE INDEX ix_we_pending ON webhook_events (business_id, connection_id) WHERE status = 'pending';
CREATE INDEX ix_we_claim ON webhook_events (next_attempt_at) WHERE status IN ('pending', 'failed');
CREATE INDEX ix_we_connection ON webhook_events (business_id, connection_id, status, received_at DESC);
SELECT app.enable_tenant_rls('webhook_events');
SELECT app.make_append_only('webhook_events', ARRAY['status', 'attempts', 'next_attempt_at', 'lease_until', 'ignored_reason', 'processed_at']);
SELECT app.ensure_monthly_partitions('webhook_events');

-- Dedup key lives outside the partitioned table (D4): a UNIQUE on a partitioned table must include the
-- partition key, which differs per redelivery, so the key itself cannot live there.
CREATE TABLE webhook_event_keys (
  business_id uuid NOT NULL,
  connection_id uuid NOT NULL,
  external_event_id text NOT NULL,
  webhook_event_id uuid NOT NULL, -- no FK: points into the partitioned table by convention only
  first_received_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, connection_id, external_event_id),
  FOREIGN KEY (business_id, connection_id) REFERENCES integration_connections (business_id, id)
);
CREATE INDEX ix_wek_first_received ON webhook_event_keys (first_received_at);
SELECT app.enable_tenant_rls('webhook_event_keys');

-- =================================================================================================================
-- 4. Crosswalk, carrier shipments and requests
-- =================================================================================================================

CREATE TABLE external_refs (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  connection_id uuid NOT NULL,
  entity_type text NOT NULL CHECK (entity_type IN ('contact', 'order', 'product', 'shipment', 'message')),
  entity_id uuid NOT NULL, -- allocated by integrations (uuidv7) on first sight (D12) — opaque to crm/orders
  external_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, connection_id) REFERENCES integration_connections (business_id, id)
);
CREATE UNIQUE INDEX uq_er_external ON external_refs (business_id, connection_id, entity_type, external_id);
CREATE INDEX ix_er_entity ON external_refs (business_id, entity_type, entity_id);
SELECT app.add_updated_at_trigger('external_refs');
SELECT app.enable_tenant_rls('external_refs');

CREATE TABLE carrier_shipments (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  connection_id uuid NOT NULL,
  shipment_id uuid NOT NULL, -- opaque ref: orders.shipments
  order_id uuid, -- opaque ref: orders.orders
  tracking_number text,
  label_file_id uuid,
  status text NOT NULL DEFAULT 'requested' CHECK (status IN (
    'requested', 'created', 'creation_failed', 'picked_up', 'in_transit', 'out_for_delivery',
    'awaiting_customer_pickup', 'delivered', 'failed', 'returned', 'cancelled', 'lost', 'unknown'
  )),
  last_raw_status text,
  last_mapping_version int,
  last_event_at timestamptz,
  next_poll_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  FOREIGN KEY (business_id, connection_id) REFERENCES integration_connections (business_id, id),
  FOREIGN KEY (business_id, label_file_id) REFERENCES app.files (business_id, id)
);
CREATE UNIQUE INDEX uq_cship_shipment ON carrier_shipments (business_id, connection_id, shipment_id);
CREATE UNIQUE INDEX ux_cship_tracking ON carrier_shipments (business_id, connection_id, tracking_number) WHERE tracking_number IS NOT NULL;
CREATE INDEX ix_cship_poll ON carrier_shipments (next_poll_at) WHERE status NOT IN ('delivered', 'failed', 'returned', 'cancelled', 'creation_failed', 'lost');
SELECT app.add_updated_at_trigger('carrier_shipments');
SELECT app.enable_tenant_rls('carrier_shipments');

CREATE TABLE carrier_requests (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  carrier_shipment_id uuid NOT NULL,
  operation text NOT NULL CHECK (operation IN ('create', 'cancel', 'relabel', 'update_address')),
  idempotency_key text NOT NULL,
  source_event_id uuid, -- opaque ref: orders outbox
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'succeeded', 'failed', 'retryable', 'outcome_unknown')),
  attempts int NOT NULL DEFAULT 0,
  request_payload jsonb,
  response_payload jsonb,
  next_attempt_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, carrier_shipment_id) REFERENCES carrier_shipments (business_id, id)
);
CREATE UNIQUE INDEX uq_creq_idempotency ON carrier_requests (business_id, carrier_shipment_id, operation, idempotency_key);
CREATE INDEX ix_creq_claim ON carrier_requests (next_attempt_at) WHERE status IN ('pending', 'retryable', 'outcome_unknown');
CREATE INDEX ix_creq_shipment ON carrier_requests (business_id, carrier_shipment_id);
SELECT app.enable_tenant_rls('carrier_requests');

-- =================================================================================================================
-- 5. Imports
-- =================================================================================================================

CREATE TABLE import_jobs (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('contacts', 'orders', 'products', 'remittances')),
  file_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'validated', 'running', 'completed', 'failed', 'cancelled')),
  dedupe_strategy text NOT NULL DEFAULT 'skip' CHECK (dedupe_strategy IN ('skip', 'update', 'create')),
  rows_total int NOT NULL DEFAULT 0,
  rows_succeeded int NOT NULL DEFAULT 0,
  rows_failed int NOT NULL DEFAULT 0,
  rows_skipped int NOT NULL DEFAULT 0,
  created_by uuid, -- opaque ref: identity_access.business_members
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  FOREIGN KEY (business_id, file_id) REFERENCES app.files (business_id, id)
);
CREATE INDEX ix_ij_list ON import_jobs (business_id, created_at DESC);
SELECT app.add_updated_at_trigger('import_jobs');
SELECT app.enable_tenant_rls('import_jobs');

CREATE TABLE import_rows (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  job_id uuid NOT NULL,
  row_number int NOT NULL,
  raw jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'valid', 'invalid', 'succeeded', 'failed')),
  entity_type text,
  entity_id uuid,
  error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, job_id) REFERENCES import_jobs (business_id, id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX uq_ir_row ON import_rows (business_id, job_id, row_number);
CREATE INDEX ix_ir_job_status ON import_rows (business_id, job_id, status);
SELECT app.add_updated_at_trigger('import_rows');
SELECT app.enable_tenant_rls('import_rows');

-- =================================================================================================================
-- 6. Outbound call log (debug; partitioned, fully immutable)
-- =================================================================================================================

CREATE TABLE outbound_calls (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  connection_id uuid NOT NULL,
  carrier_request_id uuid,
  method text NOT NULL,
  url_template text NOT NULL,
  status_code int,
  request_excerpt text, -- scrubbed, <= 4KB, path templates without query strings
  response_excerpt text,
  duration_ms int,
  started_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, started_at),
  FOREIGN KEY (business_id, connection_id) REFERENCES integration_connections (business_id, id)
) PARTITION BY RANGE (started_at);
CREATE INDEX ix_oc_connection ON outbound_calls (business_id, connection_id, started_at DESC);
SELECT app.enable_tenant_rls('outbound_calls');
SELECT app.make_append_only('outbound_calls', '{}');
SELECT app.ensure_monthly_partitions('outbound_calls');

-- =================================================================================================================
-- 7. Functions
-- =================================================================================================================

-- Tenant resolution BEFORE any RLS context exists — the only two SECURITY DEFINER bridges that take no tenant.
CREATE OR REPLACE FUNCTION resolve_webhook_connection_by_route(p_route_key text)
RETURNS TABLE (connection_id uuid, business_id uuid, status text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT id, integration_connections.business_id, integration_connections.status
   FROM public.integration_connections WHERE route_key = p_route_key;
$$;
REVOKE ALL ON FUNCTION resolve_webhook_connection_by_route(text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION resolve_webhook_connection_by_account(p_kind text, p_carrier_code text, p_external_account_id text)
RETURNS TABLE (connection_id uuid, business_id uuid, status text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT id, integration_connections.business_id, integration_connections.status
   FROM public.integration_connections
   WHERE kind = p_kind AND carrier_code IS NOT DISTINCT FROM p_carrier_code
     AND external_account_id = p_external_account_id AND status <> 'disabled';
$$;
REVOKE ALL ON FUNCTION resolve_webhook_connection_by_account(text, text, text) FROM PUBLIC;

-- SECURITY INVOKER (refuses without a tenant): the handler has already resolved the connection and set the
-- tenant before calling this. Dedup via webhook_event_keys ON CONFLICT DO NOTHING; a conflict means a
-- redelivery — the caller checks FOUND to decide whether to insert into webhook_events at all. D6: an
-- ignored (bad-signature) event is passed with p_take_dedup_key = false, so a forged request never occupies
-- the genuine event's dedup slot.
CREATE OR REPLACE FUNCTION ingest_webhook_event(
  p_business_id uuid, p_connection_id uuid, p_channel text, p_external_event_id text,
  p_external_id_kind text, p_headers jsonb, p_payload jsonb, p_status text DEFAULT 'pending',
  p_ignored_reason text DEFAULT NULL, p_take_dedup_key boolean DEFAULT true
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  IF app.current_business_id() IS DISTINCT FROM p_business_id THEN
    RAISE EXCEPTION 'ingest_webhook_event: no matching tenant context' USING ERRCODE = '55000';
  END IF;

  IF p_take_dedup_key AND p_external_event_id IS NOT NULL THEN
    INSERT INTO webhook_event_keys (business_id, connection_id, external_event_id, webhook_event_id)
    VALUES (p_business_id, p_connection_id, p_external_event_id, uuidv7())
    ON CONFLICT DO NOTHING
    RETURNING webhook_event_id INTO v_id;
    IF v_id IS NULL THEN
      RETURN NULL; -- redelivery within the dedup window; caller does not insert into webhook_events
    END IF;
  ELSE
    v_id := uuidv7();
  END IF;

  INSERT INTO webhook_events (id, business_id, connection_id, channel, external_id_kind, external_event_id,
                               headers, payload, payload_sha256, status, ignored_reason)
  VALUES (v_id, p_business_id, p_connection_id, p_channel, p_external_id_kind, p_external_event_id,
          p_headers, p_payload, digest(p_payload::text, 'sha256'), p_status, p_ignored_reason);
  RETURN v_id;
END;
$$;

-- Worker claim functions: SECURITY DEFINER, BYPASSRLS (cross-tenant by design), return ids + business_id ONLY
-- (never payload) — the worker re-sets the tenant and processes each item in its own transaction.
-- #variable_conflict: the RETURNS TABLE columns (event_id, received_at, business_id, connection_id) become
-- implicit PL/pgSQL variables, which collide with identically-named table columns referenced unqualified below.
CREATE OR REPLACE FUNCTION claim_webhook_events(p_limit int DEFAULT 50)
RETURNS TABLE (event_id uuid, received_at timestamptz, business_id uuid, connection_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
#variable_conflict use_column
BEGIN
  RETURN QUERY
    UPDATE public.webhook_events w SET status = 'processing', lease_until = now() + interval '5 minutes'
    FROM (
      SELECT we.id, we.received_at FROM public.webhook_events we
       WHERE we.status IN ('pending', 'failed') AND (we.next_attempt_at IS NULL OR we.next_attempt_at <= now())
         AND (we.lease_until IS NULL OR we.lease_until < now())
       ORDER BY we.received_at LIMIT p_limit FOR UPDATE SKIP LOCKED
    ) picked
    WHERE w.id = picked.id AND w.received_at = picked.received_at
    RETURNING w.id, w.received_at, w.business_id, w.connection_id;
END;
$$;
REVOKE ALL ON FUNCTION claim_webhook_events(int) FROM PUBLIC;

CREATE OR REPLACE FUNCTION claim_carrier_requests(p_limit int DEFAULT 50)
RETURNS TABLE (carrier_request_id uuid, business_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  UPDATE public.carrier_requests cr SET status = 'pending', attempts = attempts + 1
  FROM (
    SELECT id FROM public.carrier_requests
     WHERE status IN ('pending', 'retryable', 'outcome_unknown') AND (next_attempt_at IS NULL OR next_attempt_at <= now())
     ORDER BY next_attempt_at NULLS FIRST LIMIT p_limit FOR UPDATE SKIP LOCKED
  ) picked
  WHERE cr.id = picked.id
  RETURNING cr.id, cr.business_id;
$$;
REVOKE ALL ON FUNCTION claim_carrier_requests(int) FROM PUBLIC;

CREATE OR REPLACE FUNCTION claim_shipments_to_poll(p_limit int DEFAULT 50)
RETURNS TABLE (carrier_shipment_id uuid, business_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  UPDATE public.carrier_shipments cs SET next_poll_at = now() + interval '15 minutes'
  FROM (
    SELECT id FROM public.carrier_shipments
     WHERE status NOT IN ('delivered', 'failed', 'returned', 'cancelled', 'creation_failed', 'lost')
       AND (next_poll_at IS NULL OR next_poll_at <= now())
     ORDER BY next_poll_at NULLS FIRST LIMIT p_limit FOR UPDATE SKIP LOCKED
  ) picked
  WHERE cs.id = picked.id
  RETURNING cs.id, cs.business_id;
$$;
REVOKE ALL ON FUNCTION claim_shipments_to_poll(int) FROM PUBLIC;

-- Dedup window purge (daily job): default 90 days, never below the 30-day floor (doc §7).
CREATE OR REPLACE FUNCTION purge_webhook_event_keys(p_window_days int DEFAULT 90) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  WITH deleted AS (
    DELETE FROM public.webhook_event_keys
     WHERE first_received_at < now() - make_interval(days => greatest(p_window_days, 30))
    RETURNING 1
  )
  SELECT count(*) FROM deleted;
$$;
REVOKE ALL ON FUNCTION purge_webhook_event_keys(int) FROM PUBLIC;

-- Claw back C0001's default-privilege auto-grant on every function above, then grant to exactly the role
-- that needs it (app resolves + ingests; worker claims + purges).
DO $$ DECLARE db text := current_database(); app_r text := current_database() || '_app'; wrk text := current_database() || '_worker'; BEGIN
  EXECUTE format(
    'REVOKE ALL ON FUNCTION resolve_webhook_connection_by_route(text), resolve_webhook_connection_by_account(text, text, text), ingest_webhook_event(uuid, uuid, text, text, text, jsonb, jsonb, text, text, boolean), claim_webhook_events(int), claim_carrier_requests(int), claim_shipments_to_poll(int), purge_webhook_event_keys(int) FROM %I, %I',
    app_r, wrk);
  EXECUTE format(
    'GRANT EXECUTE ON FUNCTION resolve_webhook_connection_by_route(text), resolve_webhook_connection_by_account(text, text, text), ingest_webhook_event(uuid, uuid, text, text, text, jsonb, jsonb, text, text, boolean) TO %I',
    app_r);
  EXECUTE format(
    'GRANT EXECUTE ON FUNCTION claim_webhook_events(int), claim_carrier_requests(int), claim_shipments_to_poll(int), purge_webhook_event_keys(int) TO %I',
    wrk);
END $$;

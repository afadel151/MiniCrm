-- V0001__initial.sql — orders schema (docs/02-data/orders.md). Two state machines (order, cash) driven by a
-- data-table + trigger pair rather than hardcoded CASE/CHECK, so C# and the DB read the same edges.
-- Roles: standard trio only.

-- =================================================================================================================
-- 1. Catalogue
-- =================================================================================================================

CREATE TABLE products (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  sku text NOT NULL,
  name text NOT NULL,
  description text,
  price numeric(12, 2) NOT NULL CHECK (price >= 0),
  currency char(3) NOT NULL DEFAULT 'DZD',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (business_id, id)
);
CREATE UNIQUE INDEX ux_products_sku ON products (business_id, sku) WHERE deleted_at IS NULL;
CREATE INDEX ix_products_list ON products (business_id, status) WHERE deleted_at IS NULL;
SELECT app.add_updated_at_trigger('products');
SELECT app.enable_tenant_rls('products');

CREATE TABLE product_variants (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  product_id uuid NOT NULL,
  sku text NOT NULL,
  name text NOT NULL,
  price_override numeric(12, 2) CHECK (price_override >= 0),
  stock_qty int NOT NULL DEFAULT 0,
  reserved_qty int NOT NULL DEFAULT 0 CHECK (reserved_qty >= 0 AND reserved_qty <= stock_qty), -- Open Q5: no floor on stock_qty itself
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  UNIQUE (business_id, product_id, id), -- composite-FK target for order_items (business, product, variant)
  FOREIGN KEY (business_id, product_id) REFERENCES products (business_id, id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX ux_product_variants_sku ON product_variants (business_id, sku);
SELECT app.add_updated_at_trigger('product_variants');
SELECT app.enable_tenant_rls('product_variants');

CREATE TABLE product_images (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  product_id uuid NOT NULL,
  file_id uuid NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, product_id) REFERENCES products (business_id, id) ON DELETE CASCADE,
  FOREIGN KEY (business_id, file_id) REFERENCES app.files (business_id, id)
);
SELECT app.enable_tenant_rls('product_images');

-- =================================================================================================================
-- 2. Order number counter (R: gap-tolerant, allocated in the app's OWN short transaction before the order write)
-- =================================================================================================================

CREATE TABLE order_number_counters (
  business_id uuid PRIMARY KEY,
  prefix text NOT NULL DEFAULT '',
  next_value bigint NOT NULL DEFAULT 1
);
SELECT app.enable_tenant_rls('order_number_counters');

CREATE OR REPLACE FUNCTION allocate_order_numbers(p_business_id uuid, p_n int DEFAULT 1)
RETURNS TABLE (order_seq bigint, order_number text) LANGUAGE plpgsql AS $$
DECLARE v_prefix text; v_start bigint;
BEGIN
  IF app.current_business_id() IS DISTINCT FROM p_business_id THEN
    RAISE EXCEPTION 'allocate_order_numbers: no matching tenant context' USING ERRCODE = '55000';
  END IF;

  INSERT INTO order_number_counters (business_id, next_value) VALUES (p_business_id, 1 + p_n)
  ON CONFLICT (business_id) DO UPDATE SET next_value = order_number_counters.next_value + p_n
  RETURNING prefix, next_value - p_n INTO v_prefix, v_start;

  RETURN QUERY SELECT s, v_prefix || lpad(s::text, 6, '0') FROM generate_series(v_start, v_start + p_n - 1) s;
END;
$$;

-- =================================================================================================================
-- 3. Orders and lines
-- =================================================================================================================

CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  order_seq bigint NOT NULL,
  order_number text NOT NULL,
  idempotency_key text,
  contact_id uuid, -- opaque ref: crm.contacts — nullable, webhook orders may precede the contact (Q1)
  contact_phone_id uuid, -- opaque ref: crm.contact_phones
  customer_name text NOT NULL,
  phone_raw text NOT NULL,
  phone_e164 text NOT NULL CHECK (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  address_text text,
  address_notes text,
  geo_dataset_version int,
  wilaya_code text,
  commune_code text,
  delivery_mode text NOT NULL DEFAULT 'home' CHECK (delivery_mode IN ('home', 'stopdesk')),
  stopdesk_id uuid, -- opaque ref: integrations
  status text NOT NULL,
  cash_status text NOT NULL,
  confirmation_status text NOT NULL DEFAULT 'pending' CHECK (confirmation_status IN ('pending', 'confirmed', 'declined', 'expired')),
  outcome_class text CHECK (outcome_class IN ('success', 'customer_failure', 'business_failure', 'neutral')), -- verbatim vocabulary, V1 spec §5.5.2
  closed_at timestamptz,
  placed_at timestamptz NOT NULL DEFAULT now(),
  risk_snapshot_id uuid, -- opaque ref: scoring (tenant_score_history.id)
  risk_tier_at_order text,
  risk_confidence_at_order text,
  risk_recommended_actions jsonb,
  requires_manager_approval boolean NOT NULL DEFAULT false,
  manager_approved_by uuid,
  manager_approved_at timestamptz,
  pii_erased_at timestamptz,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  UNIQUE (business_id, order_number),
  FOREIGN KEY (geo_dataset_version, commune_code, wilaya_code) REFERENCES ref.communes (dataset_version, code, wilaya_code),
  -- Row-level couplings between the two machines (§5):
  CHECK (status <> 'delivered' OR (outcome_class = 'success' AND cash_status <> 'pending_collection')),
  CHECK (status <> 'cancelled' OR cash_status IN ('not_collected', 'not_applicable')),
  CHECK (cash_status NOT IN ('collected_by_carrier', 'collected_by_business', 'remitted', 'reconciled') OR status IN ('delivered', 'return_in_transit', 'returned')),
  CHECK (status NOT IN ('confirmed', 'shipped', 'out_for_delivery', 'delivered') OR (confirmation_status = 'confirmed' AND phone_e164 IS NOT NULL))
);
CREATE UNIQUE INDEX ux_orders_idempotency ON orders (business_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX ix_orders_status_placed ON orders (business_id, status, placed_at DESC);
CREATE INDEX ix_orders_placed ON orders (business_id, placed_at DESC);
CREATE INDEX ix_orders_contact ON orders (business_id, contact_id) WHERE contact_id IS NOT NULL;
CREATE INDEX ix_orders_phone ON orders (business_id, phone_hash, placed_at DESC);
CREATE INDEX ix_orders_cash_aging ON orders (business_id, cash_status, placed_at) WHERE status = 'delivered' AND cash_status = 'pending_collection';
SELECT app.add_updated_at_trigger('orders');
SELECT app.enable_tenant_rls('orders');
-- orders never hard-deleted (returns/remittances reference it); no DELETE grant at all, not even revoked-from-
-- default, so skip app.make_append_only (it allows DELETE in the--default-closed sense, not needed here) and
-- instead just REVOKE below.

CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  order_id uuid NOT NULL,
  product_id uuid,
  variant_id uuid,
  qty int NOT NULL CHECK (qty > 0),
  unit_price numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
  line_total numeric(12, 2) NOT NULL CHECK (line_total >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, order_id) REFERENCES orders (business_id, id) ON DELETE CASCADE,
  FOREIGN KEY (business_id, product_id) REFERENCES products (business_id, id), -- RESTRICT (default): can't delete a product that's on an order
  FOREIGN KEY (business_id, product_id, variant_id) REFERENCES product_variants (business_id, product_id, id)
);
CREATE INDEX ix_order_items_order ON order_items (business_id, order_id);
CREATE INDEX ix_order_items_product ON order_items (business_id, product_id);
SELECT app.enable_tenant_rls('order_items');

-- =================================================================================================================
-- 4. State machines: transitions table (platform, read-only) + history (tenant, append-only, partitioned)
-- =================================================================================================================

CREATE TABLE order_status_transitions (
  machine text NOT NULL CHECK (machine IN ('order', 'cash', 'return')),
  from_status text, -- NULL = legal initial state
  to_status text NOT NULL,
  allowed_sources text[] NOT NULL,
  requires_reason boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX ux_order_status_transitions ON order_status_transitions (machine, from_status, to_status) NULLS NOT DISTINCT;
-- Platform read-only reference data: writable only by the migrator (seed), same pattern as identity-access.permissions.
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('GRANT SELECT ON order_status_transitions TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');
  EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON order_status_transitions FROM %I, %I', db || '_app', db || '_worker');
END $$;

CREATE TABLE order_status_history (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  order_id uuid NOT NULL,
  machine text NOT NULL CHECK (machine IN ('order', 'cash', 'return')),
  from_status text,
  to_status text NOT NULL,
  reason_code text,
  note text,
  source text NOT NULL CHECK (source IN ('system', 'manual', 'webhook', 'carrier')),
  is_override boolean NOT NULL DEFAULT false,
  order_version bigint NOT NULL,
  actor_member_id uuid,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, recorded_at),
  FOREIGN KEY (business_id, order_id) REFERENCES orders (business_id, id), -- RESTRICT: history outlives nothing
  CHECK (NOT is_override OR (note IS NOT NULL AND actor_member_id IS NOT NULL AND source = 'manual'))
) PARTITION BY RANGE (recorded_at);
CREATE INDEX ix_osh_order ON order_status_history (business_id, order_id, recorded_at);
SELECT app.enable_tenant_rls('order_status_history');
SELECT app.make_append_only('order_status_history', '{}');
SELECT app.ensure_monthly_partitions('order_status_history');

-- Guard 1: an inserted history row's edge must be legal (UI error codes map 1:1 onto these RAISE messages;
-- is_override skips the edge/source/reason checks but demands note+actor+source='manual', enforced by the CHECK
-- above since that CHECK runs regardless of this trigger).
CREATE OR REPLACE FUNCTION guard_osh_edge() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_transition order_status_transitions;
BEGIN
  IF NEW.is_override THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_transition FROM order_status_transitions
   WHERE machine = NEW.machine AND from_status IS NOT DISTINCT FROM NEW.from_status AND to_status = NEW.to_status;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_ILLEGAL_TRANSITION: % % -> % not a legal edge', NEW.machine, NEW.from_status, NEW.to_status
      USING ERRCODE = '55000';
  END IF;
  IF NOT (NEW.source = ANY (v_transition.allowed_sources)) THEN
    RAISE EXCEPTION 'ORDER_TRANSITION_SOURCE_NOT_ALLOWED: source % not allowed for % % -> %', NEW.source, NEW.machine, NEW.from_status, NEW.to_status
      USING ERRCODE = '55000';
  END IF;
  IF v_transition.requires_reason AND NEW.reason_code IS NULL THEN
    RAISE EXCEPTION 'ORDER_TRANSITION_REASON_REQUIRED: % -> % needs a reason_code', NEW.from_status, NEW.to_status
      USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_osh_validate BEFORE INSERT ON order_status_history
FOR EACH ROW EXECUTE FUNCTION guard_osh_edge();

-- Guard 2: every status/cash_status value an `orders` row ever holds (including the very first one) must have a
-- matching, same-version history row written in the same transaction. Deferred so EF Core can save the order
-- and the history row(s) in either order; checked at COMMIT.
-- On INSERT both machines are "new" (checked unconditionally, incl. the initial state). On UPDATE only the
-- machine(s) that actually changed need a matching row — otherwise every order-only edge would also force a
-- meaningless cash self-loop row (and vice versa), which order_status_transitions correctly has no edge for.
CREATE OR REPLACE FUNCTION guard_orders_history_logged() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_check_order boolean; v_check_cash boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_check_order := true;
    v_check_cash := true;
  ELSE
    v_check_order := OLD.status IS DISTINCT FROM NEW.status;
    v_check_cash := OLD.cash_status IS DISTINCT FROM NEW.cash_status;
  END IF;

  IF v_check_order AND NOT EXISTS (
    SELECT 1 FROM order_status_history
     WHERE business_id = NEW.business_id AND order_id = NEW.id AND machine = 'order'
       AND to_status = NEW.status AND order_version = NEW.version
  ) THEN
    RAISE EXCEPTION 'ORDER_STATUS_CHANGE_NOT_LOGGED: order % status % at version % has no history row', NEW.id, NEW.status, NEW.version
      USING ERRCODE = '55000';
  END IF;
  IF v_check_cash AND NOT EXISTS (
    SELECT 1 FROM order_status_history
     WHERE business_id = NEW.business_id AND order_id = NEW.id AND machine = 'cash'
       AND to_status = NEW.cash_status AND order_version = NEW.version
  ) THEN
    RAISE EXCEPTION 'ORDER_STATUS_CHANGE_NOT_LOGGED: order % cash_status % at version % has no history row', NEW.id, NEW.cash_status, NEW.version
      USING ERRCODE = '55000';
  END IF;
  RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER trg_orders_history_ins AFTER INSERT ON orders
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION guard_orders_history_logged();
CREATE CONSTRAINT TRIGGER trg_orders_history_upd AFTER UPDATE ON orders
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.cash_status IS DISTINCT FROM NEW.cash_status)
EXECUTE FUNCTION guard_orders_history_logged();

-- orders.version must increase on every update (same pattern as scoring.net.global_scores, S7-style guard).
CREATE OR REPLACE FUNCTION guard_orders_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.version <= OLD.version THEN
    RAISE EXCEPTION 'orders: stale version % <= %', NEW.version, OLD.version USING ERRCODE = '40001';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_orders_version BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION guard_orders_version();

-- =================================================================================================================
-- 5. Confirmation
-- =================================================================================================================

CREATE TABLE confirmation_requests (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  order_id uuid NOT NULL,
  token_hash bytea NOT NULL CHECK (octet_length(token_hash) = 32),
  result text NOT NULL DEFAULT 'pending' CHECK (result IN ('pending', 'confirmed', 'declined', 'expired', 'superseded')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  resolved_at timestamptz,
  ip text,
  user_agent text,
  recap_snapshot jsonb,
  edits jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, order_id) REFERENCES orders (business_id, id)
);
CREATE UNIQUE INDEX ux_confirmation_requests_token ON confirmation_requests (token_hash); -- global: resolved before any tenant is known
CREATE UNIQUE INDEX ux_confirmation_requests_open ON confirmation_requests (business_id, order_id) WHERE result = 'pending';
CREATE INDEX ix_confirmation_requests_order ON confirmation_requests (business_id, order_id);
CREATE INDEX ix_confirmation_requests_due ON confirmation_requests (business_id, expires_at) WHERE result = 'pending';
SELECT app.enable_tenant_rls('confirmation_requests');

-- The one SECURITY DEFINER function in this service: public confirmation link resolution happens before any
-- tenant is known. Returns ids only, never the order's PII.
CREATE OR REPLACE FUNCTION resolve_confirmation_token(p_token_hash bytea)
RETURNS TABLE (confirmation_request_id uuid, order_id uuid, business_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT id, confirmation_requests.order_id, confirmation_requests.business_id FROM public.confirmation_requests
   WHERE token_hash = p_token_hash AND result = 'pending' AND expires_at > now();
$$;
REVOKE ALL ON FUNCTION resolve_confirmation_token(bytea) FROM PUBLIC;
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('REVOKE ALL ON FUNCTION resolve_confirmation_token(bytea) FROM %I, %I', db || '_app', db || '_worker');
  EXECUTE format('GRANT EXECUTE ON FUNCTION resolve_confirmation_token(bytea) TO %I', db || '_app');
END $$;

-- =================================================================================================================
-- 6. Shipments
-- =================================================================================================================

CREATE TABLE shipments (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  order_id uuid NOT NULL,
  connection_id uuid, -- opaque ref: integrations.integration_connections
  tracking_number text,
  carrier_label_url text,
  status text NOT NULL DEFAULT 'requested' CHECK (status IN (
    'requested', 'created', 'creation_failed', 'picked_up', 'in_transit', 'out_for_delivery',
    'delivered', 'failed', 'returned', 'cancelled'
  )),
  requested_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  FOREIGN KEY (business_id, order_id) REFERENCES orders (business_id, id)
);
CREATE UNIQUE INDEX ux_shipments_tracking ON shipments (business_id, tracking_number) NULLS NOT DISTINCT;
CREATE UNIQUE INDEX ux_shipments_one_active ON shipments (business_id, order_id)
  WHERE status NOT IN ('delivered', 'failed', 'returned', 'cancelled', 'creation_failed');
CREATE INDEX ix_shipments_order ON shipments (business_id, order_id);
CREATE INDEX ix_shipments_stale ON shipments (business_id, updated_at) WHERE status NOT IN ('delivered', 'failed', 'returned', 'cancelled', 'creation_failed');
SELECT app.add_updated_at_trigger('shipments');
SELECT app.enable_tenant_rls('shipments');

CREATE TABLE shipment_events (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  shipment_id uuid NOT NULL,
  event_type text NOT NULL,
  is_anomaly boolean NOT NULL DEFAULT false,
  integration_event_id uuid, -- opaque pointer back to the raw webhook payload (integrations)
  external_event_id text,
  resolved_at timestamptz,
  resolution_note text,
  occurred_at timestamptz NOT NULL,
  PRIMARY KEY (id, occurred_at),
  FOREIGN KEY (business_id, shipment_id) REFERENCES shipments (business_id, id)
) PARTITION BY RANGE (occurred_at);
CREATE UNIQUE INDEX ux_shipment_events_dedup ON shipment_events (business_id, shipment_id, external_event_id, occurred_at) WHERE external_event_id IS NOT NULL;
CREATE INDEX ix_shipment_events_timeline ON shipment_events (business_id, shipment_id, occurred_at);
CREATE INDEX ix_shipment_events_anomalies ON shipment_events (business_id, occurred_at) WHERE is_anomaly AND resolved_at IS NULL;
SELECT app.enable_tenant_rls('shipment_events');
SELECT app.make_append_only('shipment_events', ARRAY['resolved_at', 'resolution_note']);
SELECT app.ensure_monthly_partitions('shipment_events');

-- =================================================================================================================
-- 7. COD remittance reconciliation
-- =================================================================================================================

CREATE TABLE cod_remittances (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  reference text NOT NULL,
  carrier_connection_id uuid,
  total_amount numeric(12, 2) NOT NULL CHECK (total_amount >= 0),
  status text NOT NULL DEFAULT 'imported' CHECK (status IN ('imported', 'reconciled', 'disputed')),
  imported_at timestamptz NOT NULL DEFAULT now(),
  reconciled_at timestamptz,
  UNIQUE (business_id, id)
);
CREATE UNIQUE INDEX ux_cod_remittances_reference ON cod_remittances (business_id, reference);
CREATE INDEX ix_cod_remittances_list ON cod_remittances (business_id, imported_at DESC);
SELECT app.enable_tenant_rls('cod_remittances');

CREATE TABLE cod_remittance_lines (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  remittance_id uuid NOT NULL,
  tracking_number text NOT NULL,
  shipment_id uuid, -- resolved by tracking_number match; nullable until matched
  amount numeric(12, 2) NOT NULL CHECK (amount >= 0),
  status text NOT NULL DEFAULT 'unmatched' CHECK (status IN ('unmatched', 'matched', 'disputed')),
  imported_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, remittance_id) REFERENCES cod_remittances (business_id, id),
  FOREIGN KEY (business_id, shipment_id) REFERENCES shipments (business_id, id)
);
CREATE INDEX ix_crl_remittance ON cod_remittance_lines (business_id, remittance_id);
CREATE INDEX ix_crl_shipment ON cod_remittance_lines (business_id, shipment_id);
CREATE UNIQUE INDEX ux_crl_settled_once ON cod_remittance_lines (business_id, shipment_id) WHERE status = 'matched'; -- a parcel is paid once
SELECT app.enable_tenant_rls('cod_remittance_lines');

-- =================================================================================================================
-- 8. Returns
-- =================================================================================================================

CREATE TABLE return_reason_codes (
  key text PRIMARY KEY,
  fault_class text NOT NULL CHECK (fault_class IN ('customer', 'business', 'carrier', 'unknown')), -- verbatim vocabulary, V1 spec §4.7
  label_ar text NOT NULL,
  label_fr text NOT NULL,
  label_en text NOT NULL
);
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('GRANT SELECT ON return_reason_codes TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');
  EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON return_reason_codes FROM %I, %I', db || '_app', db || '_worker');
END $$;

-- Status vocabulary, refused_at_door, cost_amount, evidence_file_id, received_at: verbatim from V1 spec §5.7/4.7
-- (return_cases, return_reason_codes). "Mark received" is an explicit agent action, followed by a restock
-- decision (restocked | written_off); fault may be changed later with a justification (spec §5.7) — not
-- modelled as a separate column here, tracked via return_case_history.note instead.
CREATE TABLE return_cases (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  order_id uuid NOT NULL,
  shipment_id uuid,
  reason_code text NOT NULL REFERENCES return_reason_codes (key),
  fault_class text NOT NULL, -- copied from reason_code at open time; audit stays stable even if the catalogue changes later
  refused_at_door boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'received', 'restocked', 'written_off', 'disputed')),
  cost_amount numeric(12, 2) CHECK (cost_amount >= 0), -- return shipping + lost fees, for analytics
  evidence_file_id uuid,
  received_at timestamptz,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  UNIQUE (business_id, order_id), -- 0..1 per order
  FOREIGN KEY (business_id, order_id) REFERENCES orders (business_id, id),
  FOREIGN KEY (business_id, shipment_id) REFERENCES shipments (business_id, id),
  FOREIGN KEY (business_id, evidence_file_id) REFERENCES app.files (business_id, id),
  CHECK (status NOT IN ('restocked', 'written_off') OR closed_at IS NOT NULL),
  CHECK (status NOT IN ('received', 'restocked', 'written_off') OR received_at IS NOT NULL) -- "received" is the explicit Mark-received action; disputed may happen before or after
);
CREATE INDEX ix_return_cases_list ON return_cases (business_id, status, opened_at DESC);
CREATE INDEX ix_return_cases_shipment ON return_cases (business_id, shipment_id);
SELECT app.add_updated_at_trigger('return_cases');
SELECT app.enable_tenant_rls('return_cases');

CREATE TABLE return_case_history (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  return_case_id uuid NOT NULL,
  from_status text,
  to_status text NOT NULL,
  note text,
  actor_member_id uuid,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, return_case_id) REFERENCES return_cases (business_id, id)
);
CREATE INDEX ix_rch_case ON return_case_history (business_id, return_case_id, recorded_at);
SELECT app.enable_tenant_rls('return_case_history');
SELECT app.make_append_only('return_case_history', '{}'); -- low volume; not partitioned (doc §9)

-- Return cases reuse the same transitions table (machine='return') rather than a second bespoke mechanism.
-- Simplified versus the order/cash pair: validation and logging happen together in one AFTER trigger (no
-- deferred pair needed — a return case has one status column and no second coupled machine to reconcile).
CREATE OR REPLACE FUNCTION guard_return_case_edge() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_from text := CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.status END;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM order_status_transitions
     WHERE machine = 'return' AND from_status IS NOT DISTINCT FROM v_from AND to_status = NEW.status
  ) THEN
    RAISE EXCEPTION 'ORDER_ILLEGAL_TRANSITION: return % -> % not a legal edge', v_from, NEW.status USING ERRCODE = '55000';
  END IF;
  INSERT INTO return_case_history (business_id, return_case_id, from_status, to_status)
  VALUES (NEW.business_id, NEW.id, v_from, NEW.status);
  RETURN NEW;
END;
$$;
-- Split in two: a trigger WHEN clause cannot reference TG_OP, only OLD/NEW columns.
CREATE TRIGGER trg_return_case_edge_ins AFTER INSERT ON return_cases
FOR EACH ROW EXECUTE FUNCTION guard_return_case_edge();
CREATE TRIGGER trg_return_case_edge_upd AFTER UPDATE OF status ON return_cases
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION guard_return_case_edge();

-- =================================================================================================================
-- 9. Per-tenant settings and policy
-- =================================================================================================================

CREATE TABLE order_settings (
  business_id uuid PRIMARY KEY,
  order_number_prefix text NOT NULL DEFAULT '',
  confirmation_link_ttl_hours int NOT NULL DEFAULT 48,
  max_confirmation_attempts int NOT NULL DEFAULT 3,
  risk_policy jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT app.add_updated_at_trigger('order_settings');
SELECT app.enable_tenant_rls('order_settings');

CREATE TABLE risk_policy_rules (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  tier text NOT NULL CHECK (tier IN ('A', 'B', 'C', 'D', 'unscored')),
  action text NOT NULL CHECK (action IN ('none', 'extra_call', 'stopdesk_only', 'deposit_required', 'manual_review')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_risk_policy_rules ON risk_policy_rules (business_id, tier);
SELECT app.add_updated_at_trigger('risk_policy_rules');
SELECT app.enable_tenant_rls('risk_policy_rules');

CREATE TABLE delivery_fee_rates (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  delivery_mode text NOT NULL CHECK (delivery_mode IN ('home', 'stopdesk')),
  wilaya_code text, -- NULL = default fallback
  fee_amount numeric(12, 2) NOT NULL CHECK (fee_amount >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_delivery_fee_rates ON delivery_fee_rates (business_id, delivery_mode, wilaya_code) NULLS NOT DISTINCT;
SELECT app.add_updated_at_trigger('delivery_fee_rates');
SELECT app.enable_tenant_rls('delivery_fee_rates');

-- =================================================================================================================
-- 10. Read models (event-fed; no FK by design — async, rebuildable)
-- =================================================================================================================

CREATE TABLE rm_contacts (
  business_id uuid NOT NULL,
  contact_id uuid NOT NULL,
  display_name text,
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, contact_id)
);
SELECT app.enable_tenant_rls('rm_contacts');

CREATE TABLE rm_contact_phones (
  business_id uuid NOT NULL,
  contact_id uuid NOT NULL,
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  phone_e164 text,
  is_primary boolean NOT NULL DEFAULT false,
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, contact_id, phone_hash)
);
CREATE INDEX ix_rm_contact_phones_contact ON rm_contact_phones (business_id, contact_id);
SELECT app.enable_tenant_rls('rm_contact_phones');

CREATE TABLE rm_score_tiers (
  business_id uuid NOT NULL,
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  tier text NOT NULL,
  confidence text NOT NULL CHECK (confidence IN ('none', 'low', 'medium', 'high')),
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, phone_hash)
);
SELECT app.enable_tenant_rls('rm_score_tiers');

-- =================================================================================================================
-- 11. Grants — no DELETE on orders/money/returns/products anywhere, not even revoked column-by-column
-- =================================================================================================================

DO $$ DECLARE db text := current_database(); app_r text := current_database() || '_app'; BEGIN
  EXECUTE format(
    'REVOKE DELETE ON orders, products, product_variants, confirmation_requests, shipments, cod_remittances, cod_remittance_lines, return_cases FROM %I',
    app_r);
END $$;

-- V0001__initial.sql — crm schema (docs/02-data/crm.md). 20 tables, all tenant-scoped with FORCE RLS; every
-- in-service FK is composite (business_id, ...) against UNIQUE (business_id, id) — X3, no exceptions, including
-- self-references (contacts.merged_into).
-- Roles: standard trio only (crm_app/_worker/_admin), no roles.conf extras.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =================================================================================================================
-- 1. Core contact graph
-- =================================================================================================================

CREATE TABLE contacts (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('person', 'organization')),
  full_name text,
  company_name text,
  job_title text,
  email text,
  email_lower text GENERATED ALWAYS AS (lower(email)) STORED,
  preferred_language text NOT NULL DEFAULT 'ar' CHECK (preferred_language IN ('ar', 'fr')),
  client_user_id uuid, -- opaque ref: identity_access.users
  owner_member_id uuid, -- opaque ref: identity_access.business_members
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'api', 'shopify', 'woocommerce')),
  import_job_id uuid, -- opaque ref: integrations.import_jobs
  search_text text,
  custom_fields jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_interaction_at timestamptz,
  merged_into uuid,
  merged_at timestamptz,
  anonymised_at timestamptz,
  deleted_at timestamptz,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  FOREIGN KEY (business_id, merged_into) REFERENCES contacts (business_id, id),
  CHECK (anonymised_at IS NULL OR (full_name IS NULL AND company_name IS NULL AND email IS NULL)) -- ck_contacts_anonymised
);
CREATE INDEX ix_contacts_last_interaction ON contacts (business_id, last_interaction_at DESC) WHERE deleted_at IS NULL AND anonymised_at IS NULL;
CREATE INDEX ix_contacts_search_trgm ON contacts USING gin (search_text gin_trgm_ops) WHERE deleted_at IS NULL; -- D13: no business_id prefix (R1 open)
CREATE INDEX ix_contacts_owner ON contacts (business_id, owner_member_id);
CREATE INDEX ix_contacts_email ON contacts (business_id, email_lower);
CREATE INDEX ix_contacts_client_user ON contacts (business_id, client_user_id) WHERE client_user_id IS NOT NULL;
SELECT app.add_updated_at_trigger('contacts');
SELECT app.enable_tenant_rls('contacts');

CREATE TABLE contact_phones (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  contact_id uuid NOT NULL,
  phone_raw text NOT NULL,
  phone_e164 text NOT NULL CHECK (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  is_primary boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'wrong_number', 'invalid')),
  line_type text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, contact_id) REFERENCES contacts (business_id, id)
);
CREATE UNIQUE INDEX uq_contact_phones_e164 ON contact_phones (business_id, phone_e164);
CREATE UNIQUE INDEX ux_contact_phones_primary ON contact_phones (business_id, contact_id) WHERE is_primary;
CREATE INDEX ix_contact_phones_contact ON contact_phones (business_id, contact_id);
CREATE INDEX ix_contact_phones_hash ON contact_phones (business_id, phone_hash);
CREATE INDEX ix_contact_phones_e164_trgm ON contact_phones USING gin (phone_e164 gin_trgm_ops);
SELECT app.add_updated_at_trigger('contact_phones');
SELECT app.enable_tenant_rls('contact_phones');

CREATE TABLE contact_addresses (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  contact_id uuid NOT NULL,
  geo_dataset_version int,
  wilaya_code text,
  commune_code text,
  landmark text,
  address_text text,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, contact_id) REFERENCES contacts (business_id, id),
  FOREIGN KEY (geo_dataset_version, commune_code, wilaya_code) REFERENCES ref.communes (dataset_version, code, wilaya_code)
);
CREATE UNIQUE INDEX ux_contact_addresses_default ON contact_addresses (business_id, contact_id) WHERE is_default;
CREATE INDEX ix_contact_addresses_contact ON contact_addresses (business_id, contact_id);
SELECT app.add_updated_at_trigger('contact_addresses');
SELECT app.enable_tenant_rls('contact_addresses');

CREATE TABLE contact_relationships (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  from_contact_id uuid NOT NULL,
  to_contact_id uuid NOT NULL,
  relationship_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, from_contact_id) REFERENCES contacts (business_id, id),
  FOREIGN KEY (business_id, to_contact_id) REFERENCES contacts (business_id, id)
);
CREATE UNIQUE INDEX uq_contact_rel ON contact_relationships (business_id, from_contact_id, to_contact_id, relationship_type);
CREATE INDEX ix_contact_rel_to ON contact_relationships (business_id, to_contact_id);
SELECT app.enable_tenant_rls('contact_relationships');

CREATE TABLE tags (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id)
);
CREATE UNIQUE INDEX ux_tags_name ON tags (business_id, name);
SELECT app.enable_tenant_rls('tags');

CREATE TABLE contact_tags (
  business_id uuid NOT NULL,
  contact_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, contact_id, tag_id),
  FOREIGN KEY (business_id, contact_id) REFERENCES contacts (business_id, id),
  FOREIGN KEY (business_id, tag_id) REFERENCES tags (business_id, id)
);
CREATE INDEX ix_contact_tags_tag ON contact_tags (business_id, tag_id);
SELECT app.enable_tenant_rls('contact_tags');

CREATE TABLE custom_field_definitions (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  entity text NOT NULL CHECK (entity IN ('contact', 'opportunity')),
  key text NOT NULL,
  label text NOT NULL,
  field_type text NOT NULL CHECK (field_type IN ('text', 'number', 'date', 'boolean', 'select')),
  options jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_custom_field_key ON custom_field_definitions (business_id, entity, key);
SELECT app.enable_tenant_rls('custom_field_definitions');

-- Append-only except loser_snapshot/redacted_at (erasure can redact a merge record's snapshot, D9 pattern).
CREATE TABLE contact_merges (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  survivor_contact_id uuid NOT NULL,
  loser_contact_id uuid NOT NULL,
  loser_snapshot jsonb NOT NULL,
  merged_by_member_id uuid,
  merged_at timestamptz NOT NULL DEFAULT now(),
  redacted_at timestamptz,
  FOREIGN KEY (business_id, survivor_contact_id) REFERENCES contacts (business_id, id),
  FOREIGN KEY (business_id, loser_contact_id) REFERENCES contacts (business_id, id)
);
CREATE INDEX ix_contact_merges_survivor ON contact_merges (business_id, survivor_contact_id);
SELECT app.enable_tenant_rls('contact_merges');
SELECT app.make_append_only('contact_merges', ARRAY['loser_snapshot', 'redacted_at']);

CREATE TABLE contact_erasures (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  contact_id uuid NOT NULL,
  erased_by_member_id uuid,
  erased_at timestamptz NOT NULL DEFAULT now(),
  reason text,
  FOREIGN KEY (business_id, contact_id) REFERENCES contacts (business_id, id)
);
SELECT app.enable_tenant_rls('contact_erasures');
SELECT app.make_append_only('contact_erasures', '{}');

-- =================================================================================================================
-- 2. Pipelines and opportunities
-- =================================================================================================================

CREATE TABLE pipelines (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  name text NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id)
);
CREATE UNIQUE INDEX uq_pipelines_name ON pipelines (business_id, name);
CREATE UNIQUE INDEX ux_pipelines_default ON pipelines (business_id) WHERE is_default;
SELECT app.enable_tenant_rls('pipelines');

CREATE TABLE pipeline_stages (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  pipeline_id uuid NOT NULL,
  name text NOT NULL,
  system_key text, -- UI translation of seeded stages (D11)
  stage_type text NOT NULL CHECK (stage_type IN ('open', 'won', 'lost')),
  sort_order int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, pipeline_id, id), -- composite-FK target from opportunities
  UNIQUE (business_id, pipeline_id, id, stage_type), -- declarative "status must match stage type" target
  FOREIGN KEY (business_id, pipeline_id) REFERENCES pipelines (business_id, id)
);
ALTER TABLE pipeline_stages ADD CONSTRAINT uq_pipeline_stages_order UNIQUE (business_id, pipeline_id, sort_order) DEFERRABLE INITIALLY IMMEDIATE;
SELECT app.enable_tenant_rls('pipeline_stages');

CREATE TABLE opportunities (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  contact_id uuid NOT NULL,
  pipeline_id uuid NOT NULL,
  stage_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('open', 'won', 'lost')),
  title text NOT NULL,
  value_amount numeric(12, 2) CHECK (value_amount >= 0),
  currency char(3) NOT NULL DEFAULT 'DZD',
  owner_member_id uuid,
  order_id uuid, -- opaque ref: orders.orders
  won_at timestamptz,
  lost_at timestamptz,
  lost_reason text,
  custom_fields jsonb NOT NULL DEFAULT '{}'::jsonb,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  FOREIGN KEY (business_id, contact_id) REFERENCES contacts (business_id, id),
  -- Declarative opportunity rule (spec §5.3): status must match the stage's own type, and the stage must
  -- actually belong to the pipeline — one FK enforces both.
  FOREIGN KEY (business_id, pipeline_id, stage_id, status) REFERENCES pipeline_stages (business_id, pipeline_id, id, stage_type),
  CONSTRAINT ck_opportunities_state CHECK (
    (status = 'open' AND won_at IS NULL AND lost_at IS NULL AND lost_reason IS NULL) OR
    (status = 'won' AND won_at IS NOT NULL AND lost_at IS NULL) OR
    (status = 'lost' AND lost_at IS NOT NULL AND lost_reason IS NOT NULL AND won_at IS NULL)
  )
);
CREATE INDEX ix_opportunities_board ON opportunities (business_id, pipeline_id, stage_id) WHERE status = 'open';
CREATE INDEX ix_opportunities_contact ON opportunities (business_id, contact_id);
CREATE UNIQUE INDEX ux_opportunities_order ON opportunities (business_id, order_id) WHERE order_id IS NOT NULL;
SELECT app.add_updated_at_trigger('opportunities');
SELECT app.enable_tenant_rls('opportunities');

CREATE TABLE opportunity_stage_changes (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  opportunity_id uuid NOT NULL,
  from_stage_id uuid,
  to_stage_id uuid NOT NULL,
  changed_by_member_id uuid,
  changed_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, opportunity_id) REFERENCES opportunities (business_id, id)
);
CREATE INDEX ix_opp_stage_changes_opp ON opportunity_stage_changes (business_id, opportunity_id, changed_at);
SELECT app.enable_tenant_rls('opportunity_stage_changes');
SELECT app.make_append_only('opportunity_stage_changes', '{}'); -- small per-opportunity history; not one of CLAUDE.md §4's named large tables, so no partitioning

-- =================================================================================================================
-- 3. Tasks
-- =================================================================================================================

CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  contact_id uuid,
  opportunity_id uuid,
  assignee_member_id uuid,
  title text NOT NULL,
  notes text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'done', 'cancelled')),
  source_interaction_id uuid, -- documented ref into the partitioned interactions (no FK)
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  FOREIGN KEY (business_id, contact_id) REFERENCES contacts (business_id, id),
  FOREIGN KEY (business_id, opportunity_id) REFERENCES opportunities (business_id, id)
);
CREATE INDEX ix_tasks_assignee_open ON tasks (business_id, assignee_member_id, due_at) WHERE status = 'open';
CREATE INDEX ix_tasks_contact ON tasks (business_id, contact_id);
CREATE INDEX ix_tasks_opportunity ON tasks (business_id, opportunity_id);
CREATE UNIQUE INDEX ux_tasks_source_interaction ON tasks (business_id, source_interaction_id) WHERE source_interaction_id IS NOT NULL;
SELECT app.add_updated_at_trigger('tasks');
SELECT app.enable_tenant_rls('tasks');

-- =================================================================================================================
-- 4. Timeline (partitioned)
-- =================================================================================================================

CREATE TABLE interactions (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  contact_id uuid,
  opportunity_id uuid,
  order_id uuid, -- opaque ref: orders.orders
  type text NOT NULL CHECK (type IN ('call', 'whatsapp', 'sms', 'email', 'chat', 'system', 'note')),
  summary text,
  payload jsonb,
  source_event_id uuid,
  external_message_id text,
  redacted_at timestamptz,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);
CREATE INDEX ix_interactions_contact ON interactions (business_id, contact_id, occurred_at DESC);
CREATE INDEX ix_interactions_opportunity ON interactions (business_id, opportunity_id, occurred_at DESC);
CREATE INDEX ix_interactions_order ON interactions (business_id, order_id, occurred_at DESC);
CREATE UNIQUE INDEX ux_interactions_source_event ON interactions (source_event_id, occurred_at) WHERE source_event_id IS NOT NULL;
CREATE UNIQUE INDEX ux_interactions_external_msg ON interactions (external_message_id, occurred_at) WHERE external_message_id IS NOT NULL;
SELECT app.enable_tenant_rls('interactions');
SELECT app.make_append_only('interactions', ARRAY['contact_id', 'summary', 'payload', 'redacted_at']);
SELECT app.ensure_monthly_partitions('interactions');

CREATE TABLE call_attempt_groups (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  contact_id uuid,
  order_id uuid, -- opaque ref: orders.orders
  purpose text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  attempt_count int NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, contact_id) REFERENCES contacts (business_id, id),
  UNIQUE (business_id, id)
);
CREATE UNIQUE INDEX ux_call_attempt_groups_open_order ON call_attempt_groups (business_id, order_id, purpose) WHERE status = 'open';
CREATE INDEX ix_call_attempt_groups_contact ON call_attempt_groups (business_id, contact_id);
SELECT app.add_updated_at_trigger('call_attempt_groups');
SELECT app.enable_tenant_rls('call_attempt_groups');

CREATE TABLE call_logs (
  interaction_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL, -- same value as the matching interactions row (D8); partition key
  business_id uuid NOT NULL,
  attempt_group_id uuid NOT NULL,
  attempt_no int NOT NULL CHECK (attempt_no > 0),
  contact_phone_id uuid,
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  disposition text NOT NULL CHECK (disposition IN ('answered', 'unreachable', 'wrong_number', 'busy', 'no_answer')),
  outcome text,
  answered_at timestamptz,
  telemetry_source text,
  order_id uuid, -- opaque ref: orders.orders
  redacted_at timestamptz,
  PRIMARY KEY (interaction_id, occurred_at),
  FOREIGN KEY (business_id, attempt_group_id) REFERENCES call_attempt_groups (business_id, id),
  CHECK ((disposition = 'answered') = (outcome IS NOT NULL AND answered_at IS NOT NULL)) -- call rule, spec §5.4
) PARTITION BY RANGE (occurred_at);
CREATE INDEX ix_call_logs_group ON call_logs (business_id, attempt_group_id, attempt_no);
SELECT app.enable_tenant_rls('call_logs');
SELECT app.make_append_only('call_logs', ARRAY['contact_phone_id', 'phone_hash', 'redacted_at']);
SELECT app.ensure_monthly_partitions('call_logs');

-- Next call_attempt_groups.attempt_no, serialised with a row lock (D7 — a partitioned call_logs cannot hold a
-- global UNIQUE on attempt_no, so the counter lives on the (non-partitioned) group row instead).
CREATE OR REPLACE FUNCTION next_call_attempt_no(p_business_id uuid, p_group_id uuid) RETURNS int
LANGUAGE plpgsql AS $$
DECLARE v_next int;
BEGIN
  UPDATE call_attempt_groups SET attempt_count = attempt_count + 1
   WHERE business_id = p_business_id AND id = p_group_id
   RETURNING attempt_count INTO v_next;
  IF v_next IS NULL THEN
    RAISE EXCEPTION 'next_call_attempt_no: group % not found for business %', p_group_id, p_business_id;
  END IF;
  RETURN v_next;
END;
$$;

-- =================================================================================================================
-- 5. Read models (event-fed, upsert with a source_version guard; natural keys, D14; no FK by design — async)
-- =================================================================================================================

CREATE TABLE contact_orders (
  business_id uuid NOT NULL,
  order_id uuid NOT NULL, -- opaque ref: orders.orders
  contact_id uuid,
  status text NOT NULL,
  total_amount numeric(12, 2),
  currency char(3) NOT NULL DEFAULT 'DZD',
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, order_id)
);
CREATE INDEX ix_contact_orders_contact ON contact_orders (business_id, contact_id);
SELECT app.enable_tenant_rls('contact_orders');

-- C2 fix: the tenant layer only — layer is structurally pinned to 'tenant', so a global row can never be stored
-- here even by a future bug; reason_codes may be populated because this IS the tenant layer (CLAUDE.md §5 allows
-- detail there).
CREATE TABLE contact_score_cache (
  business_id uuid NOT NULL,
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  layer text NOT NULL DEFAULT 'tenant' CHECK (layer = 'tenant'),
  tier text NOT NULL,
  confidence text NOT NULL CHECK (confidence IN ('none', 'low', 'medium', 'high')), -- E2 tenant vocabulary
  reason_codes jsonb,
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, phone_hash),
  CONSTRAINT ck_contact_score_cache_no_global_reasons CHECK (layer = 'tenant' OR reason_codes IS NULL)
);
CREATE INDEX ix_contact_score_cache_tier ON contact_score_cache (business_id, tier);
SELECT app.enable_tenant_rls('contact_score_cache');

CREATE TABLE member_refs (
  business_id uuid NOT NULL,
  member_id uuid NOT NULL, -- opaque ref: identity_access.business_members
  display_name text,
  role text,
  status text,
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, member_id)
);
SELECT app.enable_tenant_rls('member_refs');

-- =================================================================================================================
-- 6. Helper functions (SECURITY INVOKER — no bridge needed, every caller already has a tenant context)
-- =================================================================================================================

CREATE OR REPLACE FUNCTION create_default_pipeline(p_business_id uuid) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE v_pipeline_id uuid; v_business uuid := app.current_business_id();
BEGIN
  IF v_business IS NULL OR v_business <> p_business_id THEN
    RAISE EXCEPTION 'create_default_pipeline: no matching tenant context' USING ERRCODE = '55000';
  END IF;

  INSERT INTO pipelines (business_id, name, is_default) VALUES (p_business_id, 'Default', true)
  RETURNING id INTO v_pipeline_id;

  INSERT INTO pipeline_stages (business_id, pipeline_id, name, system_key, stage_type, sort_order) VALUES
    (p_business_id, v_pipeline_id, 'New', 'new', 'open', 1),
    (p_business_id, v_pipeline_id, 'Contacted', 'contacted', 'open', 2),
    (p_business_id, v_pipeline_id, 'Confirmed', 'confirmed', 'open', 3),
    (p_business_id, v_pipeline_id, 'Won', 'won', 'won', 4),
    (p_business_id, v_pipeline_id, 'Lost', 'lost', 'lost', 5);

  RETURN v_pipeline_id;
END;
$$;

-- Structural erasure (CLAUDE.md §4.1 / §5 "erasure = structural" pattern): deletes phones/addresses/relationships
-- and now-unused score-cache rows, redacts interactions/call_logs/tasks/opportunity titles/merge snapshots,
-- anonymises the contact, and writes one contact_erasures row. Caller adds app.audit_log + the outbox event.
CREATE OR REPLACE FUNCTION erase_contact(p_business_id uuid, p_contact_id uuid, p_erased_by uuid, p_reason text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_business uuid := app.current_business_id();
BEGIN
  IF v_business IS NULL OR v_business <> p_business_id THEN
    RAISE EXCEPTION 'erase_contact: no matching tenant context' USING ERRCODE = '55000';
  END IF;

  DELETE FROM contact_phones WHERE business_id = p_business_id AND contact_id = p_contact_id;
  DELETE FROM contact_addresses WHERE business_id = p_business_id AND contact_id = p_contact_id;
  DELETE FROM contact_relationships WHERE business_id = p_business_id AND (from_contact_id = p_contact_id OR to_contact_id = p_contact_id);
  -- contact_score_cache is keyed by phone_hash, not contact_id (it's a shared read model, not contact-owned) —
  -- nothing to do here; it ages out naturally once no contact_phones row references that hash.

  UPDATE interactions SET contact_id = NULL, summary = NULL, payload = NULL, redacted_at = now()
   WHERE business_id = p_business_id AND contact_id = p_contact_id;
  UPDATE call_logs SET contact_phone_id = NULL, phone_hash = decode(repeat('00', 32), 'hex'), redacted_at = now()
   WHERE business_id = p_business_id AND attempt_group_id IN (
     SELECT id FROM call_attempt_groups WHERE business_id = p_business_id AND contact_id = p_contact_id
   );
  UPDATE tasks SET title = '(erased)', notes = NULL WHERE business_id = p_business_id AND contact_id = p_contact_id;
  UPDATE opportunities SET title = '(erased)' WHERE business_id = p_business_id AND contact_id = p_contact_id;
  UPDATE contact_merges SET loser_snapshot = '{}'::jsonb, redacted_at = now()
   WHERE business_id = p_business_id AND (survivor_contact_id = p_contact_id OR loser_contact_id = p_contact_id);

  UPDATE contacts SET full_name = NULL, company_name = NULL, job_title = NULL, email = NULL,
                       search_text = NULL, custom_fields = '{}'::jsonb, anonymised_at = now()
   WHERE business_id = p_business_id AND id = p_contact_id;

  INSERT INTO contact_erasures (business_id, contact_id, erased_by_member_id, reason)
  VALUES (p_business_id, p_contact_id, p_erased_by, p_reason);
END;
$$;

-- V0001__initial.sql — Scoring service schema (CLAUDE.md §5; docs/02-data/scoring.md).
-- Implements the 2026-11-20 review fixes (docs/02-data/reviews/2026-11-20-phase2-review.md, rows S1-S16, X1-X7,
-- E2) on top of the original design. Edited in place per the fix-round brief — no V0002.
--
-- Two planes in one database: `public` = tenant plane (business_id + RLS). `net` = global plane; scoring_app has
-- NO USAGE on this schema at all — the only bridge is the SECURITY DEFINER functions defined in `public`.
--
-- Runtime roles (role suffixes declared in Database/roles.conf: engine, portal):
--   scoring_app      Scoring.Api (gRPC GetScore/BatchGetScore). SELECT on its own tenant rows (RLS) on the 4
--                    public tables minus the writes default privileges granted (revoked below); EXECUTE
--                    public.lookup_score only. Nothing in net, no writes anywhere (S9).
--   scoring_engine   Scoring.Worker (consumers, recompute, nightly decay, DSR execution, erasure). Explicit
--                    grants only, NOBYPASSRLS, sets tenant from the event envelope.
--   scoring_portal   owner self-view OTP portal. EXECUTE on the 5 owner_* functions only; no table grants at
--                    all — those functions are SECURITY DEFINER and do their own writes as the migrator.
--   scoring_admin    web-master console: SELECT across net for review queues; mutations only through the
--                    admin_* SECURITY DEFINER functions (dispute resolution, legal holds, DSR progression,
--                    model activation, pepper rotation) — never raw UPDATE on a state-machine table.
--   scoring_migrator owner; definer of every function below.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gen_random_bytes/digest for OTP session tokens (trusted extension)

CREATE SCHEMA IF NOT EXISTS net;

DO $$ DECLARE db text := current_database(); BEGIN
  -- net is invisible to scoring_app and scoring_portal (S9): no USAGE grant for either, ever.
  EXECUTE format('GRANT USAGE ON SCHEMA net TO %I, %I', db || '_engine', db || '_admin');
END $$;

-- =================================================================================================================
-- 1. Global plane (net) — platform tables, no business_id-scoped RLS (00-conventions §4)
-- =================================================================================================================

CREATE TABLE net.pepper_versions (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  version int NOT NULL,
  status text NOT NULL CHECK (status IN ('active', 'retired')),
  activated_at timestamptz NOT NULL DEFAULT now(),
  retired_at timestamptz
);
CREATE UNIQUE INDEX ux_pepper_versions_one_active ON net.pepper_versions (status) WHERE status = 'active';
CREATE UNIQUE INDEX ux_pepper_versions_version ON net.pepper_versions (version);
COMMENT ON TABLE net.pepper_versions IS 'Tracks pepper rotation (S16). The pepper VALUE itself lives only in the secret store, never here.';

CREATE TABLE net.phone_identities (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  pepper_version int NOT NULL REFERENCES net.pepper_versions (version),
  current_epoch int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_phone_identities_hash ON net.phone_identities (phone_hash);
COMMENT ON TABLE net.phone_identities IS 'phone_hash = HMAC-SHA256(pepper, E.164 phone). No raw phone ever stored (CLAUDE.md §5).';

CREATE TABLE net.erasure_suppressions (
  phone_hash bytea PRIMARY KEY CHECK (octet_length(phone_hash) = 32),
  mode text NOT NULL CHECK (mode IN ('erase', 'pseudonymise')),
  suppressed_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE net.erasure_suppressions IS 'S11 fix: once a phone_hash is erased, trg_phone_identities_suppression refuses to recreate it, so a later event cannot resurrect purged data.';

CREATE OR REPLACE FUNCTION net.guard_erasure_suppression() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM net.erasure_suppressions WHERE phone_hash = NEW.phone_hash) THEN
    RAISE EXCEPTION 'phone_identities: phone_hash is under an erasure suppression' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_phone_identities_suppression BEFORE INSERT ON net.phone_identities
FOR EACH ROW EXECUTE FUNCTION net.guard_erasure_suppression();

CREATE TABLE net.phone_epochs (
  id uuid NOT NULL DEFAULT uuidv7(),
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  epoch int NOT NULL,
  reason text NOT NULL CHECK (reason IN ('initial', 'recycle_inactivity', 'recycle_owner_claim')),
  started_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (phone_identity_id, epoch)
);
COMMENT ON TABLE net.phone_epochs IS 'Recycled-number resets. Lookups are refused when the merchant''s known_phones row predates the current epoch''s started_at.';

CREATE TABLE net.score_models (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  version text NOT NULL,
  status text NOT NULL CHECK (status IN ('draft', 'active', 'retired')) DEFAULT 'draft',
  params jsonb NOT NULL,
  params_sha256 bytea NOT NULL,
  active_from timestamptz,
  retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  -- S13 fix, NULL-safe: every provenance weight is a mandatory key, and carrier >= webhook >= manual always holds.
  CHECK (
    (params -> 'weights' ->> 'carrier_verified') IS NOT NULL AND
    (params -> 'weights' ->> 'webhook_verified') IS NOT NULL AND
    (params -> 'weights' ->> 'manual') IS NOT NULL AND
    (params ->> 'manual_negative_cap') IS NOT NULL AND
    (params ->> 'per_merchant_cap') IS NOT NULL AND
    (params -> 'weights' ->> 'carrier_verified')::numeric >= (params -> 'weights' ->> 'webhook_verified')::numeric AND
    (params -> 'weights' ->> 'webhook_verified')::numeric >= (params -> 'weights' ->> 'manual')::numeric
  )
);
CREATE UNIQUE INDEX ux_score_models_one_active ON net.score_models (status) WHERE status = 'active';
CREATE UNIQUE INDEX ux_score_models_version ON net.score_models (version);

CREATE TABLE net.settings (
  key text PRIMARY KEY,
  value_int bigint,
  value_text text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- X6 fix: a missing setting RAISES (fail closed) instead of silently returning NULL, which earlier read as
-- "no limit" at every call site.
CREATE OR REPLACE FUNCTION net.setting_int(p_key text) RETURNS bigint
LANGUAGE plpgsql STABLE AS $$
DECLARE v bigint;
BEGIN
  SELECT value_int INTO v FROM net.settings WHERE key = p_key;
  IF v IS NULL THEN
    RAISE EXCEPTION 'missing required setting: %', p_key USING ERRCODE = '55000';
  END IF;
  RETURN v;
END;
$$;

CREATE TABLE net.feature_flags (
  key text PRIMARY KEY,
  enabled boolean NOT NULL DEFAULT false,
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE net.feature_flags IS 'Read model of identity.feature_flag.changed (ADR-0005). global_score_visible defaults OFF if unknown (E3).';

CREATE OR REPLACE FUNCTION net.guard_version_column() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.source_version <= OLD.source_version THEN
    RAISE EXCEPTION '%: stale version % <= %', TG_TABLE_NAME, NEW.source_version, OLD.source_version USING ERRCODE = '40001';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_feature_flags_version BEFORE UPDATE ON net.feature_flags
FOR EACH ROW EXECUTE FUNCTION net.guard_version_column();

CREATE TABLE net.business_trust (
  business_id uuid PRIMARY KEY,
  trust_weight numeric(5, 4) NOT NULL DEFAULT 1.0 CHECK (trust_weight BETWEEN 0 AND 1),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'probation', 'flagged')), -- S5 DEFAULT
  manual_negative_count_30d int NOT NULL DEFAULT 0 CHECK (manual_negative_count_30d >= 0),
  source_version bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_business_trust_version BEFORE UPDATE ON net.business_trust
FOR EACH ROW EXECUTE FUNCTION net.guard_version_column();

CREATE TABLE net.phone_signals (
  id uuid NOT NULL DEFAULT uuidv7(),
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  phone_epoch int NOT NULL,
  business_id uuid, -- opaque ref, kept internal (D3) — never exposed to the global-layer lookup
  source_event_id uuid NOT NULL,
  signal_type text NOT NULL CHECK (signal_type IN (
    'call_answered', 'call_unreachable', 'call_wrong_number', 'identity_disclaimed',
    'confirmed', 'cancelled_after_confirmation',
    'delivered', 'refused_at_door', 'returned_customer_fault', 'returned_other_fault'
  )),
  provenance text NOT NULL CHECK (provenance IN ('carrier_verified', 'webhook_verified', 'manual')),
  weight numeric(6, 4) NOT NULL,
  model_version text NOT NULL REFERENCES net.score_models (version),
  occurred_at timestamptz NOT NULL,
  is_valid boolean NOT NULL DEFAULT true,
  invalid_reason text,
  invalidated_at timestamptz,
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE UNIQUE INDEX ux_phone_signals_source ON net.phone_signals (source_event_id, signal_type, occurred_at);
CREATE INDEX ix_phone_signals_phone ON net.phone_signals (phone_identity_id, occurred_at);
CREATE INDEX ix_phone_signals_business ON net.phone_signals (business_id, occurred_at);

-- Abuse table: "provenance weight forced from model by trigger" — caller-supplied weight is never trusted.
CREATE OR REPLACE FUNCTION net.derive_signal_weight() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE w numeric;
BEGIN
  SELECT (params -> 'weights' ->> NEW.provenance)::numeric INTO w FROM net.score_models WHERE version = NEW.model_version;
  IF w IS NULL THEN
    RAISE EXCEPTION 'score model % has no weight for provenance %', NEW.model_version, NEW.provenance USING ERRCODE = '55000';
  END IF;
  NEW.weight := w * (CASE WHEN NEW.signal_type = 'returned_other_fault' THEN 0 ELSE 1 END); -- carrier/merchant fault never counts
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_phone_signals_weight BEFORE INSERT ON net.phone_signals
FOR EACH ROW EXECUTE FUNCTION net.derive_signal_weight();

CREATE TABLE net.order_outcome_claims (
  order_id uuid PRIMARY KEY, -- opaque ref: orders.orders — one outcome per order (anti-sink)
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  business_id uuid NOT NULL,
  signal_id uuid NOT NULL,
  signal_occurred_at timestamptz NOT NULL, -- documented ref into the partitioned phone_signals (no FK)
  claimed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE net.phone_contributors (
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  phone_epoch int NOT NULL,
  business_id uuid NOT NULL,
  first_contribution_at timestamptz NOT NULL DEFAULT now(),
  eligible_at timestamptz NOT NULL, -- P5 DEFAULT: eligibility window, not immediate
  PRIMARY KEY (phone_identity_id, phone_epoch, business_id)
);

CREATE TABLE net.global_scores (
  phone_identity_id uuid PRIMARY KEY REFERENCES net.phone_identities (id),
  phone_epoch int NOT NULL,
  band text NOT NULL CHECK (band IN ('A', 'B', 'C', 'D', 'not_enough_data')),
  confidence text NOT NULL CHECK (confidence IN ('not_enough_data', 'low', 'high')), -- E2: global 2-label vocabulary
  effective_n int NOT NULL DEFAULT 0 CHECK (effective_n >= 0),
  model_version text NOT NULL REFERENCES net.score_models (version),
  computed_at timestamptz NOT NULL DEFAULT now(),
  frozen_until timestamptz, -- bounded, non-extendable (S4)
  version bigint NOT NULL DEFAULT 1,
  CHECK (confidence = 'not_enough_data' OR effective_n > 0) -- S12 fix
);

CREATE OR REPLACE FUNCTION net.guard_dispute_freeze() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.frozen_until IS NOT NULL AND OLD.frozen_until > now()
     AND (NEW.band IS DISTINCT FROM OLD.band OR NEW.confidence IS DISTINCT FROM OLD.confidence) THEN
    RAISE EXCEPTION 'global_scores: phone % is frozen until %', OLD.phone_identity_id, OLD.frozen_until USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_dispute_freeze BEFORE UPDATE ON net.global_scores
FOR EACH ROW EXECUTE FUNCTION net.guard_dispute_freeze(); -- fires before trg_global_scores_version (alphabetical)

CREATE OR REPLACE FUNCTION net.guard_score_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.version <= OLD.version THEN
    RAISE EXCEPTION 'global_scores: stale version % <= %', NEW.version, OLD.version USING ERRCODE = '40001';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_global_scores_version BEFORE UPDATE ON net.global_scores
FOR EACH ROW EXECUTE FUNCTION net.guard_score_version(); -- S7 fix: lost-update guard: pair with SELECT ... FOR UPDATE

CREATE TABLE net.global_score_history (
  id uuid NOT NULL DEFAULT uuidv7(),
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  phone_epoch int NOT NULL,
  band text NOT NULL,
  confidence text NOT NULL,
  effective_n int NOT NULL DEFAULT 0,
  model_version text NOT NULL REFERENCES net.score_models (version),
  params_sha256 bytea NOT NULL,
  computed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, computed_at)
) PARTITION BY RANGE (computed_at);
CREATE INDEX ix_global_score_history_phone ON net.global_score_history (phone_identity_id, computed_at);
CREATE INDEX ix_global_scores_computed ON net.global_scores (computed_at);

CREATE TABLE net.consents (
  id uuid NOT NULL DEFAULT uuidv7(),
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  purpose text NOT NULL CHECK (purpose IN ('global_scoring', 'otp_contact')),
  decision text NOT NULL CHECK (decision IN ('granted', 'withdrawn')),
  seq bigint NOT NULL,
  wording_text text NOT NULL,
  wording_sha256 bytea NOT NULL,
  evidence jsonb, -- ip, user agent — internal only (§8)
  effective_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, effective_at),
  UNIQUE (phone_identity_id, purpose, seq, effective_at)
) PARTITION BY RANGE (effective_at);
CREATE INDEX ix_consents_current ON net.consents (phone_identity_id, purpose, effective_at DESC);

-- S6 fix: strictly monotonic seq per (phone, purpose) — the latest row is always authoritative, so a withdrawal
-- (whoever recorded it) always wins over an earlier grant, and a merchant-declared grant can never override it.
CREATE OR REPLACE FUNCTION net.guard_consent_seq() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE max_seq bigint;
BEGIN
  SELECT max(seq) INTO max_seq FROM net.consents WHERE phone_identity_id = NEW.phone_identity_id AND purpose = NEW.purpose;
  IF max_seq IS NOT NULL AND NEW.seq <= max_seq THEN
    RAISE EXCEPTION 'consents: seq % not monotonic (max %)', NEW.seq, max_seq USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_consents_seq BEFORE INSERT ON net.consents
FOR EACH ROW EXECUTE FUNCTION net.guard_consent_seq();

CREATE TABLE net.disputes (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  signal_id uuid,                -- documented ref into the partitioned phone_signals (no FK); NULL = general dispute
  signal_occurred_at timestamptz,
  status text NOT NULL CHECK (status IN ('open', 'upheld', 'rejected')) DEFAULT 'open',
  reason_text text,              -- PII, internal only
  opened_via text NOT NULL CHECK (opened_via IN ('owner_otp', 'admin')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid,               -- opaque ref: identity-access user
  frozen_until timestamptz NOT NULL,
  due_at timestamptz NOT NULL
);
CREATE UNIQUE INDEX ux_disputes_active ON net.disputes (phone_identity_id, signal_id) NULLS NOT DISTINCT WHERE status = 'open';
CREATE INDEX ix_disputes_queue ON net.disputes (due_at) WHERE status = 'open';
CREATE INDEX ix_disputes_phone ON net.disputes (phone_identity_id, opened_at);

CREATE TABLE net.owner_verifications (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  otp_hash bytea NOT NULL,
  otp_key_version int NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'verified', 'locked', 'expired')) DEFAULT 'pending',
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  verified_at timestamptz,
  session_token_hash bytea,
  session_expires_at timestamptz
);
CREATE INDEX ix_owner_verifications_phone ON net.owner_verifications (phone_hash, created_at DESC);

CREATE TABLE net.data_subject_requests (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  phone_identity_id uuid REFERENCES net.phone_identities (id) ON DELETE SET NULL, -- D8/R4: SET NULL on purge
  kind text NOT NULL CHECK (kind IN ('erase', 'pseudonymise')),
  status text NOT NULL CHECK (status IN ('requested', 'in_progress', 'blocked_legal_hold', 'completed', 'rejected')) DEFAULT 'requested',
  requested_via text NOT NULL CHECK (requested_via IN ('owner_otp', 'admin')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  due_at timestamptz NOT NULL
);
CREATE INDEX ix_dsr_queue ON net.data_subject_requests (due_at) WHERE status IN ('requested', 'in_progress');

CREATE TABLE net.legal_holds (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  phone_identity_id uuid NOT NULL REFERENCES net.phone_identities (id),
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  released_at timestamptz
);
CREATE INDEX ix_legal_holds_active ON net.legal_holds (phone_identity_id) WHERE released_at IS NULL;

-- Append-only, with the R2 local override: DELETE is normally blocked (app.guard_append_only_block), but these
-- 4 tables additionally accept a DELETE while net.erase_phone is running (net.guard_append_only_erasure_delete),
-- so an in-progress erasure/pseudonymisation DSR can actually remove rows. D9.
SELECT app.make_append_only('net.phone_epochs', '{}');
SELECT app.make_append_only('net.phone_signals', ARRAY['is_valid', 'invalid_reason', 'invalidated_at']);
SELECT app.make_append_only('net.global_score_history', '{}');
SELECT app.make_append_only('net.consents', '{}');
SELECT app.make_append_only('net.score_models', ARRAY['status', 'active_from', 'retired_at']);

CREATE OR REPLACE FUNCTION net.guard_append_only_erasure_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('scoring.erasure_in_progress', true) IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'append-only: DELETE not permitted on % outside erasure', TG_TABLE_NAME USING ERRCODE = '55000';
  END IF;
  RETURN OLD;
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['net.phone_epochs', 'net.phone_signals', 'net.global_score_history', 'net.consents'] LOOP
    EXECUTE format('DROP TRIGGER trg_append_only_block_delete ON %s', t);
    EXECUTE format(
      'CREATE TRIGGER trg_erasure_delete_guard BEFORE DELETE ON %s FOR EACH ROW EXECUTE FUNCTION net.guard_append_only_erasure_delete()',
      t);
  END LOOP;
END $$;

SELECT app.ensure_monthly_partitions('net.phone_signals');
SELECT app.ensure_monthly_partitions('net.global_score_history');
SELECT app.ensure_monthly_partitions('net.consents');

-- =================================================================================================================
-- 2. Tenant plane (public) — RLS on all 4 tables
-- =================================================================================================================

CREATE TABLE public.known_phones (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  has_order boolean NOT NULL DEFAULT false,
  min_order_age_hours int,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  forgotten_at timestamptz, -- crm.contact.erased
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, phone_hash),
  UNIQUE (business_id, id) -- lets other tenant tables FK in as (business_id, known_phone_id) — ADR-0002/X3
);
CREATE INDEX ix_known_phones_hash ON public.known_phones (phone_hash);
SELECT app.enable_tenant_rls('public.known_phones');

CREATE TABLE public.tenant_scores (
  known_phone_id uuid PRIMARY KEY,
  business_id uuid NOT NULL,
  tier text NOT NULL CHECK (tier IN ('A', 'B', 'C', 'D', 'unscored')),
  confidence text NOT NULL CHECK (confidence IN ('none', 'low', 'medium', 'high')), -- E2: tenant 4-label vocabulary
  effective_n int NOT NULL DEFAULT 0 CHECK (effective_n >= 0),
  model_version text NOT NULL REFERENCES net.score_models (version),
  computed_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  -- Composite FK only (X3): a single-column FK on known_phone_id would let tenant B attach its row to tenant
  -- A's known_phones row by guessing/learning the id, bypassing business_id entirely.
  FOREIGN KEY (business_id, known_phone_id) REFERENCES public.known_phones (business_id, id) ON DELETE CASCADE,
  CHECK (confidence = 'none' OR effective_n > 0)
);
CREATE INDEX ix_tenant_scores_computed ON public.tenant_scores (business_id, computed_at);
SELECT app.enable_tenant_rls('public.tenant_scores');
CREATE TRIGGER trg_tenant_scores_version BEFORE UPDATE ON public.tenant_scores
FOR EACH ROW EXECUTE FUNCTION net.guard_score_version();

CREATE TABLE public.tenant_score_history (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  known_phone_id uuid NOT NULL,
  tier text NOT NULL,
  confidence text NOT NULL,
  model_version text NOT NULL REFERENCES net.score_models (version),
  computed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, computed_at),
  FOREIGN KEY (business_id, known_phone_id) REFERENCES public.known_phones (business_id, id)
) PARTITION BY RANGE (computed_at);
CREATE INDEX ix_tenant_score_history_phone ON public.tenant_score_history (business_id, known_phone_id, computed_at DESC);
SELECT app.enable_tenant_rls('public.tenant_score_history');
SELECT app.make_append_only('public.tenant_score_history', '{}');
SELECT app.ensure_monthly_partitions('public.tenant_score_history');

CREATE TABLE public.score_lookups (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  phone_hash bytea NOT NULL,
  known_phone_id uuid,
  result text NOT NULL CHECK (result IN (
    'scored', 'not_enough_data', 'refused_not_known', 'refused_rate_limited', 'refused_consent', 'refused_k_gate'
  )),
  requested_at timestamptz NOT NULL DEFAULT now(),
  requested_by uuid, -- opaque ref: identity-access user
  PRIMARY KEY (id, requested_at)
) PARTITION BY RANGE (requested_at);
CREATE INDEX ix_score_lookups_business ON public.score_lookups (business_id, requested_at DESC);
CREATE INDEX ix_score_lookups_hash ON public.score_lookups (phone_hash, requested_at);
SELECT app.enable_tenant_rls('public.score_lookups');
SELECT app.make_append_only('public.score_lookups', '{}');
SELECT app.ensure_monthly_partitions('public.score_lookups');

-- scoring_app has NO direct writes anywhere (S9): C0001's default privileges grant INSERT/UPDATE/DELETE on every
-- public table to _app, which must be revoked here. All writes to these 4 tables happen inside the SECURITY
-- DEFINER functions below (running as the migrator) or via scoring_engine directly.
-- scoring_engine (not the generic, unused <db>_worker) is this service's worker role, declared via roles.conf,
-- so unlike _app/_worker it gets NO default privileges at all (ADR-0006) — its public-table access must be
-- granted explicitly here too, not only its net.* access.
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format(
    'REVOKE INSERT, UPDATE, DELETE ON public.known_phones, public.tenant_scores, public.tenant_score_history, public.score_lookups FROM %I',
    db || '_app');
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON public.known_phones, public.tenant_scores TO %I', db || '_engine');
  -- tenant_score_history and score_lookups are append-only: engine may only ever INSERT, never UPDATE/DELETE
  -- (make_append_only already blocked this for _app/_worker/_admin by name; it does not know about _engine).
  EXECUTE format('GRANT SELECT, INSERT ON public.tenant_score_history, public.score_lookups TO %I', db || '_engine');
  EXECUTE format(
    'GRANT SELECT ON public.known_phones, public.tenant_scores, public.tenant_score_history, public.score_lookups TO %I',
    db || '_admin');
END $$;

-- =================================================================================================================
-- 3. scoring_engine explicit grants (net schema has no default privileges)
-- =================================================================================================================

DO $$ DECLARE db text := current_database(); eng text := current_database() || '_engine'; adm text := current_database() || '_admin'; BEGIN
  EXECUTE format('GRANT SELECT ON net.pepper_versions, net.score_models, net.settings TO %I, %I', eng, adm);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON net.phone_identities TO %I', eng);
  EXECUTE format('GRANT SELECT, INSERT ON net.phone_epochs TO %I', eng);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON net.feature_flags, net.business_trust TO %I', eng);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON net.phone_signals TO %I', eng); -- UPDATE limited to the whitelist above
  EXECUTE format('GRANT SELECT, INSERT ON net.order_outcome_claims, net.phone_contributors, net.consents TO %I', eng);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON net.global_scores TO %I', eng);
  EXECUTE format('GRANT SELECT, INSERT ON net.global_score_history TO %I', eng);
  EXECUTE format('GRANT SELECT ON net.disputes, net.legal_holds, net.erasure_suppressions TO %I, %I', eng, adm);
  EXECUTE format('GRANT SELECT ON net.owner_verifications, net.data_subject_requests TO %I', adm);
  EXECUTE format('GRANT UPDATE (status, active_from, retired_at) ON net.score_models TO %I', adm); -- admin_* functions use this
END $$;

-- =================================================================================================================
-- 4. SECURITY DEFINER bridge functions (the six crossing public -> net; search_path pinned, EXECUTE revoked
--    from PUBLIC and granted to exactly the one role that needs it)
-- =================================================================================================================

-- 4.1 public.lookup_score — the only way scoring_app ever reaches the global layer. Every abuse case from
-- §8 that is schema-visible is checked here, in this order, and every refusal looks identical to the caller
-- ("not_enough_data") even though the real reason is recorded in score_lookups for internal forensics.
CREATE OR REPLACE FUNCTION public.lookup_score(p_phone_hash bytea)
RETURNS TABLE (band text, confidence text, model_version text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_business_id uuid := app.current_business_id();
  v_known public.known_phones;
  v_identity net.phone_identities;
  v_epoch net.phone_epochs;
  v_score net.global_scores;
  v_result text;
  v_count bigint;
  v_min_age_hours int;
BEGIN
  IF v_business_id IS NULL THEN
    RAISE EXCEPTION 'lookup_score: no tenant context' USING ERRCODE = '55000';
  END IF;
  IF octet_length(p_phone_hash) <> 32 THEN
    RAISE EXCEPTION 'lookup_score: malformed phone_hash' USING ERRCODE = '55000';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_business_id::text, 0)); -- X6: count-then-check race

  SELECT count(*) INTO v_count FROM public.score_lookups
   WHERE business_id = v_business_id AND requested_at > now() - interval '1 minute';
  IF v_count >= net.setting_int('lookup_rate_per_minute') THEN
    v_result := 'refused_rate_limited';
  END IF;

  IF v_result IS NULL THEN
    SELECT count(*) INTO v_count FROM public.score_lookups
     WHERE business_id = v_business_id AND requested_at > now() - interval '1 day';
    IF v_count >= net.setting_int('lookup_rate_per_day') THEN
      v_result := 'refused_rate_limited';
    END IF;
  END IF;

  IF v_result IS NULL THEN
    SELECT * INTO v_known FROM public.known_phones
     WHERE business_id = v_business_id AND phone_hash = p_phone_hash AND forgotten_at IS NULL;
    IF NOT FOUND THEN
      v_result := 'refused_not_known';
    END IF;
  END IF;

  -- S1 DEFAULT: global band only for a known order at least min_order_age_hours old (blocks the throwaway-order oracle).
  IF v_result IS NULL THEN
    v_min_age_hours := coalesce(v_known.min_order_age_hours, net.setting_int('min_order_age_hours'));
    IF NOT v_known.has_order OR v_known.created_at > now() - make_interval(hours => v_min_age_hours) THEN
      v_result := 'refused_not_known';
    END IF;
  END IF;

  IF v_result IS NULL THEN
    SELECT * INTO v_identity FROM net.phone_identities WHERE phone_hash = p_phone_hash;
    IF NOT FOUND THEN
      v_result := 'refused_not_known';
    END IF;
  END IF;

  -- Recycled-number check: refuse when this merchant's own knowledge predates the phone's current epoch.
  IF v_result IS NULL THEN
    SELECT * INTO v_epoch FROM net.phone_epochs WHERE phone_identity_id = v_identity.id AND epoch = v_identity.current_epoch;
    IF v_known.last_seen_at < v_epoch.started_at THEN
      v_result := 'refused_not_known';
    END IF;
  END IF;

  IF v_result IS NULL AND NOT EXISTS (
    SELECT 1 FROM net.consents
     WHERE phone_identity_id = v_identity.id AND purpose = 'global_scoring'
     ORDER BY seq DESC LIMIT 1
  ) THEN
    v_result := 'refused_consent'; -- no decision at all yet = not granted
  END IF;
  IF v_result IS NULL AND (
    SELECT decision FROM net.consents
     WHERE phone_identity_id = v_identity.id AND purpose = 'global_scoring'
     ORDER BY seq DESC LIMIT 1
  ) IS DISTINCT FROM 'granted' THEN
    v_result := 'refused_consent';
  END IF;

  -- k-gate: eligible contributors OTHER than the requester, per current epoch (D7).
  IF v_result IS NULL THEN
    SELECT count(*) INTO v_count FROM net.phone_contributors
     WHERE phone_identity_id = v_identity.id AND phone_epoch = v_identity.current_epoch
       AND eligible_at <= now() AND business_id <> v_business_id;
    IF v_count < net.setting_int('min_contributors_k') THEN
      v_result := 'refused_k_gate';
    END IF;
  END IF;

  IF v_result IS NULL THEN
    SELECT * INTO v_score FROM net.global_scores
     WHERE phone_identity_id = v_identity.id AND phone_epoch = v_identity.current_epoch;
    v_result := CASE WHEN FOUND THEN 'scored' ELSE 'not_enough_data' END;
  END IF;

  INSERT INTO public.score_lookups (business_id, phone_hash, known_phone_id, result, requested_by)
  VALUES (v_business_id, p_phone_hash, v_known.id, v_result, app.current_user_id());

  IF v_result = 'scored' THEN
    RETURN QUERY SELECT v_score.band, v_score.confidence, v_score.model_version;
  ELSE
    RETURN QUERY SELECT 'not_enough_data'::text, 'not_enough_data'::text, NULL::text;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.lookup_score(bytea) FROM PUBLIC;

-- 4.2 Owner self-view OTP flow (CLAUDE.md §5 phone-owner rights). The app computes phone_hash and the OTP
-- hash itself (the pepper and the OTP key never reach SQL); these functions never leak whether a number is
-- known ("start returns an id whether or not the number is known").
CREATE OR REPLACE FUNCTION public.owner_start_verification(p_phone_hash bytea, p_otp_hash bytea, p_otp_key_version int)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_id uuid; v_count bigint;
BEGIN
  IF octet_length(p_phone_hash) <> 32 THEN
    RAISE EXCEPTION 'owner_start_verification: malformed phone_hash' USING ERRCODE = '55000';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(encode(p_phone_hash, 'hex'), 1));
  SELECT count(*) INTO v_count FROM net.owner_verifications
   WHERE phone_hash = p_phone_hash AND created_at > now() - interval '1 day';
  IF v_count >= net.setting_int('otp_challenges_per_day') THEN
    RAISE EXCEPTION 'owner_start_verification: too many challenges today' USING ERRCODE = '55000';
  END IF;
  INSERT INTO net.owner_verifications (phone_hash, otp_hash, otp_key_version)
  VALUES (p_phone_hash, p_otp_hash, p_otp_key_version)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.owner_start_verification(bytea, bytea, int) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.owner_submit_otp(p_verification_id uuid, p_otp_hash bytea)
RETURNS bytea LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v net.owner_verifications; v_token bytea;
BEGIN
  SELECT * INTO v FROM net.owner_verifications WHERE id = p_verification_id FOR UPDATE;
  IF NOT FOUND OR v.status <> 'pending' OR v.created_at < now() - interval '15 minutes' THEN
    RAISE EXCEPTION 'owner_submit_otp: invalid or expired verification' USING ERRCODE = '55000';
  END IF;
  IF v.attempts >= 5 THEN
    UPDATE net.owner_verifications SET status = 'locked' WHERE id = p_verification_id;
    RAISE EXCEPTION 'owner_submit_otp: locked' USING ERRCODE = '55000';
  END IF;
  IF v.otp_hash IS DISTINCT FROM p_otp_hash THEN
    UPDATE net.owner_verifications SET attempts = attempts + 1 WHERE id = p_verification_id;
    RAISE EXCEPTION 'owner_submit_otp: incorrect code' USING ERRCODE = '55000';
  END IF;

  v_token := public.gen_random_bytes(32);
  UPDATE net.owner_verifications
     SET status = 'verified', verified_at = now(), session_token_hash = public.digest(v_token, 'sha256'),
         session_expires_at = now() + interval '30 minutes'
   WHERE id = p_verification_id;
  RETURN v_token;
END;
$$;
REVOKE ALL ON FUNCTION public.owner_submit_otp(uuid, bytea) FROM PUBLIC;

CREATE OR REPLACE FUNCTION net.require_owner_session(p_verification_id uuid, p_session_token bytea) RETURNS net.owner_verifications
LANGUAGE plpgsql AS $$
DECLARE v net.owner_verifications;
BEGIN
  SELECT * INTO v FROM net.owner_verifications WHERE id = p_verification_id;
  IF NOT FOUND OR v.status <> 'verified' OR v.session_expires_at < now()
     OR v.session_token_hash IS DISTINCT FROM public.digest(p_session_token, 'sha256') THEN
    RAISE EXCEPTION 'owner session not verified' USING ERRCODE = '55000';
  END IF;
  RETURN v;
END;
$$;

-- 4.3 owner_view_score — S2 DEFAULT: coarse month-level self-view, no provenance, no counts.
CREATE OR REPLACE FUNCTION public.owner_view_score(p_verification_id uuid, p_session_token bytea)
RETURNS TABLE (month date, had_negative_event boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v net.owner_verifications; v_identity net.phone_identities;
BEGIN
  v := net.require_owner_session(p_verification_id, p_session_token);
  SELECT * INTO v_identity FROM net.phone_identities WHERE phone_hash = v.phone_hash;
  IF NOT FOUND THEN RETURN; END IF;

  RETURN QUERY
    SELECT date_trunc('month', occurred_at)::date, bool_or(weight < 0)
    FROM net.phone_signals
    WHERE phone_identity_id = v_identity.id AND is_valid
    GROUP BY 1 ORDER BY 1;
END;
$$;
REVOKE ALL ON FUNCTION public.owner_view_score(uuid, bytea) FROM PUBLIC;

-- 4.4 owner_open_dispute — only negative, valid, current-epoch signals are disputable; 3/90 days rate limit.
CREATE OR REPLACE FUNCTION public.owner_open_dispute(
  p_verification_id uuid, p_session_token bytea, p_signal_id uuid, p_signal_occurred_at timestamptz, p_reason_text text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v net.owner_verifications; v_identity net.phone_identities; v_count bigint; v_freeze_days int; v_id uuid;
BEGIN
  v := net.require_owner_session(p_verification_id, p_session_token);
  SELECT * INTO v_identity FROM net.phone_identities WHERE phone_hash = v.phone_hash;
  IF NOT FOUND THEN RAISE EXCEPTION 'owner_open_dispute: unknown phone' USING ERRCODE = '55000'; END IF;

  SELECT count(*) INTO v_count FROM net.disputes
   WHERE phone_identity_id = v_identity.id AND opened_at > now() - interval '90 days';
  IF v_count >= 3 THEN
    RAISE EXCEPTION 'owner_open_dispute: dispute rate limit' USING ERRCODE = '55000';
  END IF;

  IF p_signal_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM net.phone_signals
     WHERE id = p_signal_id AND occurred_at = p_signal_occurred_at AND phone_identity_id = v_identity.id
       AND phone_epoch = v_identity.current_epoch AND is_valid AND weight < 0
  ) THEN
    RAISE EXCEPTION 'owner_open_dispute: signal not disputable' USING ERRCODE = '55000';
  END IF;

  v_freeze_days := net.setting_int('dispute_freeze_days');
  INSERT INTO net.disputes (phone_identity_id, signal_id, signal_occurred_at, opened_via, reason_text, frozen_until, due_at)
  VALUES (v_identity.id, p_signal_id, p_signal_occurred_at, 'owner_otp', p_reason_text,
          now() + make_interval(days => v_freeze_days), now() + interval '5 days')
  RETURNING id INTO v_id;

  -- version always bumps on write, even a freeze-only change (S7 guard enforces this on every UPDATE).
  UPDATE net.global_scores SET frozen_until = now() + make_interval(days => v_freeze_days), version = version + 1
   WHERE phone_identity_id = v_identity.id;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.owner_open_dispute(uuid, bytea, uuid, timestamptz, text) FROM PUBLIC;

-- 4.5 owner_request_erasure — files the DSR only; S10 fix: actual progression/erasure is admin-only (§4.6).
CREATE OR REPLACE FUNCTION public.owner_request_erasure(p_verification_id uuid, p_session_token bytea, p_mode text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v net.owner_verifications; v_identity net.phone_identities; v_id uuid; v_due_days int;
BEGIN
  v := net.require_owner_session(p_verification_id, p_session_token);
  IF p_mode NOT IN ('erase', 'pseudonymise') THEN
    RAISE EXCEPTION 'owner_request_erasure: invalid mode' USING ERRCODE = '55000';
  END IF;
  SELECT * INTO v_identity FROM net.phone_identities WHERE phone_hash = v.phone_hash;
  IF NOT FOUND THEN RAISE EXCEPTION 'owner_request_erasure: unknown phone' USING ERRCODE = '55000'; END IF;

  v_due_days := net.setting_int('dsr_due_days');
  INSERT INTO net.data_subject_requests (phone_identity_id, kind, requested_via, due_at)
  VALUES (v_identity.id, p_mode, 'owner_otp', now() + make_interval(days => v_due_days))
  RETURNING id INTO v_id;

  IF EXISTS (SELECT 1 FROM net.legal_holds WHERE phone_identity_id = v_identity.id AND released_at IS NULL) THEN
    UPDATE net.data_subject_requests SET status = 'blocked_legal_hold' WHERE id = v_id;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.owner_request_erasure(uuid, bytea, text) FROM PUBLIC;

-- C0001's default privileges auto-grant EXECUTE on every NEW function in schema public to _app and _worker at
-- CREATE FUNCTION time (a real grant to those roles, not to the PUBLIC pseudo-role) — "REVOKE ALL ... FROM
-- PUBLIC" above does not touch it. Claw it back here before granting to the one role that should have each.
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format(
    'REVOKE ALL ON FUNCTION public.owner_start_verification(bytea, bytea, int), public.owner_submit_otp(uuid, bytea), public.owner_view_score(uuid, bytea), public.owner_open_dispute(uuid, bytea, uuid, timestamptz, text), public.owner_request_erasure(uuid, bytea, text) FROM %I, %I',
    db || '_app', db || '_worker');
  EXECUTE format('REVOKE ALL ON FUNCTION public.lookup_score(bytea) FROM %I', db || '_worker');
END $$;

GRANT EXECUTE ON FUNCTION
  public.owner_start_verification(bytea, bytea, int), public.owner_submit_otp(uuid, bytea),
  public.owner_view_score(uuid, bytea), public.owner_open_dispute(uuid, bytea, uuid, timestamptz, text),
  public.owner_request_erasure(uuid, bytea, text)
TO scoring_portal;
GRANT EXECUTE ON FUNCTION public.lookup_score(bytea) TO scoring_app;

-- =================================================================================================================
-- 5. net.erase_phone (engine/admin) and the admin_* console functions
-- =================================================================================================================

CREATE OR REPLACE FUNCTION net.erase_phone(p_phone_identity_id uuid, p_mode text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_hash bytea;
BEGIN
  IF p_mode NOT IN ('erase', 'pseudonymise') THEN
    RAISE EXCEPTION 'erase_phone: invalid mode %', p_mode USING ERRCODE = '55000';
  END IF;
  IF EXISTS (SELECT 1 FROM net.legal_holds WHERE phone_identity_id = p_phone_identity_id AND released_at IS NULL) THEN
    RAISE EXCEPTION 'erase_phone: active legal hold' USING ERRCODE = '55000';
  END IF;

  SELECT phone_hash INTO v_hash FROM net.phone_identities WHERE id = p_phone_identity_id;
  IF NOT FOUND THEN RETURN; END IF;

  PERFORM set_config('scoring.erasure_in_progress', 'true', true);

  DELETE FROM net.order_outcome_claims WHERE phone_identity_id = p_phone_identity_id;
  DELETE FROM net.phone_contributors WHERE phone_identity_id = p_phone_identity_id;
  DELETE FROM net.disputes WHERE phone_identity_id = p_phone_identity_id;
  DELETE FROM net.legal_holds WHERE phone_identity_id = p_phone_identity_id; -- only released ones remain at this point
  DELETE FROM net.owner_verifications WHERE phone_hash = v_hash;
  DELETE FROM net.phone_signals WHERE phone_identity_id = p_phone_identity_id;
  DELETE FROM net.global_score_history WHERE phone_identity_id = p_phone_identity_id;
  DELETE FROM net.consents WHERE phone_identity_id = p_phone_identity_id;
  DELETE FROM net.phone_epochs WHERE phone_identity_id = p_phone_identity_id;
  DELETE FROM net.global_scores WHERE phone_identity_id = p_phone_identity_id;
  -- net.data_subject_requests.phone_identity_id is SET NULL by its own FK action on the next statement.
  DELETE FROM net.phone_identities WHERE id = p_phone_identity_id;

  INSERT INTO net.erasure_suppressions (phone_hash, mode) VALUES (v_hash, p_mode)
  ON CONFLICT (phone_hash) DO UPDATE SET mode = EXCLUDED.mode, suppressed_at = now();
END;
$$;
REVOKE ALL ON FUNCTION net.erase_phone(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION net.erase_phone(uuid, text) TO scoring_engine, scoring_admin;

CREATE OR REPLACE FUNCTION net.admin_progress_dsr(p_dsr_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v net.data_subject_requests;
BEGIN
  SELECT * INTO v FROM net.data_subject_requests WHERE id = p_dsr_id FOR UPDATE;
  IF NOT FOUND OR v.status NOT IN ('requested', 'blocked_legal_hold') THEN
    RAISE EXCEPTION 'admin_progress_dsr: not progressable' USING ERRCODE = '55000';
  END IF;
  IF v.phone_identity_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM net.legal_holds WHERE phone_identity_id = v.phone_identity_id AND released_at IS NULL
  ) THEN
    UPDATE net.data_subject_requests SET status = 'blocked_legal_hold' WHERE id = p_dsr_id;
    RETURN;
  END IF;
  UPDATE net.data_subject_requests SET status = 'in_progress' WHERE id = p_dsr_id;
  IF v.phone_identity_id IS NOT NULL THEN
    PERFORM net.erase_phone(v.phone_identity_id, v.kind);
  END IF;
  UPDATE net.data_subject_requests SET status = 'completed', completed_at = now() WHERE id = p_dsr_id;
END;
$$;
REVOKE ALL ON FUNCTION net.admin_progress_dsr(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION net.admin_progress_dsr(uuid) TO scoring_admin;

CREATE OR REPLACE FUNCTION net.admin_release_legal_hold(p_hold_id uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  UPDATE net.legal_holds SET released_at = now() WHERE id = p_hold_id AND released_at IS NULL;
$$;
REVOKE ALL ON FUNCTION net.admin_release_legal_hold(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION net.admin_release_legal_hold(uuid) TO scoring_admin;

CREATE OR REPLACE FUNCTION net.admin_resolve_dispute(p_dispute_id uuid, p_status text, p_resolved_by uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF p_status NOT IN ('upheld', 'rejected') THEN
    RAISE EXCEPTION 'admin_resolve_dispute: invalid status' USING ERRCODE = '55000';
  END IF;
  UPDATE net.disputes SET status = p_status, resolved_at = now(), resolved_by = p_resolved_by
   WHERE id = p_dispute_id AND status = 'open';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'admin_resolve_dispute: dispute not open' USING ERRCODE = '55000';
  END IF;
  IF p_status = 'upheld' THEN
    UPDATE net.phone_signals ps SET is_valid = false, invalid_reason = 'dispute_upheld', invalidated_at = now()
    FROM net.disputes d WHERE d.id = p_dispute_id AND ps.id = d.signal_id AND ps.occurred_at = d.signal_occurred_at;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION net.admin_resolve_dispute(uuid, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION net.admin_resolve_dispute(uuid, text, uuid) TO scoring_admin;

CREATE OR REPLACE FUNCTION net.admin_activate_score_model(p_version text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  UPDATE net.score_models SET status = 'retired', retired_at = now() WHERE status = 'active';
  UPDATE net.score_models SET status = 'active', active_from = now() WHERE version = p_version AND status = 'draft';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'admin_activate_score_model: % not in draft status', p_version USING ERRCODE = '55000';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION net.admin_activate_score_model(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION net.admin_activate_score_model(text) TO scoring_admin;

CREATE OR REPLACE FUNCTION net.admin_rotate_pepper(p_new_version int) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  UPDATE net.pepper_versions SET status = 'retired', retired_at = now() WHERE status = 'active';
  INSERT INTO net.pepper_versions (version, status) VALUES (p_new_version, 'active');
END;
$$;
REVOKE ALL ON FUNCTION net.admin_rotate_pepper(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION net.admin_rotate_pepper(int) TO scoring_admin;

DO $$ BEGIN
  EXECUTE format('GRANT INSERT ON net.score_models TO %I', current_database() || '_admin');
END $$;

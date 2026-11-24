-- V0001__initial.sql — identity-access schema (docs/02-data/identity-access.md). ASP.NET Core Identity + OpenIddict
-- map onto these tables through custom stores (ADR-0004 SQL-first); no AspNet* tables, no EF migrations.
-- OpenIddict's own tables (`oidc` schema) are deferred to V0002 after spike S1 — not in scope here.
--
-- Roles (standard trio only; no roles.conf extras needed yet — open question §10.1 notes _admin is new/thin):
--   identity_access_app     Identity.Api. No DELETE anywhere; column grants exclude platform_role, trust_weight,
--                           verified_*, business_members.business_id/user_id, api_keys.secret_hash/key_prefix.
--                           No direct write to feature_flags (only via set_feature_flag, admin-only).
--   identity_access_worker  consumers/purge jobs (session/token expiry, partition maintenance).
--   identity_access_admin   web-master: EXECUTE set_feature_flag; direct UPDATE of trust_weight/verified_*/platform_role.
--   identity_access_migrator owner; definer of the three pre-tenant lookup functions and set_feature_flag.

-- =================================================================================================================
-- 1. Platform tables (no RLS — protected by grants + "only identity-access connects to this DB", per the doc)
-- =================================================================================================================

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  email text NOT NULL,
  email_normalized text NOT NULL,
  password_hash text CHECK (password_hash IS NULL OR password_hash LIKE '$argon2id$%'),
  full_name text NOT NULL,
  avatar_file_id uuid REFERENCES app.files (id) ON DELETE SET NULL,
  platform_role text NOT NULL DEFAULT 'none' CHECK (platform_role IN ('none', 'web_master')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
  security_stamp uuid NOT NULL DEFAULT gen_random_uuid(),
  access_failed_count int NOT NULL DEFAULT 0 CHECK (access_failed_count >= 0),
  lockout_end timestamptz,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_users_email_normalized ON users (email_normalized);
SELECT app.add_updated_at_trigger('users');

-- businesses is created here (ahead of its catalogue section below) because auth_sessions.business_id FKs to it.
CREATE TABLE businesses (
  id uuid PRIMARY KEY DEFAULT uuidv7(), -- this IS the tenant id; RLS policy below is custom (keyed on id, not a business_id column)
  name text NOT NULL,
  slug text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended', 'closed')),
  trust_weight numeric(5, 4) NOT NULL DEFAULT 1.0 CHECK (trust_weight BETWEEN 0 AND 1), -- web-master write only
  verified_at timestamptz,
  verified_by uuid REFERENCES users (id),
  public_name text,
  public_description text,
  created_by uuid NOT NULL REFERENCES users (id),
  wilaya_dataset_version int,
  wilaya_code text,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (wilaya_dataset_version, wilaya_code) REFERENCES ref.wilayas (dataset_version, code)
);
CREATE UNIQUE INDEX ux_businesses_slug ON businesses (slug);
CREATE INDEX ix_businesses_pending ON businesses (created_at) WHERE status = 'pending';
SELECT app.add_updated_at_trigger('businesses');

ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE businesses FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON businesses USING (id = app.current_business_id()) WITH CHECK (id = app.current_business_id());

CREATE TABLE auth_identities (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id uuid NOT NULL REFERENCES users (id),
  provider text NOT NULL CHECK (provider IN ('google')),
  provider_subject text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider)
);
CREATE UNIQUE INDEX ux_auth_identities_provider_subject ON auth_identities (provider, provider_subject);

CREATE TABLE auth_sessions (
  id uuid PRIMARY KEY DEFAULT uuidv7(), -- "sid"
  user_id uuid NOT NULL REFERENCES users (id),
  business_id uuid REFERENCES businesses (id), -- active tenant for this session, if any (same-service FK, fine)
  ip text,
  user_agent text,
  oidc_authorization_id uuid, -- future 1:1 with oidc.authorizations (V0002, Q1) — no FK yet, schema doesn't exist
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);
CREATE INDEX ix_auth_sessions_user_active ON auth_sessions (user_id) WHERE revoked_at IS NULL;
CREATE INDEX ix_auth_sessions_expires ON auth_sessions (expires_at);

CREATE TABLE auth_refresh_tokens (
  id uuid NOT NULL DEFAULT uuidv7(),
  session_id uuid NOT NULL REFERENCES auth_sessions (id),
  token_hash bytea NOT NULL CHECK (octet_length(token_hash) = 32),
  issued_at timestamptz NOT NULL DEFAULT now(),
  used_at timestamptz,
  replaced_by uuid,
  PRIMARY KEY (id, issued_at)
) PARTITION BY RANGE (issued_at);
CREATE INDEX ix_auth_refresh_tokens_hash ON auth_refresh_tokens (token_hash);
CREATE INDEX ix_auth_refresh_tokens_session ON auth_refresh_tokens (session_id);
SELECT app.ensure_monthly_partitions('auth_refresh_tokens');

CREATE TABLE auth_tokens (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id uuid NOT NULL REFERENCES users (id),
  purpose text NOT NULL CHECK (purpose IN ('email_verify', 'password_reset', 'email_change')),
  token_hash bytea NOT NULL CHECK (octet_length(token_hash) = 32),
  email text, -- target address for email_verify/email_change
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  used_at timestamptz
);
CREATE UNIQUE INDEX ux_auth_tokens_hash ON auth_tokens (token_hash);
CREATE UNIQUE INDEX ux_auth_tokens_live ON auth_tokens (user_id, purpose) WHERE used_at IS NULL; -- one live token per purpose

CREATE TABLE user_mfa_factors (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id uuid NOT NULL REFERENCES users (id),
  kind text NOT NULL CHECK (kind IN ('totp')),
  secret_encrypted bytea NOT NULL, -- AES-256-GCM under an external envelope key
  key_id text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'disabled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz
);
CREATE UNIQUE INDEX ux_user_mfa_factors_live ON user_mfa_factors (user_id, kind) WHERE status IN ('pending', 'active');

CREATE TABLE user_recovery_codes (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id uuid NOT NULL REFERENCES users (id),
  code_hash bytea NOT NULL CHECK (octet_length(code_hash) = 32), -- HMAC-SHA256 with pepper (secret store)
  created_at timestamptz NOT NULL DEFAULT now(),
  used_at timestamptz
);
CREATE UNIQUE INDEX ux_user_recovery_codes ON user_recovery_codes (user_id, code_hash);

CREATE TABLE client_profiles (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id uuid NOT NULL REFERENCES users (id),
  phone_raw text,
  phone_e164 text CHECK (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
  phone_hash bytea CHECK (phone_hash IS NULL OR octet_length(phone_hash) = 32), -- all-or-none with proof (D7)
  proven_at timestamptz,
  default_address jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((phone_raw IS NULL) = (phone_e164 IS NULL) AND (phone_e164 IS NULL) = (phone_hash IS NULL))
);
CREATE UNIQUE INDEX ux_client_profiles_user ON client_profiles (user_id);
CREATE UNIQUE INDEX ux_client_profiles_phone_hash ON client_profiles (phone_hash) WHERE phone_hash IS NOT NULL;
SELECT app.add_updated_at_trigger('client_profiles');

CREATE TABLE permissions (
  key text PRIMARY KEY,
  category text NOT NULL,
  description text NOT NULL
);

CREATE TABLE permission_presets (
  key text PRIMARY KEY,
  name text NOT NULL,
  permission_keys text[] NOT NULL DEFAULT '{}'
);

-- =================================================================================================================
-- 2. Tenant tables
-- =================================================================================================================

CREATE TABLE business_members (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL REFERENCES businesses (id),
  user_id uuid NOT NULL REFERENCES users (id),
  role text NOT NULL CHECK (role IN ('owner', 'staff', 'client')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('invited', 'active', 'suspended', 'removed')), -- 'invited' may be dead state (open Q9)
  permissions jsonb NOT NULL DEFAULT '[]'::jsonb,
  perm_ver bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, user_id),
  UNIQUE (business_id, id) -- composite-FK target for other tenant tables (X3)
);
CREATE INDEX ix_business_members_user_active ON business_members (user_id) WHERE status = 'active';
SELECT app.add_updated_at_trigger('business_members');
SELECT app.enable_tenant_rls('business_members');

CREATE TABLE business_invitations (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL REFERENCES businesses (id),
  email text NOT NULL,
  role text NOT NULL CHECK (role IN ('owner', 'staff', 'client')),
  token_hash bytea NOT NULL CHECK (octet_length(token_hash) = 32),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
  invited_by uuid NOT NULL REFERENCES users (id),
  accepted_member_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  FOREIGN KEY (business_id, accepted_member_id) REFERENCES business_members (business_id, id)
);
CREATE UNIQUE INDEX ux_business_invitations_token ON business_invitations (token_hash);
CREATE UNIQUE INDEX ux_business_invitations_open ON business_invitations (business_id, email) WHERE status = 'pending';
SELECT app.enable_tenant_rls('business_invitations');

CREATE TABLE api_keys (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL REFERENCES businesses (id),
  name text NOT NULL,
  key_prefix text NOT NULL,
  secret_hash bytea NOT NULL CHECK (octet_length(secret_hash) = 32),
  scopes text[] NOT NULL DEFAULT '{}',
  created_by uuid NOT NULL REFERENCES users (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  last_used_at timestamptz
);
CREATE UNIQUE INDEX ux_api_keys_secret_hash ON api_keys (secret_hash);
CREATE UNIQUE INDEX ux_api_keys_prefix ON api_keys (key_prefix);
SELECT app.enable_tenant_rls('api_keys');

-- Mixed scope: global rows (business_id IS NULL) + per-business overrides. D9: NULLS NOT DISTINCT so at most one
-- global row per key. Writes ONLY through set_feature_flag() (§4 below) — no INSERT/UPDATE/DELETE grant to any
-- runtime role, including admin (the function runs as the migrator regardless of caller).
CREATE TABLE feature_flags (
  key text NOT NULL,
  business_id uuid REFERENCES businesses (id),
  enabled boolean NOT NULL DEFAULT false,
  source_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (key, business_id)
);
CREATE UNIQUE INDEX ux_feature_flags_key ON feature_flags (key, business_id) NULLS NOT DISTINCT; -- same as the UNIQUE above, named for the doc's index list

ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags FORCE ROW LEVEL SECURITY;
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format(
    'CREATE POLICY feature_flags_select ON feature_flags FOR SELECT TO %I, %I, %I USING (business_id IS NULL OR business_id = app.current_business_id())',
    db || '_app', db || '_worker', db || '_admin');
END $$;

-- =================================================================================================================
-- 3. Grants — tighten what C0001's default privileges gave _app on every public table
-- =================================================================================================================

-- REVOKE UPDATE (col) alone is a no-op when the role already has a whole-table UPDATE grant (C0001's default
-- privileges grant the whole table, every column, at CREATE TABLE time) — the table-level grant still covers
-- that column regardless. The only way to actually restrict a column is: revoke the whole-table grant, then
-- grant back an explicit column list. (Caught by T0003, not by inspection.)
DO $$ DECLARE db text := current_database(); app_r text := current_database() || '_app'; BEGIN
  EXECUTE format('REVOKE DELETE ON users, businesses, business_members, business_invitations, api_keys, client_profiles FROM %I', app_r);

  EXECUTE format('REVOKE UPDATE ON users FROM %I', app_r);
  EXECUTE format(
    'GRANT UPDATE (email, email_normalized, password_hash, full_name, avatar_file_id, status, security_stamp, access_failed_count, lockout_end, version, updated_at) ON users TO %I',
    app_r); -- platform_role excluded (I1/I2): admin-only

  EXECUTE format('REVOKE UPDATE ON businesses FROM %I', app_r);
  EXECUTE format(
    'GRANT UPDATE (name, slug, public_name, public_description, wilaya_dataset_version, wilaya_code, settings, version, updated_at) ON businesses TO %I',
    app_r); -- trust_weight/verified_*/status excluded (I2): admin-only (self-(un)suspend is exactly what I2 fixed)

  EXECUTE format('REVOKE UPDATE ON business_members FROM %I', app_r);
  EXECUTE format('GRANT UPDATE (role, status, permissions, perm_ver, updated_at) ON business_members TO %I', app_r); -- business_id/user_id excluded

  EXECUTE format('REVOKE UPDATE ON api_keys FROM %I', app_r);
  EXECUTE format('GRANT UPDATE (name, scopes, revoked_at, last_used_at) ON api_keys TO %I', app_r); -- secret_hash/key_prefix excluded

  EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON feature_flags, permissions, permission_presets FROM %I, %I', app_r, db || '_worker');
  EXECUTE format('GRANT UPDATE (platform_role) ON users TO %I', db || '_admin');
  EXECUTE format('GRANT UPDATE (trust_weight, verified_at, verified_by, status) ON businesses TO %I', db || '_admin');
END $$;

-- =================================================================================================================
-- 4. Owner guard (spec §4.10) — deferred constraint triggers, checked at COMMIT so an ownership transfer
--    (remove old owner + add new owner as two statements) succeeds without a mid-transaction false alarm.
-- =================================================================================================================

CREATE OR REPLACE FUNCTION guard_owner_exists_from_members() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_business_id uuid := COALESCE(NEW.business_id, OLD.business_id); v_status text; v_count int;
BEGIN
  SELECT status INTO v_status FROM businesses WHERE id = v_business_id FOR UPDATE;
  IF v_status IS NULL OR v_status = 'closed' THEN RETURN NULL; END IF;
  SELECT count(*) INTO v_count FROM business_members WHERE business_id = v_business_id AND role = 'owner' AND status = 'active';
  IF v_count = 0 THEN
    RAISE EXCEPTION 'business % has no active owner' , v_business_id USING ERRCODE = '55000';
  END IF;
  RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER trg_business_members_owner_guard
AFTER INSERT OR UPDATE OR DELETE ON business_members
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION guard_owner_exists_from_members();

CREATE OR REPLACE FUNCTION guard_owner_exists_from_businesses() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_count int;
BEGIN
  IF NEW.status = 'closed' THEN RETURN NULL; END IF;
  SELECT count(*) INTO v_count FROM business_members WHERE business_id = NEW.id AND role = 'owner' AND status = 'active';
  IF v_count = 0 THEN
    RAISE EXCEPTION 'business % has no active owner', NEW.id USING ERRCODE = '55000';
  END IF;
  RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER trg_businesses_owner_guard
AFTER INSERT OR UPDATE OF status ON businesses
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION guard_owner_exists_from_businesses();

-- =================================================================================================================
-- 5. Pre-tenant SECURITY DEFINER lookups (owner = migrator, BYPASSRLS) + feature-flag admin path
-- =================================================================================================================

CREATE OR REPLACE FUNCTION auth_resolve_api_key(p_secret_hash bytea)
RETURNS TABLE (api_key_id uuid, business_id uuid, scopes text[])
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT id, api_keys.business_id, api_keys.scopes FROM public.api_keys
   WHERE secret_hash = p_secret_hash AND revoked_at IS NULL;
$$;
REVOKE ALL ON FUNCTION auth_resolve_api_key(bytea) FROM PUBLIC;

CREATE OR REPLACE FUNCTION auth_resolve_invitation(p_token_hash bytea)
RETURNS TABLE (invitation_id uuid, business_id uuid, email text, role text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT id, business_invitations.business_id, business_invitations.email, business_invitations.role
   FROM public.business_invitations WHERE token_hash = p_token_hash AND status = 'pending' AND expires_at > now();
$$;
REVOKE ALL ON FUNCTION auth_resolve_invitation(bytea) FROM PUBLIC;

-- I3 fix: not a cross-tenant oracle — p_user_id must be the caller's OWN id (the authenticated user from the
-- validated token); restricted to the API/BFF path by EXECUTE grant, documented here rather than re-checked
-- inside (there is no "other user's token" to compare against at this layer).
CREATE OR REPLACE FUNCTION auth_list_user_memberships(p_user_id uuid)
RETURNS TABLE (business_id uuid, role text, status text, permissions jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT business_members.business_id, business_members.role, business_members.status, business_members.permissions
   FROM public.business_members WHERE user_id = p_user_id AND status = 'active';
$$;
REVOKE ALL ON FUNCTION auth_list_user_memberships(uuid) FROM PUBLIC;

DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format(
    'REVOKE ALL ON FUNCTION auth_resolve_api_key(bytea), auth_resolve_invitation(bytea), auth_list_user_memberships(uuid) FROM %I, %I',
    db || '_app', db || '_worker'); -- claw back the C0001 default-privilege auto-grant before re-granting below
  EXECUTE format('GRANT EXECUTE ON FUNCTION auth_resolve_api_key(bytea), auth_resolve_invitation(bytea), auth_list_user_memberships(uuid) TO %I', db || '_app');
END $$;

-- I1/I2 fix: flags and status/trust/verified changes are admin-gated functions, not raw column grants to the
-- API role. Emits identity.feature_flag.changed itself (trigger below), because flags are written by several
-- principals (seed, this function, future admin UI) and the event must never be skipped.
CREATE OR REPLACE FUNCTION set_feature_flag(p_key text, p_business_id uuid, p_enabled boolean, p_actor_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_actor_role text;
BEGIN
  SELECT platform_role INTO v_actor_role FROM public.users WHERE id = p_actor_user_id AND status = 'active';
  IF v_actor_role IS DISTINCT FROM 'web_master' THEN
    RAISE EXCEPTION 'set_feature_flag: actor is not an active web_master' USING ERRCODE = '55000';
  END IF;

  INSERT INTO public.feature_flags (key, business_id, enabled, source_version)
  VALUES (p_key, p_business_id, p_enabled, 1)
  ON CONFLICT (key, business_id) DO UPDATE
    SET enabled = EXCLUDED.enabled, source_version = public.feature_flags.source_version + 1, updated_at = now();

  INSERT INTO app.audit_log (tenant_id, actor_kind, actor_id, action, entity, entity_id, details)
  VALUES (p_business_id, 'admin_user', p_actor_user_id, 'identity.feature_flag.set', 'feature_flags', NULL,
          jsonb_build_object('key', p_key, 'businessId', p_business_id, 'enabled', p_enabled));
END;
$$;
REVOKE ALL ON FUNCTION set_feature_flag(text, uuid, boolean, uuid) FROM PUBLIC;
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('REVOKE ALL ON FUNCTION set_feature_flag(text, uuid, boolean, uuid) FROM %I, %I', db || '_app', db || '_worker');
  EXECUTE format('GRANT EXECUTE ON FUNCTION set_feature_flag(text, uuid, boolean, uuid) TO %I', db || '_admin');
END $$;

CREATE OR REPLACE FUNCTION emit_feature_flag_event() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_key text; v_business_id uuid; v_enabled boolean; v_version bigint; v_removed boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_key := OLD.key; v_business_id := OLD.business_id; v_enabled := OLD.enabled; v_version := OLD.source_version; v_removed := true;
  ELSE
    IF TG_OP = 'UPDATE' AND NEW.enabled IS NOT DISTINCT FROM OLD.enabled THEN
      RETURN NEW; -- no-op update emits nothing
    END IF;
    v_key := NEW.key; v_business_id := NEW.business_id; v_enabled := NEW.enabled; v_version := NEW.source_version; v_removed := false;
  END IF;

  INSERT INTO app.outbox (event_type, source, tenant_id, aggregate_version, payload)
  VALUES ('identity.feature_flag.changed', 'identity-access', v_business_id, v_version,
          jsonb_build_object('key', v_key, 'scope', CASE WHEN v_business_id IS NULL THEN 'global' ELSE 'business' END,
                              'businessId', v_business_id, 'enabled', v_enabled, 'removed', v_removed, 'version', v_version));
  RETURN COALESCE(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_feature_flags_outbox AFTER INSERT OR UPDATE OR DELETE ON feature_flags
FOR EACH ROW EXECUTE FUNCTION emit_feature_flag_event();

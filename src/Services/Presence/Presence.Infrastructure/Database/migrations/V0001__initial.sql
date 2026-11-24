-- V0001__initial.sql — presence schema (docs/02-data/presence.md). Public business profiles, reviews with
-- DB-enforced eligibility, moderation queue, Bayesian rating. Schema `pub` holds anonymous-safe views only.
-- Roles.conf: client -> presence_client (P1 fix: own role, not extra policies on presence_app).
-- presence_admin is the standard, already-bootstrapped _admin role — the web-master moderation path (P2/P3x fix).

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE SCHEMA IF NOT EXISTS pub;

-- =================================================================================================================
-- 1. Business profiles
-- =================================================================================================================

CREATE TABLE business_profiles (
  business_id uuid PRIMARY KEY, -- tenant key; this IS the business
  name text NOT NULL,
  slug text NOT NULL,
  verified_at timestamptz,
  wilaya_dataset_version int,
  wilaya_code text,
  public_phone text,
  public_email text,
  description text,
  categories text[] NOT NULL DEFAULT '{}',
  show_products boolean NOT NULL DEFAULT false,
  logo_file_id uuid,
  cover_file_id uuid,
  is_published boolean NOT NULL DEFAULT false,
  rating_sum numeric(10, 0) NOT NULL DEFAULT 0, -- D3: raw sum; Bayesian value computed in pub.business_profiles
  rating_count int NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
  identity_source_version bigint NOT NULL DEFAULT 0,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (wilaya_dataset_version, wilaya_code) REFERENCES ref.wilayas (dataset_version, code),
  FOREIGN KEY (logo_file_id) REFERENCES app.files (id) ON DELETE SET NULL,
  FOREIGN KEY (cover_file_id) REFERENCES app.files (id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX uq_business_profiles_slug ON business_profiles (slug); -- global by nature: /b/{slug}
CREATE INDEX ix_business_profiles_name_trgm ON business_profiles USING gin (name gin_trgm_ops) WHERE is_published;
CREATE INDEX ix_business_profiles_wilaya ON business_profiles (wilaya_code) WHERE is_published;
CREATE INDEX ix_business_profiles_categories ON business_profiles USING gin (categories) WHERE is_published;
SELECT app.add_updated_at_trigger('business_profiles');
SELECT app.enable_tenant_rls('business_profiles');

-- Staff cannot write the rating aggregate or the identity-sourced copy columns directly.
DO $$ DECLARE db text := current_database(); app_r text := current_database() || '_app'; BEGIN
  EXECUTE format('REVOKE UPDATE ON business_profiles FROM %I', app_r);
  EXECUTE format(
    'GRANT UPDATE (public_phone, public_email, description, categories, show_products, logo_file_id, cover_file_id, is_published, version, updated_at) ON business_profiles TO %I',
    app_r); -- name/slug/verified_at/wilaya_*/rating_*/identity_source_version excluded: identity-sourced or trigger-maintained
  EXECUTE format(
    'GRANT UPDATE (name, slug, verified_at, wilaya_dataset_version, wilaya_code, identity_source_version) ON business_profiles TO %I',
    db || '_worker'); -- identity.business.* consumer only
END $$;

CREATE TABLE business_profile_gallery (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  file_id uuid NOT NULL,
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id) REFERENCES business_profiles (business_id) ON DELETE CASCADE,
  FOREIGN KEY (business_id, file_id) REFERENCES app.files (business_id, id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX uq_business_profile_gallery_pos ON business_profile_gallery (business_id, position);
CREATE INDEX ix_business_profile_gallery_file ON business_profile_gallery (business_id, file_id);
SELECT app.enable_tenant_rls('business_profile_gallery');

-- =================================================================================================================
-- 2. Review eligibility (DB-enforced, §7.1) and the phone-verification read model
-- =================================================================================================================

CREATE OR REPLACE FUNCTION net_guard_source_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.source_version <= OLD.source_version THEN
    RAISE EXCEPTION '%: stale version % <= %', TG_TABLE_NAME, NEW.source_version, OLD.source_version USING ERRCODE = '40001';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TABLE client_verified_phones (
  user_id uuid PRIMARY KEY, -- opaque ref: identity_access.users
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_client_verified_phones_hash ON client_verified_phones (phone_hash);

ALTER TABLE client_verified_phones ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_verified_phones FORCE ROW LEVEL SECURITY;
CREATE TRIGGER trg_client_verified_phones_version BEFORE UPDATE ON client_verified_phones
FOR EACH ROW EXECUTE FUNCTION net_guard_source_version();
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format(
    'CREATE POLICY client_own_select ON client_verified_phones FOR SELECT TO %I USING (user_id = app.current_user_id())',
    db || '_client');
  EXECUTE format('CREATE POLICY worker_all ON client_verified_phones FOR ALL TO %I, %I USING (true) WITH CHECK (true)',
    db || '_worker', db || '_admin');
  EXECUTE format('GRANT SELECT ON client_verified_phones TO %I', db || '_client');
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON client_verified_phones TO %I, %I', db || '_worker', db || '_admin');
END $$;

CREATE TABLE review_eligibility (
  business_id uuid NOT NULL,
  basis text NOT NULL CHECK (basis IN ('order', 'conversation')),
  interaction_id uuid NOT NULL, -- opaque ref: orders.orders or messaging.conversations
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  source_version bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, basis, interaction_id)
);
CREATE INDEX ix_review_eligibility_phone ON review_eligibility (business_id, phone_hash);
CREATE INDEX ix_review_eligibility_client ON review_eligibility (phone_hash); -- cross-business by nature: client "review your orders"
SELECT app.add_updated_at_trigger('review_eligibility');
SELECT app.enable_tenant_rls('review_eligibility');
CREATE TRIGGER trg_review_eligibility_version BEFORE UPDATE ON review_eligibility
FOR EACH ROW EXECUTE FUNCTION net_guard_source_version();

-- RLS by business AND a client-visibility path (client sees eligibility rows matching ITS verified phone).
DO $$ DECLARE cli text := current_database() || '_client'; BEGIN
  EXECUTE format(
    'CREATE POLICY client_select ON review_eligibility FOR SELECT TO %I USING (phone_hash IN (SELECT phone_hash FROM client_verified_phones WHERE user_id = app.current_user_id()))',
    cli);
  EXECUTE format('GRANT SELECT ON review_eligibility TO %I', cli);
END $$;

-- =================================================================================================================
-- 3. Reviews, replies, reports
-- =================================================================================================================

CREATE TABLE reviews (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  author_user_id uuid NOT NULL, -- opaque ref: identity_access.users
  author_display_name text NOT NULL, -- public page shows this, never the user id (D9)
  basis text NOT NULL CHECK (basis IN ('order', 'conversation')),
  interaction_id uuid NOT NULL,
  rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title text,
  body text,
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published', 'hidden', 'removed')),
  moderation_reason text,
  moderated_at timestamptz,
  moderated_by uuid, -- opaque ref: identity_access.users (web_master)
  edited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  UNIQUE (business_id, basis, interaction_id), -- D5: one review per order/conversation
  FOREIGN KEY (business_id, basis, interaction_id) REFERENCES review_eligibility (business_id, basis, interaction_id)
);
CREATE INDEX ix_reviews_business ON reviews (business_id, status, created_at DESC);
CREATE INDEX ix_reviews_author ON reviews (author_user_id, created_at DESC);
SELECT app.add_updated_at_trigger('reviews');
SELECT app.enable_tenant_rls('reviews');

-- D10: no staff UPDATE policy on reviews at all (business cannot delete/hide its own reviews). Staff keeps the
-- default SELECT (from tenant_isolation) and INSERT is never used by staff; revoke INSERT/UPDATE outright.
DO $$ DECLARE app_r text := current_database() || '_app'; adm text := current_database() || '_admin'; cli text := current_database() || '_client'; BEGIN
  EXECUTE format('REVOKE INSERT, UPDATE ON reviews FROM %I', app_r);

  EXECUTE format(
    'CREATE POLICY client_select ON reviews FOR SELECT TO %I USING (author_user_id = app.current_user_id())',
    cli);
  EXECUTE format(
    'CREATE POLICY client_insert ON reviews FOR INSERT TO %I WITH CHECK (author_user_id = app.current_user_id() AND EXISTS (SELECT 1 FROM review_eligibility re WHERE re.business_id = reviews.business_id AND re.basis = reviews.basis AND re.interaction_id = reviews.interaction_id AND re.phone_hash IN (SELECT phone_hash FROM client_verified_phones WHERE user_id = app.current_user_id())))',
    cli);
  EXECUTE format('CREATE POLICY client_update ON reviews FOR UPDATE TO %I USING (author_user_id = app.current_user_id())', cli);
  EXECUTE format('GRANT SELECT, INSERT ON reviews TO %I', cli);
  EXECUTE format('GRANT UPDATE (title, body, rating, edited_at) ON reviews TO %I', cli); -- content only, never status/moderation

  EXECUTE format('CREATE POLICY admin_all ON reviews FOR ALL TO %I USING (true) WITH CHECK (true)', adm);
  EXECUTE format('GRANT SELECT ON reviews TO %I', adm);
  EXECUTE format('GRANT UPDATE (status, moderation_reason, moderated_at, moderated_by) ON reviews TO %I', adm); -- moderation only, never content
END $$;

-- Content vs. moderation columns stay strictly separated regardless of grants (defense in depth): a client can
-- only touch content+edited_at, an admin only moderation columns — matching messaging's guard_client_update.
CREATE OR REPLACE FUNCTION guard_review_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE content_changed boolean; moderation_changed boolean;
BEGIN
  content_changed := (NEW.title, NEW.body, NEW.rating) IS DISTINCT FROM (OLD.title, OLD.body, OLD.rating);
  moderation_changed := (NEW.status, NEW.moderation_reason, NEW.moderated_at, NEW.moderated_by) IS DISTINCT FROM (OLD.status, OLD.moderation_reason, OLD.moderated_at, OLD.moderated_by);
  IF current_user = current_database() || '_client' AND moderation_changed THEN
    RAISE EXCEPTION 'guard_review_update: client cannot change moderation columns' USING ERRCODE = '55000';
  END IF;
  IF current_user = current_database() || '_admin' AND content_changed THEN
    RAISE EXCEPTION 'guard_review_update: admin cannot edit review content' USING ERRCODE = '55000';
  END IF;
  IF content_changed THEN
    NEW.edited_at := now();
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_reviews_update_guard BEFORE UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION guard_review_update();

CREATE TABLE review_replies (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  review_id uuid NOT NULL,
  author_member_id uuid, -- opaque ref: identity_access.business_members
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, review_id) REFERENCES reviews (business_id, id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX uq_review_replies_review ON review_replies (business_id, review_id); -- reply once
SELECT app.add_updated_at_trigger('review_replies');
SELECT app.enable_tenant_rls('review_replies');

CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  target_type text NOT NULL CHECK (target_type IN ('review', 'business_profile', 'conversation')),
  review_id uuid,
  target_business_id uuid NOT NULL, -- opaque ref: identity_access.businesses
  conversation_id uuid, -- opaque ref: messaging.conversations
  reporter_business_id uuid, -- opaque ref: identity_access.businesses (staff reporter)
  reporter_user_id uuid, -- opaque ref: identity_access.users (client reporter)
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'dismissed', 'actioned')),
  resolution_note text,
  resolved_at timestamptz,
  resolved_by uuid, -- opaque ref: identity_access.users (web_master)
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (target_business_id, review_id) REFERENCES reviews (business_id, id),
  CHECK (num_nonnulls(reporter_business_id, reporter_user_id) = 1)
);
CREATE UNIQUE INDEX ux_reports_open_per_reporter ON reports (target_business_id, review_id, reporter_business_id, reporter_user_id)
  NULLS NOT DISTINCT WHERE status = 'open'; -- exactly one of reporter_business_id/reporter_user_id is ever non-NULL (CHECK above)
CREATE INDEX ix_reports_queue ON reports (created_at) WHERE status = 'open';
CREATE INDEX ix_reports_target ON reports (target_business_id, review_id);

-- Platform queue, not tenant-RLS'd by business_id: a reporter sees its own reports; admin sees everything.
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports FORCE ROW LEVEL SECURITY;
DO $$ DECLARE app_r text := current_database() || '_app'; cli text := current_database() || '_client'; adm text := current_database() || '_admin'; BEGIN
  EXECUTE format('CREATE POLICY staff_own_reports ON reports FOR SELECT TO %I USING (reporter_business_id = app.current_business_id())', app_r);
  EXECUTE format('CREATE POLICY staff_insert ON reports FOR INSERT TO %I WITH CHECK (reporter_business_id = app.current_business_id() AND reporter_user_id IS NULL)', app_r);
  EXECUTE format('CREATE POLICY client_own_reports ON reports FOR SELECT TO %I USING (reporter_user_id = app.current_user_id())', cli);
  EXECUTE format('CREATE POLICY client_insert ON reports FOR INSERT TO %I WITH CHECK (reporter_user_id = app.current_user_id() AND reporter_business_id IS NULL)', cli);
  EXECUTE format('CREATE POLICY admin_all ON reports FOR ALL TO %I USING (true) WITH CHECK (true)', adm);
  EXECUTE format('GRANT SELECT, INSERT ON reports TO %I, %I', app_r, cli);
  EXECUTE format('GRANT SELECT, UPDATE (status, resolution_note, resolved_at, resolved_by) ON reports TO %I', adm);
END $$;

-- =================================================================================================================
-- 4. Rating parameters (platform singleton) and the maintenance functions
-- =================================================================================================================

CREATE TABLE rating_parameters (
  key text PRIMARY KEY DEFAULT 'current',
  c_constant numeric(10, 4) NOT NULL, -- minimum votes before the raw average dominates (§7.1)
  m_mean numeric(4, 3) NOT NULL CHECK (m_mean BETWEEN 0 AND 5), -- platform-wide mean rating
  updated_at timestamptz NOT NULL DEFAULT now()
);
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('GRANT SELECT ON rating_parameters TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');
  EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON rating_parameters FROM %I, %I', db || '_app', db || '_worker');
END $$;

-- Trigger-maintained rating aggregate: SECURITY DEFINER so the staff role never needs direct write access to it.
CREATE OR REPLACE FUNCTION reviews_maintain_rating() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_business uuid := COALESCE(NEW.business_id, OLD.business_id);
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'published' THEN
    UPDATE public.business_profiles SET rating_sum = rating_sum + NEW.rating, rating_count = rating_count + 1 WHERE business_id = v_business;
  ELSIF TG_OP = 'DELETE' AND OLD.status = 'published' THEN
    UPDATE public.business_profiles SET rating_sum = rating_sum - OLD.rating, rating_count = rating_count - 1 WHERE business_id = v_business;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'published' AND NEW.status <> 'published' THEN
      UPDATE public.business_profiles SET rating_sum = rating_sum - OLD.rating, rating_count = rating_count - 1 WHERE business_id = v_business;
    ELSIF OLD.status <> 'published' AND NEW.status = 'published' THEN
      UPDATE public.business_profiles SET rating_sum = rating_sum + NEW.rating, rating_count = rating_count + 1 WHERE business_id = v_business;
    ELSIF OLD.status = 'published' AND NEW.status = 'published' AND NEW.rating <> OLD.rating THEN
      UPDATE public.business_profiles SET rating_sum = rating_sum - OLD.rating + NEW.rating WHERE business_id = v_business;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_reviews_maintain_rating AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW EXECUTE FUNCTION reviews_maintain_rating();

CREATE OR REPLACE FUNCTION refresh_rating_parameters() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_mean numeric;
BEGIN
  SELECT coalesce(avg(rating_sum::numeric / NULLIF(rating_count, 0)), 0) INTO v_mean
   FROM public.business_profiles WHERE rating_count > 0;
  UPDATE public.rating_parameters SET m_mean = v_mean, updated_at = now() WHERE key = 'current';
END;
$$;
REVOKE ALL ON FUNCTION refresh_rating_parameters() FROM PUBLIC;
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('REVOKE ALL ON FUNCTION refresh_rating_parameters() FROM %I, %I', db || '_app', db || '_worker');
  EXECUTE format('GRANT EXECUTE ON FUNCTION refresh_rating_parameters() TO %I', db || '_admin');
END $$;

-- =================================================================================================================
-- 5. Anonymous public surface (schema pub — views only, owner BYPASSRLS, explicit safe column lists)
-- =================================================================================================================

CREATE VIEW pub.business_profiles AS
SELECT
  bp.business_id, bp.name, bp.slug, bp.verified_at, bp.wilaya_dataset_version, bp.wilaya_code,
  bp.public_phone, bp.public_email, bp.description, bp.categories, bp.show_products,
  bp.logo_file_id, bp.cover_file_id,
  CASE WHEN bp.rating_count > 0
    THEN round((rp.c_constant * rp.m_mean + bp.rating_sum) / (rp.c_constant + bp.rating_count), 2)
    ELSE NULL END AS rating_bayesian,
  round(CASE WHEN bp.rating_count > 0 THEN bp.rating_sum::numeric / bp.rating_count ELSE NULL END, 2) AS rating_raw_avg,
  bp.rating_count
FROM business_profiles bp
JOIN app.tenants t ON t.business_id = bp.business_id AND t.status = 'active'
CROSS JOIN rating_parameters rp
WHERE bp.is_published AND rp.key = 'current';

CREATE VIEW pub.reviews AS
SELECT r.id, r.business_id, r.author_display_name, r.rating, r.title, r.body, r.created_at, rr.body AS reply_body
FROM reviews r
JOIN pub.business_profiles pbp ON pbp.business_id = r.business_id
LEFT JOIN review_replies rr ON rr.business_id = r.business_id AND rr.review_id = r.id
WHERE r.status = 'published';

GRANT USAGE ON SCHEMA pub TO PUBLIC;
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('GRANT SELECT ON pub.business_profiles, pub.reviews TO %I, %I, %I', db || '_app', db || '_client', db || '_admin');
END $$;

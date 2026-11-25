-- V0001__initial.sql — messaging schema (docs/02-data/messaging.md). Two RLS paths: staff (tenant_isolation) and
-- client (client_user_id = app.current_user_id()), permissive and OR'd. M1 fix: the client path is a SEPARATE
-- role (messaging_client), not messaging_app with extra policies — a DB grant boundary survives an app bug that
-- a policy alone would not.
-- Roles.conf: client -> messaging_client.

-- =================================================================================================================
-- 1. Conversations and messages
-- =================================================================================================================

CREATE TABLE conversations (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  channel text NOT NULL CHECK (channel IN ('in_app', 'whatsapp')),
  client_user_id uuid, -- opaque ref: identity_access.users
  contact_id uuid, -- opaque ref: crm.contacts (D5: nullable, linked async)
  contact_display_name text,
  wa_connection_id uuid, -- opaque ref: integrations.integration_connections
  phone_raw text,
  phone_e164 text CHECK (phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
  phone_hash bytea CHECK (phone_hash IS NULL OR octet_length(phone_hash) = 32),
  pepper_version int, -- ADR-0002 amendment / S16; all-or-none with phone_hash
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  assigned_member_id uuid, -- opaque ref: identity_access.business_members
  client_message_count int NOT NULL DEFAULT 0,
  member_message_count int NOT NULL DEFAULT 0,
  unread_staff_count int NOT NULL DEFAULT 0,
  unread_client_count int NOT NULL DEFAULT 0,
  staff_last_read_at timestamptz,
  client_last_read_at timestamptz,
  blocked_at timestamptz,
  blocked_by uuid, -- opaque ref: identity_access.business_members or users (web_master)
  last_message_at timestamptz,
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id),
  CHECK (channel = 'whatsapp' OR (wa_connection_id IS NULL AND phone_hash IS NULL)),
  CHECK ((phone_hash IS NULL) = (pepper_version IS NULL))
);
CREATE UNIQUE INDEX ux_conversations_in_app_client ON conversations (business_id, client_user_id) WHERE channel = 'in_app';
CREATE UNIQUE INDEX ux_conversations_whatsapp_phone ON conversations (business_id, wa_connection_id, phone_hash) WHERE channel = 'whatsapp';
CREATE INDEX ix_conversations_inbox ON conversations (business_id, status, last_message_at DESC);
CREATE INDEX ix_conversations_assignee ON conversations (business_id, assigned_member_id, last_message_at DESC);
CREATE INDEX ix_conversations_contact ON conversations (business_id, contact_id);
CREATE INDEX ix_conversations_client ON conversations (client_user_id, last_message_at DESC); -- D9-style exception: cross-tenant by nature
SELECT app.add_updated_at_trigger('conversations');
SELECT app.enable_tenant_rls('conversations'); -- staff path

-- Client path: a second, role-scoped permissive policy set (OR'd with tenant_isolation above).
DO $$ DECLARE cli text := current_database() || '_client'; BEGIN
  EXECUTE format('CREATE POLICY client_select ON conversations FOR SELECT TO %I USING (client_user_id = app.current_user_id())', cli);
  EXECUTE format(
    'CREATE POLICY client_insert ON conversations FOR INSERT TO %I WITH CHECK (client_user_id = app.current_user_id() AND channel = ''in_app'' AND assigned_member_id IS NULL AND blocked_at IS NULL)',
    cli);
  EXECUTE format('CREATE POLICY client_update ON conversations FOR UPDATE TO %I USING (client_user_id = app.current_user_id())', cli);
  EXECUTE format('GRANT SELECT, INSERT ON conversations TO %I', cli);
  EXECUTE format('GRANT UPDATE (client_last_read_at, unread_client_count) ON conversations TO %I', cli);
END $$;

-- Defense in depth: even if a future grant is too broad, this role can only ever touch read markers/counters.
CREATE OR REPLACE FUNCTION guard_client_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user = current_database() || '_client' THEN
    IF (to_jsonb(NEW) - 'client_last_read_at' - 'unread_client_count') IS DISTINCT FROM (to_jsonb(OLD) - 'client_last_read_at' - 'unread_client_count') THEN
      RAISE EXCEPTION 'guard_client_update: client may only change its own read markers/counters' USING ERRCODE = '55000';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_conversations_client_guard BEFORE UPDATE ON conversations
FOR EACH ROW EXECUTE FUNCTION guard_client_update();

CREATE TABLE message_templates (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  connection_id uuid, -- opaque ref: integrations.integration_connections
  name text NOT NULL,
  purpose text NOT NULL CHECK (purpose IN ('transactional', 'marketing', 'review_request')),
  consent_purpose text NOT NULL CHECK (consent_purpose IN ('transactional', 'marketing')),
  body_template text NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending_approval', 'approved', 'rejected')),
  version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, id)
);
CREATE INDEX ix_message_templates_purpose ON message_templates (business_id, purpose) WHERE status = 'approved';
SELECT app.add_updated_at_trigger('message_templates');
SELECT app.enable_tenant_rls('message_templates');

CREATE TABLE messages (
  id uuid NOT NULL DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  sender_type text NOT NULL CHECK (sender_type IN ('staff', 'client', 'system')),
  sender_member_id uuid, -- opaque ref: identity_access.business_members
  body text,
  template_id uuid,
  template_params jsonb,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('pending', 'sent', 'delivered', 'read', 'failed')),
  attachment_count int NOT NULL DEFAULT 0,
  redacted_at timestamptz,
  sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, sent_at),
  FOREIGN KEY (business_id, conversation_id) REFERENCES conversations (business_id, id),
  FOREIGN KEY (business_id, template_id) REFERENCES message_templates (business_id, id)
) PARTITION BY RANGE (sent_at);
CREATE INDEX ix_messages_thread ON messages (business_id, conversation_id, sent_at DESC);
CREATE INDEX ix_messages_pending ON messages (business_id, sent_at) WHERE status = 'pending';
SELECT app.enable_tenant_rls('messages');

DO $$ DECLARE cli text := current_database() || '_client'; BEGIN
  -- Client may SELECT any message in a thread it owns, INSERT only its own sender_type='client' messages into
  -- an open, non-blocked thread it owns, and (via the column grant) flip status to 'read' on staff messages.
  EXECUTE format(
    'CREATE POLICY client_select ON messages FOR SELECT TO %I USING (EXISTS (SELECT 1 FROM conversations c WHERE c.business_id = messages.business_id AND c.id = messages.conversation_id AND c.client_user_id = app.current_user_id()))',
    cli);
  EXECUTE format(
    'CREATE POLICY client_insert ON messages FOR INSERT TO %I WITH CHECK (sender_type = ''client'' AND EXISTS (SELECT 1 FROM conversations c WHERE c.business_id = messages.business_id AND c.id = messages.conversation_id AND c.client_user_id = app.current_user_id() AND c.status = ''open'' AND c.blocked_at IS NULL))',
    cli);
  EXECUTE format(
    'CREATE POLICY client_update ON messages FOR UPDATE TO %I USING (sender_type <> ''client'' AND EXISTS (SELECT 1 FROM conversations c WHERE c.business_id = messages.business_id AND c.id = messages.conversation_id AND c.client_user_id = app.current_user_id()))',
    cli);
  -- No DELETE grant on sent_at/status/redacted_at/attachment_count: client cannot backdate or forge delivery
  -- state. Only body/sender_type/conversation_id/id/business_id may be supplied on INSERT (defaults cover the rest).
  EXECUTE format('GRANT SELECT, INSERT (id, business_id, conversation_id, sender_type, body) ON messages TO %I', cli);
  EXECUTE format('GRANT UPDATE (status) ON messages TO %I', cli); -- read receipts only (status -> read)
END $$;

-- Redaction may only set body/template_params to NULL, once, together with redacted_at (irreversible, X5-style).
CREATE OR REPLACE FUNCTION guard_message_redaction() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (NEW.body IS DISTINCT FROM OLD.body OR NEW.template_params IS DISTINCT FROM OLD.template_params) THEN
    IF NEW.body IS NOT NULL OR NEW.template_params IS NOT NULL OR OLD.redacted_at IS NOT NULL OR NEW.redacted_at IS NULL THEN
      RAISE EXCEPTION 'guard_message_redaction: body/template_params may only be set to NULL once, with redacted_at' USING ERRCODE = '55000';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_messages_redaction_guard BEFORE UPDATE ON messages
FOR EACH ROW EXECUTE FUNCTION guard_message_redaction();
SELECT app.make_append_only('messages', ARRAY['status', 'redacted_at', 'body', 'template_params']);
-- The client's column-level UPDATE(status) grant above must survive make_append_only's blanket revoke+regrant.
DO $$ DECLARE cli text := current_database() || '_client'; BEGIN
  EXECUTE format('GRANT UPDATE (status) ON messages TO %I', cli);
END $$;
SELECT app.ensure_monthly_partitions('messages');

CREATE TABLE message_external_ids (
  external_message_id text PRIMARY KEY, -- global (D3): a partitioned-table UNIQUE must include sent_at, which a redelivery in another month would bypass
  business_id uuid NOT NULL,
  message_id uuid NOT NULL,
  message_sent_at timestamptz NOT NULL, -- pointer into messages, no FK (partition detach)
  created_at timestamptz NOT NULL DEFAULT now()
);
SELECT app.enable_tenant_rls('message_external_ids');
SELECT app.make_append_only('message_external_ids', '{}');

CREATE TABLE message_attachments (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  business_id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  message_id uuid NOT NULL,
  message_sent_at timestamptz NOT NULL, -- pointer into messages, no FK
  file_id uuid NOT NULL,
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (business_id, conversation_id) REFERENCES conversations (business_id, id),
  FOREIGN KEY (business_id, file_id) REFERENCES app.files (business_id, id)
);
CREATE UNIQUE INDEX uq_message_attachments_pos ON message_attachments (business_id, message_id, message_sent_at, position);
CREATE INDEX ix_message_attachments_file ON message_attachments (business_id, file_id);
SELECT app.enable_tenant_rls('message_attachments');
SELECT app.make_append_only('message_attachments', '{}');

DO $$ DECLARE cli text := current_database() || '_client'; BEGIN
  EXECUTE format(
    'CREATE POLICY client_select ON message_attachments FOR SELECT TO %I USING (EXISTS (SELECT 1 FROM conversations c WHERE c.business_id = message_attachments.business_id AND c.id = message_attachments.conversation_id AND c.client_user_id = app.current_user_id()))',
    cli);
  EXECUTE format(
    'CREATE POLICY client_insert ON message_attachments FOR INSERT TO %I WITH CHECK (EXISTS (SELECT 1 FROM conversations c WHERE c.business_id = message_attachments.business_id AND c.id = message_attachments.conversation_id AND c.client_user_id = app.current_user_id()))',
    cli);
  EXECUTE format('GRANT SELECT, INSERT ON message_attachments TO %I', cli);
END $$;

-- R2 (local workaround): app.files needs an extra permissive policy for a client uploader/reader, scoped to
-- files actually attached inside one of that client's own conversations.
DO $$ DECLARE cli text := current_database() || '_client'; BEGIN
  EXECUTE format('GRANT USAGE ON SCHEMA app TO %I', cli);
  EXECUTE format(
    'CREATE POLICY messaging_client_attachment ON app.files FOR SELECT TO %I USING (purpose = ''attachment'' AND EXISTS (SELECT 1 FROM message_attachments ma JOIN conversations c ON c.business_id = ma.business_id AND c.id = ma.conversation_id WHERE ma.file_id = app.files.id AND ma.business_id = app.files.business_id AND c.client_user_id = app.current_user_id()))',
    cli);
  EXECUTE format('GRANT SELECT ON app.files TO %I', cli);
END $$;

-- =================================================================================================================
-- 2. Consent read model
-- =================================================================================================================

CREATE TABLE channel_consent_states (
  business_id uuid NOT NULL,
  phone_hash bytea NOT NULL CHECK (octet_length(phone_hash) = 32),
  channel text NOT NULL CHECK (channel IN ('whatsapp', 'sms', 'email')),
  purpose text NOT NULL CHECK (purpose IN ('transactional', 'marketing')),
  decision text NOT NULL CHECK (decision IN ('granted', 'withdrawn')),
  stop_received_at timestamptz, -- local STOP keyword, sticky even if a later consent event says granted
  source_version bigint NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (business_id, phone_hash, channel, purpose)
);
SELECT app.enable_tenant_rls('channel_consent_states');

CREATE OR REPLACE FUNCTION guard_consent_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.source_version <= OLD.source_version THEN
    RAISE EXCEPTION 'channel_consent_states: stale version % <= %', NEW.source_version, OLD.source_version USING ERRCODE = '40001';
  END IF;
  -- Sticky local opt-out (S6-style): once STOP is received, a later "granted" event cannot silently re-enable.
  -- stop_received_at carries forward automatically (not in the caller's SET list) unless explicitly cleared.
  IF TG_OP = 'UPDATE' AND OLD.stop_received_at IS NOT NULL AND NEW.stop_received_at IS NOT NULL AND NEW.decision = 'granted' THEN
    NEW.decision := 'withdrawn';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_consent_version BEFORE UPDATE ON channel_consent_states
FOR EACH ROW EXECUTE FUNCTION guard_consent_version();

-- =================================================================================================================
-- 3. Notifications (RLS by RECIPIENT, not tenant — D9)
-- =================================================================================================================

CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  user_id uuid NOT NULL, -- opaque ref: identity_access.users (the recipient)
  business_id uuid, -- nullable: platform/client notifications have none
  type text NOT NULL,
  title text NOT NULL,
  body text,
  read_at timestamptz,
  delivery_status text CHECK (delivery_status IN ('pending', 'sending', 'sent', 'failed', 'not_applicable')),
  attempts int NOT NULL DEFAULT 0,
  claimed_until timestamptz,
  last_error text,
  source_event_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_notifications_user ON notifications (user_id, created_at DESC);
CREATE INDEX ix_notifications_unread ON notifications (user_id) WHERE read_at IS NULL;
CREATE INDEX ix_notifications_email_queue ON notifications (claimed_until) WHERE delivery_status IN ('pending', 'sending');
CREATE INDEX ix_notifications_created ON notifications USING brin (created_at);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications FORCE ROW LEVEL SECURITY;
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format(
    'CREATE POLICY notifications_recipient_select ON notifications FOR SELECT TO %I, %I USING (user_id = app.current_user_id())',
    db || '_app', db || '_client');
  EXECUTE format(
    'CREATE POLICY notifications_recipient_update ON notifications FOR UPDATE TO %I, %I USING (user_id = app.current_user_id())',
    db || '_app', db || '_client');
  EXECUTE format('CREATE POLICY notifications_worker_all ON notifications FOR ALL TO %I, %I USING (true) WITH CHECK (true)',
    db || '_worker', db || '_admin');
  EXECUTE format('GRANT SELECT ON notifications TO %I, %I', db || '_app', db || '_client');
  EXECUTE format('GRANT UPDATE (read_at) ON notifications TO %I, %I', db || '_app', db || '_client'); -- mark-as-read only
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON notifications TO %I, %I', db || '_worker', db || '_admin');
END $$;
SELECT app.make_append_only('notifications', ARRAY['read_at', 'delivery_status', 'attempts', 'claimed_until', 'last_error']);
-- The recipient's column-level UPDATE(read_at) grant must survive make_append_only's blanket revoke+regrant.
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('GRANT UPDATE (read_at) ON notifications TO %I, %I', db || '_app', db || '_client');
END $$;

CREATE TABLE notification_preferences (
  user_id uuid NOT NULL,
  event_type text NOT NULL,
  channel text NOT NULL CHECK (channel IN ('in_app', 'email')),
  enabled boolean NOT NULL DEFAULT true,
  PRIMARY KEY (user_id, event_type, channel)
);
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences FORCE ROW LEVEL SECURITY;
DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format(
    'CREATE POLICY prefs_recipient_all ON notification_preferences FOR ALL TO %I, %I USING (user_id = app.current_user_id()) WITH CHECK (user_id = app.current_user_id())',
    db || '_app', db || '_client');
  EXECUTE format('CREATE POLICY prefs_worker_all ON notification_preferences FOR ALL TO %I, %I USING (true) WITH CHECK (true)',
    db || '_worker', db || '_admin');
  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON notification_preferences TO %I, %I, %I, %I',
    db || '_app', db || '_client', db || '_worker', db || '_admin');
END $$;

-- M3 fix: worker-only (not the API role) — the earlier design let any API session claim all users' payloads.
CREATE OR REPLACE FUNCTION claim_email_notifications(p_limit int DEFAULT 50)
RETURNS TABLE (notification_id uuid, user_id uuid, business_id uuid, type text, title text, body text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  UPDATE public.notifications n SET delivery_status = 'sending', claimed_until = now() + interval '5 minutes', attempts = attempts + 1
  FROM (
    SELECT id FROM public.notifications
     WHERE delivery_status = 'pending' AND (claimed_until IS NULL OR claimed_until < now())
     ORDER BY created_at LIMIT p_limit FOR UPDATE SKIP LOCKED
  ) picked
  WHERE n.id = picked.id
  RETURNING n.id, n.user_id, n.business_id, n.type, n.title, n.body;
$$;
REVOKE ALL ON FUNCTION claim_email_notifications(int) FROM PUBLIC;

CREATE OR REPLACE FUNCTION complete_email_notification(p_notification_id uuid, p_success boolean, p_error text DEFAULT NULL)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  UPDATE public.notifications
     SET delivery_status = CASE WHEN p_success THEN 'sent' ELSE 'failed' END, last_error = p_error, claimed_until = NULL
   WHERE id = p_notification_id;
$$;
REVOKE ALL ON FUNCTION complete_email_notification(uuid, boolean, text) FROM PUBLIC;

DO $$ DECLARE db text := current_database(); BEGIN
  EXECUTE format('REVOKE ALL ON FUNCTION claim_email_notifications(int), complete_email_notification(uuid, boolean, text) FROM %I, %I',
    db || '_app', db || '_client');
  EXECUTE format('GRANT EXECUTE ON FUNCTION claim_email_notifications(int), complete_email_notification(uuid, boolean, text) TO %I',
    db || '_worker');
END $$;

-- =================================================================================================================
-- 4. Column-grant cleanup (claw back what C0001's default privileges granted beyond what each role should have)
-- =================================================================================================================

DO $$ DECLARE db text := current_database(); app_r text := current_database() || '_app'; BEGIN
  -- Column-level REVOKE alone is a no-op against the whole-table UPDATE grant C0001's default privileges
  -- already gave _app — revoke the whole table, then grant back everything except the counters (which are
  -- trigger/consumer-maintained, never a raw staff UPDATE target) and id/business_id/created_at.
  EXECUTE format('REVOKE UPDATE ON conversations FROM %I', app_r);
  EXECUTE format(
    'GRANT UPDATE (channel, client_user_id, contact_id, contact_display_name, wa_connection_id, phone_raw, phone_e164, phone_hash, pepper_version, status, assigned_member_id, staff_last_read_at, blocked_at, blocked_by, last_message_at, version, updated_at) ON conversations TO %I',
    app_r);
END $$;

-- S0001__permissions_presets_flags.sql — permission catalogue, starter presets, and the initial
-- global_score_visible=false flag (CLAUDE.md §5: off until legal review R1; consumers must start from an
-- explicit OFF rather than treating "row missing" as a default).

INSERT INTO permissions (key, category, description) VALUES
  ('team.manage', 'team', 'Invite, remove and change roles of team members'),
  ('orders.view', 'orders', 'View orders and their status'),
  ('orders.manage', 'orders', 'Confirm, edit and cancel orders'),
  ('score.view', 'scoring', 'View the Contact Score band for a phone number'),
  ('settings.manage', 'settings', 'Change business settings');

INSERT INTO permission_presets (key, name, permission_keys) VALUES
  ('owner', 'Owner', ARRAY['team.manage', 'orders.view', 'orders.manage', 'score.view', 'settings.manage']),
  ('staff_confirmation', 'Confirmation agent', ARRAY['orders.view', 'orders.manage', 'score.view']),
  ('client_readonly', 'Client (read-only)', ARRAY['orders.view']);

INSERT INTO feature_flags (key, business_id, enabled, source_version) VALUES
  ('global_score_visible', NULL, false, 1);

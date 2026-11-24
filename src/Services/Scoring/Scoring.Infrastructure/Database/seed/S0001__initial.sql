-- S0001__initial.sql — bootstrap config. No PII. Every threshold here is [Guessing] (CLAUDE.md §8 rule 5; doc
-- open question Q9) — there is no production data yet to tune against. Revisit at the Phase 2 gate / after the
-- walking skeleton.

INSERT INTO net.settings (key, value_int) VALUES
  ('lookup_rate_per_minute', 30),
  ('lookup_rate_per_day', 2000),
  ('min_order_age_hours', 24),
  ('min_contributors_k', 3),
  ('otp_challenges_per_day', 5),
  ('dispute_freeze_days', 14),
  ('dsr_due_days', 30);

INSERT INTO net.pepper_versions (version, status) VALUES (1, 'active');

-- v1.0: carrier_verified >= webhook_verified >= manual (S13); caps are mandatory keys, enforced by the
-- net.score_models CHECK. Magnitudes are [Guessing] — a smoothed-rate model per the spec's Beta prior (D11),
-- not re-derived here; this seed only needs to satisfy the schema's invariants so the engine has something to
-- run against before Phase 6 implements the real model.
WITH params AS (
  SELECT '{
    "weights": {"carrier_verified": 1.0, "webhook_verified": 0.8, "manual": 0.3},
    "manual_negative_cap": 0.5,
    "per_merchant_cap": 0.4,
    "half_life_days": 180,
    "beta_prior": {"a": 2.1, "b": 0.9}
  }'::jsonb AS p
)
INSERT INTO net.score_models (version, status, params, params_sha256, active_from)
SELECT '1.0', 'active', p, digest(p::text, 'sha256'), now() FROM params;

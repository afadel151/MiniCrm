-- S0001__order_status_transitions.sql — the legal edges for all three machines (order, cash, return).
--
-- Order machine: transcribed from the V1 specification §5.5 "Order lifecycle (state machine)" table
-- (docs/reference/CRM_Algeria_V1_Specification.pdf) — 21 edges including 3 initial, matching the count already
-- cited in docs/02-data/orders.md §5. Status vocabulary adds `draft` and `processing` versus the earlier
-- [Guessing] reconstruction, which this replaces. The 3 initial edges (how an order enters `draft`,
-- `pending_confirmation` or `confirmed` directly) are not spelled out verbatim in §5.5's table — inferred from
-- its own prose ("Order saved with confirmation required", "policy allows auto-confirm for tier A") and
-- consistent with the doc's "3 initial" count, not itself a literal transcription.
--
-- Cash machine: the spec has no remittance/cash model (orders.md D1: "spec payments table was a mockup");
-- CLAUDE.md §7 / algeria-cod-crm wins here, per that deviation. Still [Guessing] on exact edges.
--
-- Return machine: status vocabulary (open/received/restocked/written_off/disputed) is verbatim from spec §4.7
-- return_cases; the specific edges between them are not spelled out as a table in §5.7, so they are
-- reconstructed from its prose ("Mark received" is explicit, followed by restocked|written_off) — [Guessing]
-- on the disputed branches specifically.

-- Order machine (V1 spec §5.5, verbatim table)
INSERT INTO order_status_transitions (machine, from_status, to_status, allowed_sources, requires_reason) VALUES
  ('order', NULL, 'draft', ARRAY['system', 'manual', 'webhook'], false),
  ('order', NULL, 'pending_confirmation', ARRAY['webhook', 'system'], false),
  ('order', NULL, 'confirmed', ARRAY['system'], false), -- tier A auto-confirm
  ('order', 'draft', 'pending_confirmation', ARRAY['manual', 'webhook'], false),
  ('order', 'draft', 'confirmed', ARRAY['manual'], false), -- customer present, or auto-confirm policy
  ('order', 'pending_confirmation', 'confirmed', ARRAY['manual', 'webhook'], false), -- call outcome, link, WhatsApp "yes"
  ('order', 'pending_confirmation', 'cancelled', ARRAY['manual', 'system'], true), -- reject / escalation accepted / expiry
  ('order', 'confirmed', 'processing', ARRAY['manual'], false), -- order packed
  ('order', 'confirmed', 'shipped', ARRAY['manual', 'carrier'], false),
  ('order', 'processing', 'shipped', ARRAY['manual', 'carrier'], false),
  ('order', 'shipped', 'out_for_delivery', ARRAY['carrier', 'webhook', 'manual'], false),
  ('order', 'out_for_delivery', 'delivered', ARRAY['carrier', 'manual'], false),
  ('order', 'shipped', 'delivery_failed', ARRAY['carrier', 'manual'], true), -- failure reason required (§5.5.2)
  ('order', 'out_for_delivery', 'delivery_failed', ARRAY['carrier', 'manual'], true),
  ('order', 'delivery_failed', 'out_for_delivery', ARRAY['carrier', 'manual'], false), -- retry
  ('order', 'delivery_failed', 'return_in_transit', ARRAY['carrier', 'manual'], false), -- no retry / business stops retries
  ('order', 'return_in_transit', 'returned', ARRAY['manual'], true), -- agent MUST confirm physical receipt; outcome from fault
  ('order', 'delivered', 'return_in_transit', ARRAY['manual'], true), -- post-delivery return window; reason code required
  ('order', 'draft', 'cancelled', ARRAY['manual'], true), -- "any pre-ship status -> cancelled"
  ('order', 'confirmed', 'cancelled', ARRAY['manual'], true),
  ('order', 'processing', 'cancelled', ARRAY['manual'], true);

-- Cash machine [Guessing — not in the V1 spec]
INSERT INTO order_status_transitions (machine, from_status, to_status, allowed_sources, requires_reason) VALUES
  ('cash', NULL, 'pending_collection', ARRAY['system'], false),
  ('cash', NULL, 'not_applicable', ARRAY['system'], false),
  ('cash', 'pending_collection', 'collected_by_carrier', ARRAY['webhook', 'carrier'], false),
  ('cash', 'pending_collection', 'collected_by_business', ARRAY['manual'], false),
  ('cash', 'pending_collection', 'not_collected', ARRAY['system', 'webhook', 'manual'], true),
  ('cash', 'collected_by_carrier', 'remitted', ARRAY['webhook', 'system'], false),
  ('cash', 'collected_by_business', 'remitted', ARRAY['manual'], false),
  ('cash', 'remitted', 'reconciled', ARRAY['system', 'manual'], false),
  ('cash', 'remitted', 'disputed', ARRAY['manual'], true),
  ('cash', 'disputed', 'reconciled', ARRAY['manual'], true),
  ('cash', 'disputed', 'written_off', ARRAY['manual'], true),
  ('cash', 'collected_by_carrier', 'refunded', ARRAY['manual'], true),
  ('cash', 'collected_by_business', 'refunded', ARRAY['manual'], true);

-- Return-case machine. Status vocabulary verbatim (spec §4.7); edges reconstructed from §5.7's prose [Guessing].
INSERT INTO order_status_transitions (machine, from_status, to_status, allowed_sources, requires_reason) VALUES
  ('return', NULL, 'open', ARRAY['system', 'manual'], false), -- opened on delivery_failed-no-retry or return_in_transit
  ('return', 'open', 'received', ARRAY['manual'], false), -- explicit "Mark received" action
  ('return', 'received', 'restocked', ARRAY['manual'], false),
  ('return', 'received', 'written_off', ARRAY['manual'], false),
  ('return', 'open', 'disputed', ARRAY['manual'], true),
  ('return', 'received', 'disputed', ARRAY['manual'], true),
  ('return', 'disputed', 'restocked', ARRAY['manual'], true),
  ('return', 'disputed', 'written_off', ARRAY['manual'], true);

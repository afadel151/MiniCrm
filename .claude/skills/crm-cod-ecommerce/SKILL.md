---
name: crm-cod-ecommerce
description: Build CRM and operations features for Cash-on-Delivery (COD) and D2C e-commerce, especially MENA-style markets: order capture from stores (Shopify, WooCommerce, YouCan, LightFunnels...), automated order confirmation (WhatsApp/SMS/IVR/agent), customer quality database and risk tiers, partial prepayment rules, carrier dispatch and tracking, delivery notifications, return/refusal analytics and return-rate reduction. Use when the user mentions COD, cash on delivery, confirmation agents, call center for e-commerce orders, return or refusal rate, couriers, D2C stores, or order-to-delivery workflows in a CRM.
---

# COD / D2C E-commerce CRM

In COD the customer has not committed financially, so unconfirmed, impulsive, mistaken or fraudulent orders become failed deliveries and returns. Source material in this pack states COD return rates of roughly 15-40% versus single digits for prepaid, and that a few points of reduction transform profitability. Treat those figures as claims from an industry vendor article to be checked against the user's own data, and make the CRM measure the user's real baseline first.

Principle: do not try to eliminate COD; make it safer with selective friction, speed and communication. Always balance fraud prevention with customer experience.

## Order lifecycle (state machine)

```
captured -> pending_confirmation -> confirmed -> ready_to_ship -> dispatched -> out_for_delivery
   |             |  (attempts exhausted)              |                              |
   |             +-> unconfirmed -> cancelled/held    +-> cancelled                  +-> delivered (cash collected) -> remitted
   |                                                                                 +-> failed_attempt -> rescheduled | returned_to_sender
   +-> rejected_by_rule (blacklist/policy) -> manual_review | prepayment_required
returned/refused -> return_received -> restocked | written_off
```
Each transition: guard conditions, actor, timestamp, reason code, event emitted. Keep `return_reason` and `cancel_reason` lookups (damaged, wrong size, not as described, changed mind, unavailable, wrong address, refused price, duplicate, fraud).

## Ten strategies mapped to CRM features

1. **Confirm every order before dispatch**: auto-start on `order.captured`. Sequence: instant acknowledgement -> WhatsApp/SMS with YES/NO reply -> (optional IVR "press 1") -> after 2-3 failed attempts route to agent queue -> status update -> dispatch or cancel/hold per business rule. Needs: reply parsing with idempotent webhook, attempt counters, per-attempt timers, business-hours handling, agent call UI with script and outcome codes (confirmed, wrong number, asks to modify, cancelled, no answer, call back at...). The source article claims 50-70% fewer unconfirmed orders; measure yours.
2. **Customer quality database**: the risk/quality score and tiers in `crm-customer-intelligence`. Track returns (count + reasons), failed deliveries, confirmation rate and latency, contact accuracy, AOV/LTV. Rules like "3+ returns in 6 months" trigger review, not permanent bans; apply time decay, reason-code nuance and an appeal path; keep blacklists inside the business and check legal limits.
3. **Honest product expectations**: link return reasons to product pages; for products with high "not as described"/"wrong size" rates create a task for the listing owner; capture size/material fields; show review stats. CRM role: analytics + task creation + data fields.
4. **Delivery speed and timing**: warehouse/stock allocation by region, carrier selection rules (cost, speed, success rate by city), same/next-day dispatch cut-offs, delivery slot capture. Target urban 1-3 days per the source; verify with own data.
5. **Packaging**: track damage-in-transit return reason by product and carrier; feed a packaging review.
6. **Delivery personnel**: scorecards per carrier/driver where data allows (first-attempt success, refusals, complaints); feedback loop with carriers; script and objection-handling guidance live outside the CRM but results are measured inside it; support digital payment at the door where the carrier offers it and reconcile.
7. **Partial prepayment**: policy table by order value / risk tier / product / city (e.g., 10-20% upfront for risk tier C above X). Selective, never universal. Payment links via gateway; reconciliation of paid + COD remainder; refund rules on cancel. Source example claims a segment's return rate falling from 25% to 5%; treat as illustrative and run an A/B with a holdout.
8. **Delivery journey communication**: five touchpoints, each an automation with templates, consent/purpose = transactional: (1) order confirmed + expected timeframe; (2) dispatched + tracking link and carrier; (3) out for delivery: "please be available"; (4) attempted/failed + reason + reschedule prompt; (5) post-delivery thanks + feedback request. Channels: WhatsApp Business API, SMS, email. Confirm template approval rules with the provider.
9. **Analyse returns relentlessly**: dimensions: product, reason, customer segment (new vs repeat, AOV band), geography, carrier, confirmation agent, time/promotion period. Build a "returns cockpit" (see below).
10. **Iterate**: monthly review: pick the largest driver, run one intervention with a holdout, measure, keep or revert.

## Data additions to the core model

`orders`: `payment_method` (cod/prepaid/partial), `prepaid_minor`, `cod_amount_minor`, `confirmation_status`, `confirmation_attempts`, `confirmed_at`, `confirmed_by`, `risk_tier_at_order`, `carrier_id`, `tracking_no`, `dispatched_at`, `delivered_at`, `delivery_attempts`, `failure_reason`, `return_reason`, `cod_collected_minor`, `remitted_at`.
`confirmation_attempts(order_id, channel, sent_at, response, responded_at, agent_id, outcome)`.
`carriers(id, name, api_config, service_levels)`, `carrier_events(order_id, status_raw, status_norm, at)`, `cod_remittances` (carrier payouts vs expected; discrepancies list).
`customer_risk(customer_id, score, tier, reasons jsonb, computed_at, model_version)`.
`return_reasons` lookup with `fault` attribute (customer / us / carrier / product) so risk logic does not penalise customers for our mistakes.

## Agent confirmation workspace

Queue of orders awaiting human confirmation sorted by value, risk tier and age; one-click call/WhatsApp; call script panel; edit address/phone/quantity with audit; outcome buttons mapped to codes; callback scheduling; duplicate order detection (same phone/address within N hours); live productivity (confirmations/hour, confirmation rate, downstream return rate by agent).

## Returns cockpit (dashboard)

Return rate trend (overall, by product, city, carrier, agent, tier, payment method); reason mix with fault attribution; unconfirmed rate; confirmation funnel (captured -> attempted -> confirmed -> dispatched -> delivered); net margin per order after returns; carrier league table; cohort of new vs repeat customers; what-if: effect of prepayment threshold on volume and returns.

## Benchmarks from the source (use as hypotheses, not facts)

| Metric | Good | Needs improvement |
|---|---|---|
| COD return rate | < 15% | > 25% |
| Unconfirmed order rate | < 10% | > 30% |
| Urban delivery window | 1-3 days | > 5 days |

## Prioritised plan when the user gives a bad baseline

1. Instrument: capture reasons, attempts, carrier events; compute the real baseline (week 1-2).
2. Automate confirmation (WhatsApp first, agent fallback) (weeks 2-4).
3. Customer quality tiers + duplicate detection; selective manual review (weeks 4-6).
4. Prepayment rules for risk tier C/D and high-value orders, with A/B (weeks 6-8).
5. Delivery journey notifications + carrier scorecards (weeks 6-10).
6. Returns cockpit and monthly iteration loop (ongoing).
Adapt to the platform (Shopify, WooCommerce, YouCan, etc.), region, product category, AOV and current confirmation process; ask for these if missing.

## Guardrails
- Do not store card data; use gateways for prepayment.
- Message only with a valid transactional basis; respect opt-outs and channel rules.
- Do not discriminate on protected attributes; explain tier decisions; allow review.
- Locale: RTL/Arabic and French templates, local phone formats, local address quirks (landmarks, neighbourhood names), local payment methods and carriers; validate against the provider's current docs.

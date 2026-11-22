# Phase 2 review record — 2026-11-20

Two independent reviews of the first schema drafts, run in fresh contexts:
- **A** = adversarial architecture + Contact Score review (`architecture-reviewer`, Fable 5.2, read-only).
- **S** = SQL security/correctness review (`code-reviewer`, Opus 5.5) — findings marked **V** were reproduced on
  PostgreSQL 18.7 as the runtime roles inside rolled-back transactions.

Disposition: **FIX** = fixed in this round (technical, no product choice) · **DEFAULT** = fixed with the most
conservative configurable default, product lead to confirm at the gate · **DECIDE** = needs the product lead/legal ·
**P3** = belongs to Phase 3 (contracts) · **LATER** = tracked, not blocking.

## Cross-cutting (root causes)

| # | Finding | Src | Disposition |
|---|---|---|---|
| X1 | Powers granted by self-settable settings (`app.platform_role`, client paths via `app.user_id`) and one runtime role for every caller | S5,S6,S3,A-H3 | **FIX** — ADR-0006 role model (`_app/_worker/_admin` + per-service extras) |
| X2 | `app.outbox/inbox/tenants` have no RLS and full DML for the API role: cross-tenant event forgery, version-guard bypass, inbox replay (**V**) | S1, A-H3 | **FIX** — building blocks: outbox INSERT tenant-checked for `_app`, relay = `_worker`; inbox worker-only, no DELETE; tenants worker-only + DB version guard |
| X3 | Single-column FKs between tenant tables (13: 11→`app.files`, identity invitation, scoring known_phone) — cross-tenant reference, erasure blocking, existence oracle (**V**) | S7 | **FIX** — composite `(business_id, x_id)` FKs; `audit-fks.sql` must return 0 rows |
| X4 | `app.files.scan_status` updatable by every runtime role; client could insert `clean` files (**V**) | S4 | **FIX** — app inserts only `pending`; scanner (`_worker`) updates |
| X5 | Append-only tables can be TRUNCATEd by owner; whitelisted columns can rewrite meaning (crm `call_logs.phone_hash`, reversible `redacted_at`, `contact_merges.loser_snapshot`) (**V**) | S12 | **FIX** — TRUNCATE trigger in building block; per-table guard triggers |
| X6 | Count-then-insert limits race; `setting_int` NULL fails open | S11, A-M4 | **FIX** — advisory locks + fail-closed defaults |
| X7 | Bootstrap: roles never re-asserted; `svc` unvalidated | S-low | **FIX** |

## Service findings

| # | Finding | Src | Disposition |
|---|---|---|---|
| I1 | `set_feature_flag` trusts caller-supplied actor id → any API session enables `global_score_visible` (**V**) | S2 | **FIX** — EXECUTE only for `identity_access_admin` |
| I2 | Suspended tenant can unsuspend itself (status columns in runtime grant) (**V**) | S2 | **FIX** — status/suspension via admin role |
| I3 | `auth_list_user_memberships` accepts any user id | S-low | **FIX** — restrict to worker/BFF path, document |
| M1 | Client path can redact/fail merchant messages, forge counters, back-date messages (**V**) | S3 | **FIX** — `messaging_client` role + guard triggers; counters by trigger |
| M2 | Client attaches another tenant's file and reads its storage key (**V**) | S4 | **FIX** — composite FK + policy compares business_id |
| M3 | `claim_email_notifications` callable by API role (all users' payloads) | S-low | **FIX** — worker only |
| P1 | Staff self-review on their own customers' orders (**V**) | S5 | **FIX** — `presence_client` role; author policy checks eligibility owner |
| P2 | Staff forge `rating_*`, `verified_at` (**V**); `refresh_rating_parameters` callable by API | S5 | **FIX** — column grants; consumer/scheduler = worker |
| P3x | `app.platform_role` grants web_master (**V**) | S5 | **FIX** — `presence_admin` role |
| P4 | Public views leak hidden rows through error messages (**V**) | S8 | **FIX** — `security_barrier` views |
| P5 | Review eligibility of a recycled number shows the previous owner's orders | A-M3 | **DEFAULT** — eligibility window from `eligible_at` |
| C1 | `call_logs`/`interactions`/`contact_merges` whitelist rewrites | S12 | **FIX** (see X5) |
| C2 | `contact_score_cache` accepts `layer='global'` | A-H7 | **FIX** — tenant layer only in crm |
| S1 | Oracle bypass with throwaway orders (`has_order` from any placed order, `min_order_age_hours` unused, batch lookups) | A-C1 | **DEFAULT** — global band only for orders ≥ min age, not cancelled-before-confirmation, never on batch/import channels, probation tenants excluded; quota vs shipped volume; origins list = DECIDE |
| S2 | Owner self-view by shareable OTP leaks behaviour to merchants | A-C2 | **DEFAULT** — coarse self-view (month, no provenance), per-number view cap, confirmation-link completion never proves ownership; magic-link flow = DECIDE |
| S3 | Forgeable "carrier-verified" outcomes; merchant-chosen fault class | A-C3 | **DEFAULT** — webhook-only outcomes = `webhook_verified` until a poll confirms; customer-fault refusal counts globally only with customer-side evidence; velocity table added |
| S4 | Disputes chain into a permanent freeze; freeze trigger RAISEs into the engine txn; no unfreeze job | A-H1, S11 | **DEFAULT** — general disputes don't freeze; yearly freeze cap; engine skips global upsert instead of raising; unfreeze recompute |
| S5 | Sybil k-gate, differential/timing inference, `global_band` in tenant-visible `score_lookups`, inflation by fake deliveries | A-H2 | **DEFAULT** — move global band out of tenant-visible table, positive global signals need carrier/remittance proof, probation signals excluded; independence evidence + hysteresis = LATER (engine) |
| S6 | Consent: merchant-declared grant overrides owner withdrawal; per-scope seq collisions; messaging STOP resets guard | A-H4, S10 | **FIX** — withdrawal wins, per-phone monotonic consent version, sticky local opt-out |
| S7 | Lost updates on concurrent global recomputes | A-H5 | **FIX** — row lock on phone identity + version guard on `global_scores` |
| S8 | First order of a phone never scored (GetScore before `order.placed`) | A-H6 | **DEFAULT** — async `scoring.order_risk.assessed` after `order.placed` (P3 contract) |
| S9 | `scoring_app` has app.* DML; owner portal shares API role | A-H3 | **FIX** — `scoring_portal` role; app.* per ADR-0006 |
| S10 | `scoring_engine` can create DSR + release hold + erase | A-M6 | **FIX** — DSR progress/hold release = admin only |
| S11 | Erasure re-created by next event; deletes all tenant layers; reveals DSR; version restarts | A-M1 | **FIX** (suppression list + monotonic event version) / **DECIDE** (tenant layers survive? legal) |
| S12 | N=0 can be "low" confidence; behaviour points on never-delivered numbers | A-M2 | **FIX** — CHECK effective_n > 0 or UNSCORED; no behaviour points before N ≥ 1 |
| S13 | NULL-unsafe score-model CHECKs: carrier ≥ manual not enforced (**V**) | S9 | **FIX** |
| S14 | Nightly decay floods history + events | A-M5 | **FIX** — write/emit only on tier/confidence change |
| S15 | Recycled-number triggers undefined | A-M3 | **DECIDE** (inactivity window, owner-claim evidence) |
| S16 | Pepper shared by ~6 DBs; rotation breaks hash-keyed read models | A-M7 | **FIX** (key-version column on every hash) + runbook = LATER |
| E1 | Event name/payload mismatches between services (11 listed) | A-H7 | **P3** — event catalogue; schema-affecting ones fixed now (confidence vocabulary, tenant-only score events) |
| E2 | Confidence vocabulary differs (crm/orders/scoring) | A-H7 | **FIX** — tenant layer `none/low/medium/high`; global label `not_enough_data/low/high` |
| E3 | `global_score_visible` semantics: identity override vs scoring AND | A-H7 | **DEFAULT** AND (a business can only opt out) — confirm |
| G11 | Phase 1 / 1b skipped (schema-first) — no sequence diagrams to check contracts against | A-low | **Noted** — Phase 1 artefacts owed before Phase 3 |

## Questions for the product lead (gate)
1. Which order origins make a phone eligible for the global band (customer-initiated only?) — S1
2. Owner self-view: magic link on the phone itself, coarse granularity? May a confirmation link ever prove ownership? — S2
3. Which carriers' webhooks (if any) count as carrier-verified without a confirming poll? — S3
4. Should disputes freeze the score at all; general disputes; maximum freeze per year? — S4
5. Consent scope: may merchants collect score consent; does any withdrawal win? — S6
6. Does a global-layer erasure remove merchants' tenant layer? Is a suppression list acceptable (legal R1)? — S11
7. Recycled numbers: inactivity window, evidence for owner-claimed reset? — S15
8. `global_score_visible`: AND (proposed) or business override? — E3
9. Do new businesses start `pending` (cheapest Sybil brake)? — S5

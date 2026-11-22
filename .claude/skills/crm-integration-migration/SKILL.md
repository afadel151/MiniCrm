---
name: crm-integration-migration
description: Plan and build CRM integrations and data migration: connecting to accounting/ERP, e-commerce platforms (Shopify, WooCommerce, YouCan, etc.), carriers/couriers, payment gateways, WhatsApp/SMS/email providers, telephony, and importing legacy data from spreadsheets or old CRMs. Covers sync direction, ID crosswalks, webhooks, idempotency, field/value mapping, deduplication on import, mock migrations and validation. Use when the user says integrate, sync, webhook, import, migrate, connector, API, CSV upload, or "move data from X to the CRM".
---

# CRM Integration and Data Migration

Integration and migration are both "moving and translating data between systems"; the book calls integration "a kind of ongoing data migration". Treat them with the same discipline: scenario table -> mapping -> build -> test with experts -> monitor.

## Part A: Integration

### Why integrate
(1) A more complete customer picture (360 view); (2) automate processes that cross application boundaries (won deal -> accounting customer + order; order confirmed -> carrier booking), removing re-keying, delays and errors.

### Two types
- **Data-level**: copy data between systems. More work, but the data is fully usable by the receiving system (search, reports, automation). Define the *direction of flow* and the **system of record per field**, and what happens when both sides edit (last-write-wins with timestamps, field-level ownership, or conflict queue).
- **UI-level**: embed a view of another system (e.g., invoices from accounting in a tab on the account). Quick, but the data cannot be searched/reported/automated in the CRM. Pick this when users only need to *look*.

### Start with the integration scenario table
| Source app | Entity | Direction | Target app | Entity | Trigger | Notes (read-only? who owns?) |
|---|---|---|---|---|---|---|
| CRM | Account | -> | Accounting | Customer | status becomes "customer" | no manual customer creation in accounting |
| CRM | Order | <-> | Accounting | Sales order | status "Submit to Accounting" | becomes read-only in CRM after flowing |
| Accounting | Invoice | -> | CRM | Invoice | invoice created | read-only |

### Linking records
Store each system's unique ID on the other's record, or (better with 3+ systems) in an `external_ids` crosswalk table (see `crm-data-model`). Plan how *existing* records get matched initially (exact keys first, then fuzzy matching with a manual-review queue); this is often the painful part.

### Engineering patterns
- **Inbound webhooks**: verify signatures; respond fast (ack then process async); idempotent by event id; store raw payload; handle out-of-order and duplicate deliveries; replay tooling.
- **Outbound**: from the transactional outbox (see `crm-workflow-automation`); retry with backoff; circuit breaker; per-provider rate limits; dead-letter queue + admin UI.
- **Polling/reconciliation**: webhooks drop events; run periodic reconciliation (by updated_since cursor or checksum) and report drift.
- **Anti-corruption layer**: translate external models to the CRM's canonical model in one adapter per system; never leak provider-specific fields into core tables (keep raw in `metadata`).
- **Connector interface**: `fetch_changes(since)`, `push(entity)`, `map_in`, `map_out`, `verify_webhook`, `health()`. One folder per connector; contract tests with recorded fixtures; sandbox credentials in CI.
- **Secrets and scopes**: per-tenant credentials in a vault; least-privilege API scopes.
- **Observability**: sync dashboard (last success, lag, error counts per connector and entity), alerts on lag/error thresholds, per-record sync status visible on the record.
- **Testing**: need a test instance of every application involved; business SMEs of each system review results because they spot translation errors engineers miss.

### Typical connectors for COD/D2C and general CRMs
E-commerce stores (orders, customers, products, inventory), carriers/couriers (rate, booking, tracking webhooks, COD collection and remittance statuses), payment gateways (partial prepayments, refunds), messaging (WhatsApp Business API providers, SMS, email), telephony/IVR, accounting/ERP, ads platforms (lead forms, conversion events), spreadsheets (CSV/Google Sheets). Check each provider's current API docs, quotas and policy; do not assume endpoints from memory.

## Part B: Data migration

### First decide whether to migrate
Default: **do not migrate** until the value is proven. Weigh: is the data structured? how complex (relationships, notes, attachments)? size (small simple sets can be re-keyed or imported by CSV)? will the old system stay available read-only? data quality (if poor, start clean)? business value? Migration does not fix quality; clean and deduplicate first (see `crm-data-model/references/identity-resolution.md`).

### Assess sources
Access (connectors, DB, exports), schema understanding (docs/SDK, reverse engineering), quality (inconsistent field usage, different interpretations of values, varying quality between entities, e.g., tidy customers but sloppy leads).

### Design (functional then technical)
1. Which entities, and which records of each (all, active only, last N months)?
2. **Entity mapping**: source entity -> CRM entity.
3. **Field mapping**: source field -> CRM field.
4. **Value mapping**: pick-list translation (codes differ even when labels match), lookups (sales rep -> user via crosswalk), parsing (single "name" field -> first/last, with known imperfections), format normalisation (phones to E.164, dates, currencies), defaults and rejects.
5. Sign-off by business owners (accountability point).
Templates: `references/mapping-templates.md`.

### Execute
- Build migration as **idempotent, re-runnable scripts** with a run id, writing to staging tables first; load via bulk APIs; keep source IDs in `external_ids` so reruns update rather than duplicate.
- **Mock migration** at least once with the **full data set** on production-like infrastructure; fully scripted; time-stamped log; measures duration; the team validates. Re-run until clean.
- **Validation**: error logs; query/count reconciliation (50,000 source accounts -> how many created, which missing and why?); spot testing records field by field including relationships; business-rule checks (no orphan contacts, no opportunities without stage); users close to the source data review samples. Report issues with record id + field + expected vs actual.
- **Cutover**: freeze source (read-only) at a set time, take final extract, run the same script as the mock, validate, go/no-go, then open the CRM. Keep rollback plan and the old system read-only for a defined period.
- Plan the schedule around business cycles (e.g., weekend/evening) and communicate to users.

### CSV import tool (build this early, it replaces most small migrations)
Upload -> detect columns -> map to fields -> preview with validation errors -> dedupe strategy (skip/update/create) -> dry run summary -> commit with run id -> downloadable error file -> undo by run id (within a window). Record `source='import:<name>'` and consent status/evidence per row; refuse marketing-consent import without evidence.

## Anti-patterns
- Point-to-point spaghetti between five systems; use the CRM's events/outbox and adapters.
- Syncing everything both ways with no system-of-record rules.
- Migrating free-text notes as unstructured blobs into structured fields.
- Cutover without a mock migration, or with the first full-volume run being production.

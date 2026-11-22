# Data design conventions (all services)

Status: **Proposed** (Phase 2, gate pending). Owner: architecture. Applies to every service database.
Sources: CLAUDE.md §3–5, §7, §10, §14 · Tech Decisions v0.2 §2.4–2.5, §3.3, §5 · V1 Spec §4 · ADRs 0001–0005.

## 1. Physical layout

| Item | Rule |
|---|---|
| Engine | PostgreSQL **18** (needed for built-in `uuidv7()`; vanilla features + `pg_trgm`, `unaccent` only) |
| Database | One per service: `identity_access`, `crm`, `orders`, `scoring`, `integrations`, `messaging`, `presence`. One cluster in dev/early prod, separate credentials |
| Roles | `<db>_migrator` owns everything, `BYPASSRLS`, used only by the migration job · `<db>_app` runtime, **not owner**, `NOBYPASSRLS` · platform-admin role (`<db>_admin`) arrives with the web-master console (M5) |
| Schemas | `public` = service domain tables · `app` = building blocks (outbox, inbox, audit_log, files, tenants, helpers) · `ref` = reference data (geo) |
| Migrations | SQL-first, files `V0001__name.sql`, applied by a separate deploy step after the shared `C000x` building blocks (ADR-0004). Never on startup |
| Location | `src/Services/<Svc>/<Svc>.Infrastructure/Database/{migrations,seed,tests}/` · shared blocks in `src/BuildingBlocks/Database/sql/` |
| Local run | `tools/db/bootstrap-service-db.sh <db> <Svc> [--geo] [--reset]` (Docker container `minicrm-pg`, host 127.0.0.1:55433; `CONTAINER_ENGINE=podman` also works) |

## 2. Columns and types

| Concern | Rule |
|---|---|
| Primary key | `id uuid PRIMARY KEY DEFAULT uuidv7()` — the app normally supplies `Guid.CreateVersion7()`; the default is a safety net |
| Timestamps | `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()` + `app.add_updated_at_trigger()`. UTC; UI converts to `Africa/Algiers` |
| Tenant | `business_id uuid NOT NULL` on every tenant row + `app.enable_tenant_rls()`; **first column of every tenant index and unique constraint** (keeps tenant sharding possible) |
| Enumerations | `text` + `CHECK (col IN (...))` — easier to migrate than native enums (spec §4.1) |
| Money | **`numeric(12,2)` DZD**, `CHECK (>= 0)` unless a signed amount is meaningful (ADR-0001). C# `decimal`. Never floats |
| Currency | `currency char(3) NOT NULL DEFAULT 'DZD'` on money-bearing aggregates (international later; CLAUDE.md §7) |
| Phones | Private tables: `phone_raw` (as typed) + `phone_e164` (normalised, `CHECK (phone_e164 ~ '^\+[1-9][0-9]{6,14}$')`) + `phone_hash bytea` (HMAC-SHA256, 32 bytes, computed in app). Scoring stores **only** `phone_hash` |
| Concurrency | Aggregates carry `version bigint NOT NULL DEFAULT 1`, incremented by the app on every write; it is the `aggregate_version` in events and the optimistic-concurrency token |
| Read models | Rows fed by events carry `source_version bigint NOT NULL`; upserts use `WHERE target.source_version < EXCLUDED.source_version` |
| JSON | `jsonb` only for genuinely schemaless data (custom-field values, raw payloads, diffs) — never for data we query relationally |
| Soft delete | `deleted_at timestamptz` for user-editable master data (contacts, products). Orders and history are never deleted |
| Text search | `pg_trgm` GIN indexes on names inside the owning service; no external search engine in V1 |

## 3. Cross-service references (ADR-0002)

- **No foreign key to another service's table, ever.** A foreign id is an opaque `uuid` column named after the
  entity (`contact_id`, `user_id`) with a `COMMENT ON COLUMN ... IS 'opaque ref: crm.contacts'`.
- Data needed on hot paths is copied as a **local read model** fed by events (e.g. orders keeps a contact snapshot).
- Spec tables that FK to `businesses`/`users` become plain `business_id`/`user_id` uuids outside identity-access.
- `app.tenants` (read model of `identity.business.*`) lets a service refuse writes for suspended tenants; no FK to it.

## 4. Tenancy and RLS

- Policy `business_id = app.current_business_id()` for USING and WITH CHECK; the setting is applied with
  `set_config('app.business_id', $1, true)` **inside the transaction** (PgBouncer transaction pooling safe).
- Unset tenant ⇒ `NULL` ⇒ no rows (fail closed). Platform-level tables (scoring global layer, reference data,
  outbox/inbox) have no `business_id` and no tenant policy; access is restricted by grants instead.
- EF Core global query filter on `business_id` is the second layer; never the only one.
- **FK checks bypass RLS.** A single-column FK `child.parent_id → parent.id` lets tenant B attach its row to tenant A's
  parent if it learns the id. Inside a service, every FK between tenant tables is **composite**
  `(business_id, parent_id) → parent(business_id, id)` (parent declares `UNIQUE (business_id, id)`). Verified by
  orders T0001; enforced by the cross-service FK audit query in `tools/db/audit-fks.sql`.
- **NULL-safe CHECKs.** `CHECK (x <> 'a' OR y = 'b')` passes when `y` is NULL. Write implications as
  `CHECK (x IS DISTINCT FROM 'a' OR y IS NOT DISTINCT FROM 'b')` or add an explicit `y IS NOT NULL` (two real bugs in orders).
- **Every tenant table gets a cross-tenant SQL test** in `tests/` (run as `<db>_app`, never as superuser —
  superusers bypass RLS).

## 5. Append-only and history

`app.make_append_only(tbl, allowed_update_columns)` revokes UPDATE/DELETE from the runtime role and installs a
trigger. Applies to: status histories (`order_status_history`, `shipment_events`), `phone_signals` (only
`is_valid` may flip), `audit_log`, consent records, webhook payloads once processed (payload column).

## 6. Partitioning (from day one)

Monthly `RANGE` partitions via `app.ensure_monthly_partitions(parent)` (daily job, 3 months ahead, DEFAULT
partition as a safety net with an alert when non-empty). PK must contain the partition key. Partitioned:
`app.outbox`, `app.inbox`, `app.audit_log`, `order_status_history`, `shipment_events`, `phone_signals`,
`webhook_events`, `messages`. Retention = detach + archive old partitions (per-table retention in each service doc).
**Partitions are locked** (`app.lock_partitions`, called by `ensure_monthly_partitions`): the runtime role has no
privilege on any partition, because partitions do not inherit the parent's RLS policies. Always query the parent.
If a service partitions a table itself, it must call `app.ensure_monthly_partitions` AFTER `app.enable_tenant_rls`
and any grants, and its tests must assert direct partition access is denied.

## 7. Messaging tables

`app.outbox` and `app.inbox` (C0002) implement the CloudEvents-style envelope of CLAUDE.md §3. The inbox is
partitioned by the event's `occurred_at`, so redeliveries hit the same partition and the PK rejects duplicates.
If spike S2 selects Wolverine, its envelope tables replace these; the envelope columns are the contract.

## 8. Required per-service deliverables

1. `migrations/V0001__initial.sql` (idempotent where practical, commented, grouped by aggregate)
2. `seed/` (only non-PII reference/config data, e.g. permission catalogue, score model v1 parameters)
3. `tests/*.sql` — cross-tenant isolation for every tenant table, append-only, key constraints, state CHECKs
4. `docs/02-data/<service>.md` — tables, spec mapping, deviations with justification, indexes ↔ queries,
   partitioning/retention, events produced/consumed that touch the schema, open questions
5. `docs/02-data/erd/<service>.drawio` (+ `.png`) generated from the DDL

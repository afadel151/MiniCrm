# Phase 2 task brief: one service's database schema

You design and VALIDATE the PostgreSQL schema of ONE service of the Algerian COD CRM. Repo root:
`/home/fadel/gitHub/MiniCrm`. Work only inside the paths listed under "Write scope".

## Read first (in this order, do not skip)
1. `CLAUDE.md` (sections 3, 4, 5, 7, 13, 14 matter most).
2. `docs/02-data/00-conventions.md` — binding conventions. Then `docs/adr/0001…0005` and `docs/00-context/gap-analysis.md`.
3. The building blocks you build on (already applied before your migration): `src/BuildingBlocks/Database/sql/C0001__app_base.sql`,
   `C0002__outbox_inbox_audit_files.sql`, `C0003__reference_geo.sql` (only if your service stores addresses), and
   `tools/db/bootstrap-service-db.sh` (how your files are applied and tested).
4. The spec / tech-decision sections named in your task. Read ONLY those line ranges (`Read` with offset/limit). The books in
   `docs/reference/` are large: grep them, never load them whole. `graphify-out/GRAPH_REPORT.md` is a map of the references.
5. Skills (invoke with the Skill tool): `database-design:postgresql-table-design` and `crm-data-model` always; others as named in your task.

## Precedence
ADRs > Tech Decisions v0.2 > V1 spec > CLAUDE.md > books. The spec was written for ONE database; v0.2 splits it into services.
So: no FK to another service's table (ADR-0002), opaque uuid + `COMMENT ON COLUMN ... IS 'opaque ref: <svc>.<table>'`.
If two sources conflict and precedence does not settle it, do NOT pick silently: record it under "Open questions".

## Write scope
- `src/Services/<Svc>/<Svc>.Infrastructure/Database/migrations/V0001__initial.sql`
- `src/Services/<Svc>/<Svc>.Infrastructure/Database/seed/S0001__*.sql` (only non-PII config/reference rows; NEVER invent geo data or real people)
- `src/Services/<Svc>/<Svc>.Infrastructure/Database/tests/T0001__*.sql` (one or more files)
- `docs/02-data/<service>.md`
Do NOT edit building blocks, conventions, ADRs, CLAUDE.md or other services. If you need a building-block change, describe it in your doc under
"Requests to building blocks" and work around it locally.

## Schema rules (summary — conventions file is authoritative)
- `id uuid PRIMARY KEY DEFAULT uuidv7()`, `created_at`/`updated_at` + `SELECT app.add_updated_at_trigger('<tbl>')`.
- Tenant tables: `business_id uuid NOT NULL`, `SELECT app.enable_tenant_rls('<tbl>')`, business_id FIRST in every index/unique.
- Enums = text + CHECK. Money = `numeric(12,2)` + CHECK, `currency char(3) DEFAULT 'DZD'` on aggregates. Phones = raw + E.164 + `phone_hash bytea` (32 bytes).
- Aggregates: `version bigint NOT NULL DEFAULT 1`. Event-fed read models: `source_version bigint NOT NULL`.
- Append-only: `SELECT app.make_append_only('<tbl>'[, ARRAY['allowed_col']])`. Partition big append-only tables monthly with
  `PARTITION BY RANGE (<time col>)` + `SELECT app.ensure_monthly_partitions('<tbl>')`; PK must include the partition column.
  Note: a FK pointing TO a partitioned table must include its partition key — prefer no FK into partitioned history tables.
- Every index must be justified by a named query in your doc. Every CHECK that encodes a state machine must match the spec.
- Comment tables and non-obvious columns (`COMMENT ON`). No secrets/peppers/tokens in clear: store hashes (and say which algorithm).
- Do not add tables for features outside V1 scope (spec §1.2) unless the spec says "schema-ready".

## Validation (mandatory — you are not done until this passes)
Run: `tools/db/bootstrap-service-db.sh <db> <Svc> [--geo] --reset`  (PostgreSQL 18.7 in Docker container `minicrm-pg`, host port 55433).
Ad-hoc SQL: `docker exec -i minicrm-pg psql -U postgres -d <db> -X -v ON_ERROR_STOP=1`.
Tests run as superuser by default — superusers BYPASS RLS, so every test file must `SET ROLE <db>_app;` before tenant checks. Cover:
1. For EVERY tenant table: tenant B cannot SELECT, UPDATE or DELETE tenant A's rows, and cannot INSERT a row with A's business_id
   (expect `insufficient_privilege` / 0 rows); with no tenant set, 0 rows are visible.
2. Every append-only table refuses UPDATE/DELETE (except whitelisted columns).
3. Key uniques and CHECKs (state values, money >= 0, E.164 format, one-of constraints), and the main FK cascades/RESTRICTs.
4. End each test file with `SELECT 'PASS <file name>';`. Use `DO $$ ... ASSERT ... $$` or exception-expecting DO blocks.
Iterate until the script prints `OK <db>`. Paste the last 15 lines of the successful run in your final reply.

## Service doc (`docs/02-data/<service>.md`, aim ≤ 250 lines)
1. Purpose and ownership (what this DB owns, what it does NOT).
2. Table catalogue: table → spec table(s) it implements → tenant/platform → append-only? → partitioned?
3. Mermaid `erDiagram` (relations inside this service only; external refs shown as notes).
4. Deviations from the spec, each with justification and the source that wins.
5. Indexes ↔ queries (which screen/handler/consumer needs each index).
6. Events: produced (written to app.outbox) and consumed (read models / inbox), with the tables they touch.
7. Partitioning and retention per table. 8. Security notes (RLS, PII columns, hashed secrets).
9. Open questions (numbered, tagged [Likely]/[Guessing] where relevant). 10. Requests to building blocks.

## Final reply (to the orchestrator, ≤ 40 lines)
Tables created (count + names), deviations, open questions, test result tail, and a scaffold-honesty line:
what was not done and whether everything was actually executed against PostgreSQL.

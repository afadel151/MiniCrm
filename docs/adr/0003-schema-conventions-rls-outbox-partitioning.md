# ADR-0003: Shared schema building blocks (RLS, outbox/inbox, append-only, partitioning)

- Status: **Proposed** (Phase 2 gate)
- Context: CLAUDE.md §3–4 mandate RLS with transaction-local tenant, outbox, idempotent inbox, append-only
  history and time partitioning from day one, in seven databases. Hand-writing these seven times guarantees drift.
- Decision: one set of versioned SQL building blocks (`src/BuildingBlocks/Database/sql/C000x`) applied to every
  service database before its own migrations:
  - `app.current_business_id()` reads `app.business_id` (missing ⇒ NULL ⇒ fail closed);
    `app.enable_tenant_rls(tbl)` = ENABLE + FORCE RLS + one `tenant_isolation` policy (USING + WITH CHECK).
  - Runtime role `<db>_app` is non-owner/NOBYPASSRLS; derived from `current_database()` so files are identical.
  - `app.make_append_only(tbl, allowed_cols)` = privilege revoke + trigger (two layers; column whitelist for
    `phone_signals.is_valid`).
  - `app.outbox` / `app.inbox` partitioned by event `occurred_at`; the inbox PK `(event_id, consumer,
    occurred_at)` makes redeliveries collide in the same partition (a `received_at` key would let a redelivery
    across a month boundary slip through).
  - `app.ensure_monthly_partitions(parent)` (no pg_partman: not available on every managed provider, D2).
  - `app.audit_log`, `app.files` (metadata only), `app.tenants` read model.
- Alternatives rejected: pg_partman (portability), native enums (migration pain, spec §4.1), session-level
  `SET app.business_id` (leaks through pooled connections — the classic failure), RLS-only without EF filter.
- **Partition lock (security fix, 2026-11-20):** RLS policies and grants on a partitioned parent are not inherited
  by partitions, and default privileges made every partition directly readable by `<db>_app` — a cross-tenant
  read bypassing RLS. `app.ensure_monthly_partitions` now calls `app.lock_partitions(parent)`, which revokes every
  privilege on every partition from the runtime role and PUBLIC; data is reachable only through the parent.
  Verified on Docker PostgreSQL 18.7. Every service test suite must assert that partitions are not directly readable.
- Verification: smoke test on PostgreSQL 18.7 (2026-11-20) proved fail-closed reads, cross-tenant insert refusal,
  append-only refusal with column whitelist, inbox duplicate rejection. Each service adds its own tests.
- Consequences: PostgreSQL 18 is the minimum (built-in `uuidv7()`); partition maintenance is a scheduled job to
  monitor; outbox is readable by the runtime role (relay runs in-process), so it must never be exposed by an API.
- Revisit when: spike S2 picks Wolverine (its envelope tables replace outbox/inbox), or PgBouncer/Citus tests
  (S4-adjacent) show an issue.

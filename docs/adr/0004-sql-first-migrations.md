# ADR-0004: SQL-first migrations, applied as a separate deploy step

- Status: **Proposed** (Phase 2 gate); runner tool chosen in Phase 5
- Context: v0.2 §5.3 uses EF Core for commands and requires reviewed, idempotent SQL migrations run as a K8s Job.
  The schema relies heavily on features EF migrations model poorly: RLS policies, partitioned tables, triggers,
  partial and expression indexes, column-level grants. CLAUDE.md §13 wants "migrations reviewed as SQL".
- Options: (a) EF Core migrations + raw SQL blocks; (b) SQL-first files, EF model maps the existing schema
  (no EF migrations); (c) a declarative diff tool.
- Decision: **(b)**. The source of truth is `V####__*.sql` per service (after shared `C####__*.sql`). EF Core
  entity configuration maps onto it; an integration test (Testcontainers) applies all migrations and checks the
  EF model against the database. Runner candidates for Phase 5: DbUp (MIT) or a 100-line in-repo runner with a
  `schema_migrations` table and checksum; both are licence-safe.
- Consequences: reviewers read the real DDL; expand-and-contract is written by hand; drift between EF mapping
  and schema is caught by tests, not by tooling.
- Revisit when: the hand-written migration burden shows up in the >30 % plumbing tripwire.

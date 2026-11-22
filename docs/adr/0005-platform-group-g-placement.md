# ADR-0005: Where the spec's "Group G: Platform" tables live

- Status: **Proposed** (Phase 2 gate)
- Context: Spec §4.9 has `files`, `notifications`, `audit_logs`, `feature_flags`, `wilayas`. v0.2 §2.2 says
  `platform` is a shared library until two services need a capability at runtime — so it owns no database.
- Decision:
  | Spec table | Home | Why |
  |---|---|---|
  | `audit_logs` | `app.audit_log` in **every** service (building block) | Audit is written in the same transaction as the action; a central audit service would need distributed writes |
  | `files` | `app.files` in each service that owns files | Metadata belongs to the owner of the file's purpose; bytes behind `IFileStorage` |
  | `feature_flags` | **identity-access** (`feature_flags`), changes published as `identity.feature_flag.changed`; consumers cache | identity-access is already the tenant authority; scoring enforces `global_score_visible` from its cached copy (default OFF if unknown) |
  | `notifications` (+ preferences) | **messaging** (M5) | Outbound communication and the real-time hub already live there. Before M5, identity-access sends its own transactional e-mails (verification, reset) through a library `IEmailSender` with no table |
  | `wilayas` (+ communes) | Versioned reference data (`ref` schema, C0003) seeded into each service that stores addresses | Read-only, same dataset everywhere, no runtime coupling. Carrier code maps live in integrations |
- Consequences: no platform DB in V1; reference data updates are a seed migration in several services (scripted).
- Revisit when: two services need notifications or flags at runtime with stronger consistency than events give.

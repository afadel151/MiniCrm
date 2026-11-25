# Gap analysis and conflict log (Phase 0, living document)

Started 2026-11-20 during Phase 2 data design. Precedence: ADRs > Tech Decisions v0.2 > V1 spec > CLAUDE.md > books.
Status legend: **Resolved** (decided, with reference) · **Open** (needs the product lead) · **Noted** (resolved by
precedence, recorded for traceability).

| # | Topic | Sources in conflict | Status | Resolution / next step |
|---|---|---|---|---|
| G1 | Money type | Spec §4.1 `numeric(12,2)` vs CLAUDE.md §7 integer DZD | **Resolved** | ADR-0001: `numeric(12,2)`; CLAUDE.md amended |
| G2 | FKs to other services' tables | Spec §4 (single DB) vs v0.2 §2.4 / CLAUDE.md §3 | **Noted** | v0.2 wins: ADR-0002 opaque ids + read models |
| G3 | Wilaya count | Spec §4.9 "1..58 [Likely]", analysis PDF "58 wilayas" vs CLAUDE.md §7 "69 wilayas / 1 541 communes since Nov 2025" | **Open (data)** | Schema is version-agnostic (C0003). Need the official dataset (decree + commune list) before seeding; nothing is hard-coded |
| G4 | Group G platform tables | Spec §4.9 vs v0.2 "platform is a library" | **Noted** | ADR-0005 |
| G5 | `carrier_status_mappings` placement | Spec Group D (orders) vs CLAUDE.md §7 "no carrier vocabulary in the domain" + v0.2 integrations owns adapters | **Noted** | Integrations owns carrier mappings and emits our vocabulary; orders never sees carrier codes |
| G6 | `message_templates` placement | Spec Group E (integrations) vs v0.2 §2.2 messaging owns templates | **Noted** | v0.2 wins: messaging; WhatsApp template registration goes through integrations by event |
| G7 | Marketing, service desk, workflow automation, reporting homes | CLAUDE.md §6 "not in v0.2 — Phase 1 must assign" | **Resolved** | ADR-0007: marketing split crm(segments)/messaging(campaigns); service desk → crm; workflow automation → new, deferred context; reporting → per-service replica/materialised views, no new service |
| G8 | Messaging library (Wolverine vs in-repo) | v0.2 §3.3: decided by spike S2 | **Open (spike)** | Outbox/inbox tables written as the envelope contract (ADR-0003); replaceable |
| G9 | Global score legal gate | Spec §6.7, CLAUDE.md §5, analysis PDF (law 18-07, ANPDP) | **Open (legal R1)** | Tables exist, flag OFF by default |
| G10 | Erasure of `phone_identities`/`phone_signals` | Spec §4.1 / §10.3 "legal question" | **Open (legal)** | Schema supports pseudonymous retention and hard purge per phone; policy pending |
| G11 | Phase order | CLAUDE.md §8 (Phase 0→1→1b→2) vs instruction to start with schemas | **Resolved** | Product lead directed schema-first; Phase 1 artefacts (`docs/01-architecture/`) written 2026-11-24, after the 7 schemas, matching them rather than the reverse. Still owed: Phase 1b independent review before any ADR from this round is accepted |

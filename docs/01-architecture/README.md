# 01-architecture — status: proposed, pending Phase 1b independent review

Phase 1 (CLAUDE.md §8) ran after Phase 2 (schemas), on explicit product-lead direction (G11) — written to match
the 7 services already built and validated, not derived in the abstract. **Nothing here is accepted until
Phase 1b** (`architecture-reviewer` agent, fresh context, adversarial) has run against it.

## Deliverables

| File | Covers |
|---|---|
| `bounded-contexts.md` | The 8 contexts, context map, DDD relationship pattern per pair, resolves G7 (marketing/service/automation/reporting homes — formalised in ADR-0007) |
| `c4-diagrams.md` | C4 L1 (System Context) and L2 (Container) |
| `sequence-diagrams.md` | The 6 flows from Tech Decisions v0.2 §3.4, grounded in the actual triggers/functions already built |
| `degradation-table.md` | What still works / what breaks when each service, RabbitMQ, Valkey, or a single Postgres instance is down |
| `nfr-targets.md` | Latency, availability, RTO/RPO targets — all `[Guessing]` until spike S1 (walking skeleton) measures them |

New ADR produced alongside this phase: `docs/adr/0007-marketing-service-automation-reporting-homes.md`.

## What this phase intentionally does not do

- No new tables for the two existing-service extensions ADR-0007 assigns (crm gains cases/segments, messaging
  gains campaigns) — those are future Phase 2 work for those two services, not retrofitted into schemas already
  built and validated.
- No contracts (`.proto`, event catalogue, JSON Schema) — that's Phase 3, and per G11 it still needs the
  sequence diagrams here as its own input first.
- No resolution of the still-open items this phase surfaces but doesn't own: G3 (wilaya dataset), G8 (Wolverine
  vs in-repo, spike S2), G9/G10 (legal gate, erasure policy) — listed in `bounded-contexts.md` §5, not
  re-decided here.

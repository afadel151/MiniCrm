# NFR targets (Phase 1)

Status: **Proposed** (Phase 1 gate). CLAUDE.md §4 tagged the hot-path latency target `[Guessing — set in
Phase 1]`; this document is that decision. All numbers here are **targets to validate against the walking
skeleton (Phase 5, spike S1)**, not measurements — tagged `[Guessing]` throughout for that reason, per CLAUDE.md
§8 rule 5. Revisit after S1 and after real traffic exists.

## 1. Latency

| Path | Target (p95, at the gateway) | Basis |
|---|---|---|
| Order creation (`POST /v1/orders`) | **< 300 ms** | CLAUDE.md §4's own figure; one synchronous hop (`GetScore`) at most, per Tech Decisions v0.2 §3.1 rule 2 |
| Score lookup (`GetScore`/`BatchGetScore` via gRPC, or the REST wrapper) | **< 150 ms** internal gRPC, **< 300 ms** at the gateway for the REST path | Single-flight/stampede-protected cache (Valkey) on a hot key; no cross-service hop from scoring itself |
| Confirmation link resolution (`GET /c/{token}`, anonymous) | **< 200 ms** | Single `SECURITY DEFINER` lookup, no RLS context to establish first (pre-tenant by design) |
| Public profile page (`GET /b/{slug}`, anonymous) | **< 200 ms** | Single view read (`pub.business_profiles`), cacheable (Valkey key `presence:{business}:profile`, presence.md §1) |
| Webhook ingestion (`POST` from a carrier/WhatsApp, store-first) | **< 100 ms** | Store-and-ack pattern (`ingest_webhook_event`) — processing is async, the HTTP response only needs the INSERT to commit |
| Everything else (CRUD inside one service, RLS, no cross-service call) | **< 200 ms** | No hop at all; dominated by the DB round-trip |

All targets are **p95 at the gateway**, not p50 and not measured inside a single service — a slow dependency
should show up in the number that matters to the caller.

## 2. Availability

| Target | Value | Basis |
|---|---|---|
| Per-service availability (steady state, excluding planned maintenance) | **99.5%** `[Guessing]` | Small team (Tech Decisions v0.2 §0.3 question 1 still open), single-region Kubernetes — not claiming a number a small team can't actually operate to |
| Replicas per service in production | **≥ 2** | CLAUDE.md §4 "Availability" row, already a hard rule, not a target to negotiate |
| Planned-maintenance budget | Rolling/canary deploys, zero-downtime expand-and-contract migrations as a separate K8s Job (CLAUDE.md §4) | Already decided; restated here so an availability number isn't read in isolation from how deploys actually happen |
| RPO (event loss tolerance) | **Zero** for anything that reached an outbox row; **unbounded** for a webhook that never reached us while a service was down | Matches the degradation table: outbox/inbox guarantees cover internal propagation, not external webhook delivery before it arrives |
| RTO (recovery time objective) | **< 15 minutes** to restore a single failed service `[Guessing]` | No number exists yet to validate this against; revisit after the first real incident or after a deliberate chaos exercise (Tech Decisions v0.2 §11 "kill a service during a flow") |

## 3. Throughput / scale sketch

Carried over from Tech Decisions v0.2 §9.3, restated as a Phase 1 commitment rather than a passing remark:
plan for a 3-node cluster, ~4 vCPU / 16 GB per node, before load — **validate with the walking skeleton**, not
with this document. No throughput number is set here because none of the 7 services has run against real
traffic; setting one now would be exactly the "present a guess as verified" CLAUDE.md §8 forbids.

## 4. What gates on these numbers

- Spike **S1** (walking skeleton, Tech Decisions v0.2 §14.1) is the first point any of these can be measured
  rather than guessed — the 2-week time-box explicitly exists to validate the microservices bet these targets
  assume.
- Tripwire **§14.2.2** ("median lead time... exceeds one working day") and the resource sketch in §9.3 are the
  two existing signals that would force a revisit of this document before Phase 5 even finishes.

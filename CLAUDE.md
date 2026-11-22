# CLAUDE.md — Algerian COD CRM (event-driven .NET microservices)

> Read this file fully at the start of every session. It is the contract between the team and Claude Code.
> Last updated: 2026-11-17. Owner: product lead. Change it through a PR, never silently.

## 1. What we are building

A multi-tenant SaaS **CRM** for e-commerce merchants, launched in **Algeria** first, then international.
It covers the full CRM scope from *CRM Fundamentals* (customers, sales, marketing, service, security,
configuration, reporting, workflow automation) **plus** a cash-on-delivery (COD) operations layer:
order confirmation, carrier shipping, cash reconciliation, returns.

The differentiator is the **Contact Score**: a reliability score attached to a **phone number**
(does this person answer calls, confirm, and actually accept the parcel?). Merchants see the score,
**never the behaviour behind it** (section 5).

North-star metric: **merchant return rate (refused/returned parcels ÷ shipped parcels)**.

## 2. Source of truth (read before designing; do not re-decide what is decided)

| Doc (put copies in `docs/reference/`) | Use it for | Authority |
|---|---|---|
| `CRM_Algeria_Technology_Decisions_v0.2.md` | Every technology choice, service map, comms rules, security, spikes, tripwires | **Binding.** Changing a decision = new ADR |
| `CRM_Algeria_V1_Specification.pdf` | Functional spec V1 | Binding for scope (**missing from repo — ask for it before Phase 1**) |
| `CRM_Fundamentals.md` (Kostojohn et al., 2011) | Functional checklist of a complete CRM (ch. 2 "Common CRM Application Functionality") | Reference; 500 KB — grep or query the graph, never load whole |
| `Building_Event-Driven_Microservices.md` (Bellemare) | Event design, data contracts, consistency | Reference; Kafka-centric, our broker is RabbitMQ |
| `NET-Microservices-Architecture.md` (Microsoft eBook) | .NET patterns, DDD, resilience | Reference; older, prefer current Microsoft Learn docs |

Precedence when sources conflict: **ADRs > Tech Decisions v0.2 > V1 spec > this file > reference books**.
If you find a conflict, stop and raise it; do not pick silently.

## 3. Architecture non-negotiables (from Tech Decisions v0.2)

- **.NET 10 LTS**, ASP.NET Core, minimal APIs, vertical slices. **PostgreSQL** per service. **RabbitMQ** (quorum queues) for events. **gRPC** internal, **REST + OpenAPI** at the edge via **YARP** gateway. **Nuxt + PrimeVue** frontend whose Nitro server is the **BFF**. **Valkey** for cache/sessions. **Kubernetes** runtime, Aspire for local dev. OpenTelemetry + Grafana stack.
- **Services arrive with their milestone**, not all at once: M0 identity-access + gateway + BFF; M1 crm; M2 orders; M3 scoring; M4 integrations; M5 messaging, presence. `platform` stays a shared library until two services need it at runtime.
- **Boundaries by data ownership and consistency**, not by module. Order + shipment + return stay in `orders` (they change together).
- **Database per service. No shared tables. No cross-database queries. No FK to another service.** Foreign IDs are opaque UUIDv7 values.
- **gRPC only for fresh reads, max one hop, always deadline + circuit breaker + fallback.** Never change another service's state over gRPC — emit an event.
- **Transactional outbox** for every published event; **idempotent consumers** (inbox table keyed `(event_id, consumer)`); **version guards** `WHERE version < @incoming`; bounded retries → DLQ; alert on DLQ depth > 0.
- **Multi-tenancy:** `business_id` on every tenant row + **PostgreSQL RLS**, tenant set **transaction-locally** (`set_config('app.business_id', …, true)`), app role is non-owner, EF Core global filter as second layer. In consumers, tenant comes from the event envelope. Every endpoint and consumer gets a cross-tenant attack test.
- **Event envelope** (CloudEvents-style): `eventId, type, source, subject, occurredAt, tenantId, correlationId, causationId, traceparent, schemaVersion`. JSON + JSON Schema per version, golden-file tests, additive changes only, dual-publish for breaking changes. Names are past-tense facts: `orders.order.delivered`.
- **Contracts are code:** `.proto` checked with `buf lint` + `buf breaking`; event schemas live in each service's `*.Contracts` project only.
- **Files** only through `IFileStorage` (local + S3-protocol implementations). No storage vendor SDK in business code.
- **Portability hedge:** only open-protocol infrastructure (K8s, PostgreSQL, AMQP, S3 API, OTLP). No cloud-proprietary messaging, identity or storage.
- **Licences:** no MediatR, AutoMapper, MassTransit v9, FluentAssertions, Duende. Every new dependency gets a licence + maintenance line in the PR. Messaging library = **Wolverine or in-repo library, decided by spike S2** — do not pick before the spike.
- **Tripwires (§14.2 of v0.2)** are live: >30 % time on plumbing, lead time > 1 day, call chain > 2 hops, two services changing together in most commits, local dev needing more than a couple of commands. If you observe one, say so in your report.

## 4. Scalability, reliability and data-intensity rules

Design every service for these from the first commit; optimise only with measurements.

| Concern | Rule |
|---|---|
| Stateless services | No in-memory session or cache that matters; scale with HPA (CPU) and KEDA (queue depth) |
| Load balancing | Ingress → gateway → services. gRPC uses headless service + client-side round-robin (spike S4) |
| Caching | Cache-aside in Valkey with explicit TTL and key prefix `{service}:{tenant}:…`; invalidate from events; never cache permission-sensitive data without the tenant in the key; stampede protection (single-flight) on hot keys such as score lookups |
| Database scaling | PgBouncer (transaction pooling; RLS setting must stay transaction-local), read replicas for read models/reports, **time-partition** large append-only tables (`order_status_log`, `outbox`, `inbox`, `score_signals`, `audit_log`) from day one, keep `business_id` in every PK/index so tenant sharding (e.g. Citus) stays possible |
| Hot paths | Order creation and score lookup must not depend on more than one synchronous call; target p95 < 300 ms at gateway [Guessing — set in Phase 1] |
| Read models | CQRS read models fed by events; every projection must be **rebuildable** (replay from outbox archive or snapshot + events) |
| Analytics | Do not run reports on OLTP primaries. Phase 1 must decide the analytics path (replica + materialized views first; event/CDC feed into a columnar store later) |
| Backpressure | Bounded consumer concurrency, prefetch limits, rate limiting at gateway (per tenant and per API key) |
| Fault tolerance | Timeouts everywhere, retries only on idempotent operations, circuit breakers, graceful degradation table per service (what still works when X is down) |
| Availability | ≥ 2 replicas per service in prod, PodDisruptionBudgets, readiness gates, zero-downtime expand-and-contract migrations run as a separate K8s Job |
| IDs and time | `Guid.CreateVersion7()`, `TimeProvider`, `DateTimeOffset` UTC everywhere |
| Broker evolution | RabbitMQ now. Keep the envelope and partition key (aggregate id) Kafka-compatible so a log-based broker can be added for replay/analytics without changing handlers |

## 5. Contact Score — product and privacy invariants

The score lives in the **scoring** service. Treat this section as a hard spec; changes need an ADR.

**Identity.** Key = `phone_hash = HMAC-SHA256(pepper, E.164 phone)`. Pepper from the secret store, never in the DB or logs. Scoring never stores raw phone numbers.

**Two layers.**
- *Tenant layer*: a merchant's own history with that customer. The merchant already owns this data, so its own CRM screens may show it in detail.
- *Global layer*: aggregated across all merchants. **Merchants see only a band/score + confidence label** (e.g. `A/B/C/D` or 0–100, plus "high / low confidence" or "not enough data"). Behind feature flag `global_score_visible` (default off until legal review R1).

**What a merchant must never see from the global layer:** reason codes, signal counts, refusal/return history, which or how many other merchants, dates, order values, other names or addresses linked to the phone. Reason codes exist **internally** for audit, disputes and the phone owner's own view.

**Signals (inputs)** — each with source, weight, timestamp, model version:
call answered / unreachable / wrong number (`crm.call.logged`), confirmation outcome, delivered, refused at door, returned with **fault classification** (only customer-fault returns count against the phone; carrier/merchant fault do not), cancellation after confirmation.

**Anti-abuse rules.**
- Carrier-verified outcomes (webhooks) outweigh manual merchant input; manual negative signals are capped.
- Per-merchant contribution cap so one merchant cannot sink a number; minimum distinct merchants before a global score is shown.
- Time decay, and a decay/reset path for **recycled phone numbers**.
- A new or thin-history number is **"not enough data"**, never "bad".
- **No lookup oracle:** a merchant can only fetch the score of a phone that exists in its own contacts/orders; lookups are rate-limited and audit-logged.
- The score is **advisory**. It may drive suggested policies (extra confirmation call, stop-desk only, deposit) but never auto-blocks without a merchant-configured rule.

**Phone-owner rights.** OTP-verified self-view of their own score and reasons, dispute/correction flow, consent and retention records. Disputes freeze the global score for that phone until resolved.

**Model governance.** Rules engine in C# with versioned parameters (`score_models`), deterministic and reproducible from signals; any new model must beat the current one on a held-out backtest of return rate. Thresholds are config, tagged `[Guessing]` until real data exists.

## 6. Functional scope map (CRM Fundamentals → services)

| CRM area (book ch. 2) | Must include | Home |
|---|---|---|
| Customers | Contacts, companies, multiple phones, relationships, tags, custom fields, interaction timeline, dedup/merge | `crm` |
| Sales | Leads → opportunities, pipelines/stages, quotes, products/price lists, forecasting | `crm` (pipeline) + `orders` (products, quotes→orders) |
| COD operations | Order lifecycle, confirmation call center, wilaya/commune addressing, home vs stop-desk, carrier shipping, cash reconciliation, returns | `orders` + `integrations` |
| Marketing | Segments/lists, campaigns, WhatsApp/SMS/email sends, opt-in/opt-out, attribution to orders | **Not in v0.2 — Phase 1 must assign** (proposed: `messaging` or new `engagement` service) |
| Service | Cases/tickets, queues, SLAs, escalation, knowledge base, customer self-service portal | **Not in v0.2 — Phase 1 must assign** (proposed: `crm` until load justifies a split) |
| Security | Roles, permissions, record- and field-level security, exceptions, audit | `identity-access` + each service |
| Configuration | Custom fields/entities without code, event hooks, public API | `crm` + gateway `/v1` |
| Reporting | Dashboards, report builder, export, merchant KPIs (confirmation rate, delivery rate, return rate, cash outstanding) | **Not in v0.2 — Phase 1 must decide analytics path** |
| Workflow automation | Triggers on events, conditions, actions (assign, notify, change status, call task) — "active CRM" | **Not in v0.2 — Phase 1 must assign** (proposed: `automation` service consuming events) |

## 7. Algeria-specific rules (use the `algeria-cod-crm` skill for depth)

- **69 wilayas and 1 541 communes** since the November 2025 reform (previously 58). Store wilayas/communes as versioned reference data with effective dates, and map carrier codes per carrier — carriers may still use old codes. Never hard-code the list.
- Phones normalised to **E.164 (`+213…`)** with libphonenumber; mobile prefixes are data, not code.
- Money as **`numeric(12,2)` DZD** (C# `decimal`, never floats), per V1 spec §4.1 — see `docs/adr/0001-money-as-numeric-12-2.md` (amended 2026-11-20); COD amount stored explicitly. Delivery status and cash status are **separate state machines**.
- Every status change append-only logged (who/what/when/source).
- UI in **Arabic (RTL) and French**; English when going international. Western digits for phones, prices and dates [confirm with users]. Call scripts may need Darija.
- Carrier statuses mapped to our own vocabulary through one `ICarrierAdapter` interface; no carrier vocabulary in the domain.
- Internationalisation later: currency, country, address model and phone region must be per-tenant settings, not assumptions.

## 8. How we work: phases, gates, model routing

Every phase produces files in `docs/` and ends with a **gate**: a summary for the human, open questions, and nothing in the next phase starts until the human says go.
Model routing follows the project rule "specify model, speed and effort for every planned task". Default speed is **standard**; use **fast mode** (`/fast`, same model quality, lower latency, extra cost) only for interactive debugging under time pressure.

| Phase | Deliverables | Model · effort · speed | Skills / tools |
|---|---|---|---|
| 0. Context & gaps | `docs/00-context/gap-analysis.md`: spec vs v0.2 vs CRM Fundamentals, conflicts, open questions | Opus 5.5 · high · standard | graphify on `docs/reference`, Projects/doc reads |
| 1. Domain & system design | Bounded contexts, context map, service responsibilities incl. the unassigned areas in §6, C4 L1–L2, sequence diagrams for the 6 flows in v0.2 §3.4, degradation table, NFR targets, ADRs | Opus 5.5 · xhigh · standard | `building-event-driven-microservices-dotnet`, `algeria-cod-crm`, c4-architecture |
| 1b. Independent review | Adversarial review of Phase 1 + the Contact Score design (abuse, privacy, failure modes) in a fresh context | Fable 5.2 · high · standard (`architecture-reviewer` agent) | — |
| 2. Data design | Per-service logical + physical schema (ERD in Mermaid, DDL), RLS policies, indexes, partitioning, outbox/inbox tables, retention, seed/reference data, migration strategy | Opus 5.5 · high · standard | database-design plugin, Postgres MCP (dev DB only) |
| 3. Contracts | `.proto` files, event catalogue (`docs/contracts/event-catalogue.md`), JSON Schemas, OpenAPI drafts | Opus 5.5 · high (design) → Sonnet 5.5 · medium (golden tests) | `building-event-driven-microservices-dotnet` |
| 4. Implementation plan | `docs/plan/`: milestones M0–M5 → epics → tasks, each task with acceptance criteria, test list and its own model · effort · speed line | Opus 5.5 · high · standard | superpowers (writing-plans) |
| 5. Walking skeleton (spike S1) + spikes S2–S5 | Service template, ServiceDefaults, gateway, BFF login, identity, crm, outbox→RabbitMQ→consumer, one trace across all hops, deployed to K8s | Opus 5.5 · high · standard | Microsoft Learn MCP, Nuxt MCP |
| 6. Feature slices | Endpoints, handlers, consumers, UI screens per task | Sonnet 5.5 · medium (routine) / high (state machines, money, scoring, tenancy) · standard | feature-dev, frontend-design, PrimeVue MCP |
| 7. Verification | Review, security review, cross-tenant tests, E2E (ar + fr), k6 load | Opus 5.5 · high · standard (`code-reviewer` agent, fresh context) | code-review, security-guidance, Playwright MCP |
| Exploration / search | Locating code, reading docs | Haiku 5.5 · low · standard (`explorer` agent) | graphify |

Rules for every task:
1. Read the relevant ADRs and the owning service's `README.md` before editing.
2. Write or update tests first for state machines, money math, tenancy and scoring.
3. One service per PR unless the change is a contract change (then: contracts first, producer, consumers).
4. End every coding task with the **scaffold-honesty report**: what was not generated, what it must do in production, and whether the code was **compiled and run** or only written.
5. Mark unverified facts `[Likely]` / `[Guessing]` like v0.2 does; never present a guess as verified.

## 9. Repository layout (target)

```
docs/
  reference/            source documents (read-only)
  00-context/  01-architecture/  02-data/  contracts/  plan/  adr/  runbooks/
src/
  BuildingBlocks/       ServiceDefaults, Messaging (outbox/inbox), Tenancy, Contracts.Abstractions, Phone, Testing
  Gateway/              YARP
  Services/<Name>/      <Name>.Contracts  <Name>.Domain  <Name>.Infrastructure  <Name>.Api  <Name>.Worker
  Web/                  Nuxt app (UI + BFF in server/)
  AppHost/              Aspire orchestration
tests/<Name>.UnitTests  <Name>.ContractTests  <Name>.IntegrationTests (Testcontainers)  e2e/ (Playwright)  load/ (k6)
deploy/helm/<name>/  deploy/gitops/
tools/dotnet-new-template/   the service template (most important investment)
```

## 10. Conventions

**.NET:** nullable on, warnings as errors, central package management, `.editorconfig` + analyzers, records for contracts, `System.Text.Json`, plain handlers (no mediator library), Mapperly or manual mapping, FluentValidation (licence check), xUnit + `FakeTimeProvider`, Problem Details errors, `CancellationToken` end to end, Serilog with PII scrubbing (no phone numbers or tokens in logs), architecture tests forbid cross-service references except `*.Contracts`.
**Frontend:** Nuxt + TypeScript strict, PrimeVue (auto-import, tree-shaken), `@nuxtjs/i18n` with `ar` (rtl) and `fr`, CSS logical properties only (no `left/right`), generated OpenAPI clients (drift fails the build), TanStack Vue Query or `useFetch`, Pinia only when needed, VeeValidate/PrimeVue Forms + Zod, Vitest + Playwright in both locales. Tokens never reach browser JS.
**Git:** trunk-based, conventional commits, small PRs, feature flags for unfinished work.
**Docs:** Mermaid for diagrams, one ADR per decision (`docs/adr/NNNN-title.md`, context → options → decision → consequences → revisit when).

## 11. Commands

Fill in during Phase 5; until then, do not invent commands.
```
# dotnet run --project src/AppHost            # whole system locally
# dotnet test                                 # all tests
# buf lint && buf breaking --against '.git#branch=main'
# cd src/Web && pnpm dev | pnpm test | pnpm e2e
```

## 12. Tools Claude should use

- **graphify**: build the graph on `docs/reference` in Phase 0 and on the repo once code exists; read `graphify-out/GRAPH_REPORT.md` before broad searches; rebuild after large changes.
- **Skills:** `building-event-driven-microservices-dotnet` (any messaging work), `algeria-cod-crm` (any order, confirmation, carrier, cash, return work), `frontend-design` (new screens), `dataviz` (dashboards).
- **MCP (see `.mcp.json`):** Microsoft Learn (.NET/ASP.NET/EF Core facts), Nuxt docs, PrimeVue components, Context7 (other libraries), Postgres MCP (**dev database only, restricted mode**), Playwright (UI checks).
- Prefer official docs via MCP over memory for any API signature, package name or version.

## 13. Definition of done

Builds with zero warnings · unit + contract + integration tests pass · cross-tenant test for each new endpoint/consumer · traces visible across hops · OpenAPI/proto/event schema updated and checked · migrations reviewed as SQL · ar + fr strings present and RTL checked · no PII in logs · dashboards/alerts for new queues · README of the service updated · scaffold-honesty report in the PR.

## 14. Never

Share a database between services · call another service to change its state · publish without the outbox · ack before commit · store raw phone numbers in scoring · expose score reasons to merchants · hard-code wilayas, carrier fees or statuses · use floats for money (`numeric(12,2)`, ADR-0001) · auto-migrate on startup · add a commercially licensed library without approval · commit secrets or real customer data · run destructive SQL against anything but a local dev database.

## 15. Open questions (keep this list current)

1. Team size and Kubernetes production experience (v0.2 §0.3) — sets how fast services can be added.
2. V1 specification PDF — not in the repo yet.
3. Where marketing, service desk, workflow automation and reporting live (§6).
4. Global score launch conditions: legal review R1 (Algerian personal-data law 18-07 and its authority, ANPDP), consent wording, dispute SLA.
5. SaaS billing for merchants (local payment methods vs international) — not covered by v0.2.
6. Telephony: manual call dispositions in V1; click-to-call / call-center integration later?
7. Score display format (band vs 0–100) and the wording merchants see.

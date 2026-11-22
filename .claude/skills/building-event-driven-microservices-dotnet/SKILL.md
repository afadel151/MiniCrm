---
name: building-event-driven-microservices-dotnet
description: Use when designing, building, scaffolding, or reviewing event-driven microservices in .NET or ASP.NET Core - services talking through Kafka, RabbitMQ, Azure Service Bus or another broker; event/message contracts; transactional outbox, idempotent consumers, sagas, retries, dead-letter queues; eventual consistency behind REST APIs; or choosing between MassTransit, Wolverine, NServiceBus, Rebus and raw broker clients. Also use when the user only says "microservices", "async messaging", "pub/sub", "domain events", "integration events" or "CQRS", or reports duplicated, lost or out-of-order messages in a .NET service.
---

# Building Event-Driven Microservices in .NET

## Overview

Three facts drive every design decision here:

1. **Events are the public contract.** Each service owns its data and publishes facts about it; other services never reach into its database.
2. **Brokers deliver at-least-once.** Duplicates and redeliveries are normal, so every consumer must tolerate them.
3. **State change and announcement must be atomic.** Writing to the database and then publishing is two writes that can half-fail; the outbox pattern makes it one.

If a proposed design violates one of these, fix that before discussing anything else.

## Step 0: Is this the right architecture?

Check the observable situation first. Distributed messaging costs real operational effort, and recommending it by default is a disservice.

| Observable signal | Recommend |
|---|---|
| One team, one deploy pipeline, no independent scaling need | Modular monolith with in-process domain events; add an outbox when a second consumer appears |
| Caller needs the result inside the same HTTP request | Synchronous call (HTTP/gRPC); use events only for the side effects |
| Business cannot accept stale reads anywhere in the flow | Keep that flow inside one service and one transaction |
| Several teams own different data, fan-out to 2+ consumers, or the producer must not wait on consumers | Proceed with the steps below |

When the first or third row applies, say so plainly at the start of the answer and offer the monolith-first path. Proceed with event-driven only if the user still wants it or the fourth row applies.

## Workflow

1. **Pin the context by stating assumptions, not interrogating.** Cover broker (existing or free choice), .NET version (default to the newest LTS unless the project says otherwise), database, hosting target, ordering needs, expected volume. Ask at most one blocking question.
2. **Choose broker and library.** Read `references/brokers-and-libraries.md`. Library licensing and versions change; confirm them with a web search or the package docs before recommending.
3. **Design events before code.** Read `references/event-contracts.md`. Produce an event catalogue (name, kind, producer, partition key, consumers, schema owner) and get it agreed before writing handlers.
4. **Lay out the solution** using the default layout below.
5. **Implement reliability.** Read `references/reliability-patterns.md` for outbox, idempotent consumers, retries and dead-lettering, ordering, sagas, and API-edge consistency.
6. **Instrument, test, deploy.** Read `references/observability-testing-deployment.md`.
7. **Report honestly** (see Scaffold honesty).

## Default solution layout

```
src/
  Orders.Contracts/        published events only: records + constants, no domain types, no EF
  Orders.Domain/           aggregates, domain events (internal)
  Orders.Infrastructure/   EF Core, outbox, broker adapters
  Orders.Api/              ASP.NET Core minimal API: validate, write state + outbox row, return 202/201
  Orders.Worker/           Worker Service: consumers, outbox relay
tests/
  Orders.UnitTests/  Orders.ContractTests/  Orders.IntegrationTests/   (Testcontainers)
```

`Api` and `Worker` can start as one process and split when scaling needs differ. Keep `Contracts` free of references to anything internal, because consumers will compile against it and every leaked type becomes a coupling.

## Rules that prevent most incidents

| Rule | Why |
|---|---|
| Never `SaveChanges` then publish; write an outbox row in the same transaction | Crash between the two loses the event permanently |
| Make every consumer idempotent (dedupe table or a naturally idempotent upsert) | Redelivery after rebalance, timeout or retry is guaranteed to happen |
| Acknowledge only after the effect is durable (store Kafka offset / complete the Service Bus message / ack the RabbitMQ delivery after the DB commit) | Early ack turns a crash into silent data loss |
| Bound retries with backoff and jitter, then dead-letter with context | One poison message must not block a partition or queue forever |
| Choose the partition key from the aggregate id when order matters | Order is only guaranteed per key (Kafka partition, Service Bus session) |
| Change contracts additively; a breaking change is a new event version published alongside the old | Producers and consumers deploy independently |
| Name events as past-tense business facts (`OrderPlaced`) | Intent survives; `OrderUpdated` with 30 fields couples everyone to your schema |
| Carry `eventId`, `correlationId`, `causationId`, `occurredAt` and W3C `traceparent` on every message | Without them you cannot debug a flow across services |
| Do not simulate RPC over the broker | If the caller needs an answer now, call HTTP/gRPC with a timeout |
| No shared database between services | A shared schema is a distributed monolith |
| Pass `CancellationToken` end to end and drain in-flight work on shutdown | Rolling deploys otherwise redeliver or drop messages |
| Use `TimeProvider` and producer-assigned ids | Testable time, stable dedupe keys |

## Symptom to pattern

| Symptom | Likely cause | Reach for |
|---|---|---|
| Downstream service sometimes never hears of an event | Dual write | Outbox (`reliability-patterns.md`) |
| Double charge, double email, duplicate rows | Redelivery without dedupe | Idempotent consumer, idempotency key to third parties |
| Old value overwrites new one | Unordered delivery or concurrent consumers on one key | Key by aggregate, version check `WHERE version < @incoming` |
| Consumer lag grows, then everything stops | Poison message or handler slower than poll/lock timeout | DLQ/parking lot, tune timeouts, bounded concurrency |
| UI shows stale data right after a write | Eventual consistency unaddressed | 202 + status resource, return written state, version token |
| Needs one transaction across services | Cross-service invariant | Saga / process manager with compensations |
| Consumers broke after a release | Breaking contract change | Compatibility rules, contract tests, dual-publish |
| Frequent rebalances | Handler exceeds poll interval, aggressive scaling | Shorter handlers, cooperative-sticky assignment, static membership |

## .NET defaults

- Generic Host (`Host.CreateApplicationBuilder`); consumers are `BackgroundService`s. Never fire-and-forget with `Task.Run` inside handlers.
- Blocking client calls (Kafka `Consume`) need `await Task.Yield()` first in `ExecuteAsync` so host startup is not held up.
- `System.Text.Json` with records for contracts; tolerant reader (unknown fields ignored). `DateTimeOffset` in UTC. `Guid.CreateVersion7()` for time-ordered ids (.NET 9+).
- Options pattern with `ValidateDataAnnotations().ValidateOnStart()` for broker settings.
- Resilience for outbound HTTP and DB calls via `Microsoft.Extensions.Http.Resilience` / Polly v8; broker redelivery policy for message-level retries.
- OpenTelemetry for traces/metrics/logs; propagate trace context through message headers by hand if the client library does not.
- Aspire (the orchestration stack formerly branded .NET Aspire) is a good local multi-service dev and test host; confirm current package names before scaffolding.
- For REST endpoints, EF Core query tuning and general C# refactoring, defer to the dedicated dotnet skills if installed; this skill covers the messaging side.

## Scaffold honesty

Whenever code is generated, end with a short list of three things: what was deliberately **not** generated (authentication, secrets, infrastructure-as-code, schema-registry setup, broker provisioning, dead-letter replay tooling), what each omitted piece must do in production, and whether the code was compiled and run or only written. Unverified code presented as working is the most expensive kind of help.

## Verify before asserting

Package versions, licensing terms, and client-library signatures drift. Treat these as unverified until checked against current docs: MassTransit/MediatR licensing, RabbitMQ.Client and Azure SDK API shapes, OpenTelemetry package names, Aspire package names, KEDA scalers. Search first when the answer would change the recommendation.

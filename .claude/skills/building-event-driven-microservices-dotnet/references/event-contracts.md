# Event contracts

Design these before writing any handler. A contract is harder to change than code, because other teams compile against it.

## 1. What kind of event is it?

| Kind | Payload | Use when | Trade-off |
|---|---|---|---|
| **Notification** | Id and type only (`OrderPlaced { OrderId }`) | Payload is large or sensitive, consumers can call back | Consumers depend on a callback API being up; extra latency and coupling |
| **State (fact)** | The relevant state of the entity after the change | Default for integration between services; lets consumers build local read models without calling back | Payload becomes a public schema; keep it to what consumers need |
| **Delta** | What changed (`AddressChanged { Old, New }`) | The change itself is the information (audit, billing adjustments) | Consumers that miss one cannot recover state; pair with a periodic snapshot |

Default to state events with a deliberately small payload. Publish intent-level events (`OrderPlaced`, `OrderCancelled`) rather than one `OrderUpdated`, because intent lets consumers react selectively and keeps your table layout private.

Commands (`ChargeCard`) are different: addressed to one handler, expect an effect. Send them to a queue, not a topic that many services subscribe to.

## 2. Envelope

Every message carries the same metadata so tooling, tracing and dedupe work uniformly. CloudEvents is a good model; either adopt it or mirror its field names.

```csharp
public sealed record EventEnvelope<T>(
    Guid EventId,                 // producer-assigned, stable across retries: the dedupe key
    string Type,                  // "orders.order-placed.v1"
    string Source,                // producing service
    DateTimeOffset OccurredAt,    // when the fact happened, UTC
    string Subject,               // aggregate id, usually equals the partition key
    Guid CorrelationId,           // the whole business flow
    Guid? CausationId,            // the EventId that triggered this one
    T Data);

public sealed record OrderPlaced(
    Guid OrderId, Guid CustomerId, IReadOnlyList<OrderLine> Lines, decimal Total, string Currency);

public sealed record OrderLine(string Sku, int Quantity, decimal UnitPrice);
```

Put `traceparent` in transport headers rather than the body, because tracing is infrastructure.

Serialization: `System.Text.Json` with source generation; camelCase; enums as strings; `DateTimeOffset` in ISO 8601 UTC; money as `decimal` plus an explicit currency, never as float. Keep the body format identical across all transports.

## 3. Versioning rules

| Compatible (ship freely) | Breaking (needs a new version) |
|---|---|
| Add an optional field | Remove or rename a field |
| Add a new event type | Change a field's type or meaning |
| Loosen validation | Tighten validation or make a field required |
| Add an enum value, *if* consumers are written to tolerate unknown values | Reuse a field for something else |

Rules that make this work in practice:

- **Tolerant reader.** Consumers ignore unknown fields and map unknown enum values to a safe default. Do not enable strict unmapped-member rejection.
- **Producers own the contract**; consumers do not edit it. A consumer-specific need is a conversation, or an anti-corruption mapper on the consumer side.
- **Breaking change procedure:** publish `...v2` alongside `...v1`, migrate consumers one by one, watch `v1` traffic fall to zero, then retire it. Do not flip a topic in place.
- **Deploy order:** consumers that understand the new version first, producers after.
- **Never repurpose** an old field to mean something new, even if the type matches.

## 4. Enforcing contracts

- **Kafka:** a schema registry with Avro, Protobuf or JSON Schema and a compatibility mode (backward or full) rejects bad schemas at publish time. The Confluent .NET client has serializer packages for this; confirm current package names.
- **Other brokers:** check JSON Schema or AsyncAPI files into the contracts repo, and enforce with tests.
- **Contract tests in CI:**
  - Golden-file test per published event version: serialize a sample, compare with a committed JSON file. A diff means a contract change and forces a conscious decision.
  - Consumer test that feeds a payload with extra unknown fields and an old minimal payload; both must parse.
- **Catalogue:** keep one table in the repo or an AsyncAPI document listing every event.

| Event | Kind | Producer | Key | Consumers | Schema owner | Retention |
|---|---|---|---|---|---|---|
| `orders.order-placed.v1` | State | Orders | OrderId | Billing, Inventory, Notifications | Orders team | 7 days |

## 5. Keys and partitioning

- Key by the aggregate whose order matters (usually the aggregate id). Everything for one order then lands on one partition and is processed in order.
- Avoid low-cardinality keys (country, status): they create hot partitions.
- Partition count caps consumer parallelism and is painful to raise later (it changes key-to-partition mapping), so estimate generously.
- Events about different aggregates have no ordering relationship. If a consumer needs A before B across aggregates, model it as a workflow or make the consumer tolerate either order.

## 6. Data protection

- Include only the personal data consumers need. Prefer ids plus a lookup over copying names, addresses and phone numbers into events.
- Events in a retained log are hard to erase. Options: encrypt personal fields per subject and delete the key (crypto-shredding), or keep personal data out of the log entirely.
- Check regional data-protection law (for example GDPR, Algeria's Law 18-07) before choosing where brokers are hosted and how long topics retain data.

## 7. Anti-patterns

- Event payload equals the table row: every column rename becomes a breaking change.
- `EntityUpdated` with a full copy and no intent: consumers diff to guess what happened.
- God events that mix concerns, so unrelated consumers break together.
- Consumers that need another service's current data on every event, which turns events into synchronous calls with extra steps. Keep a local read model fed by events instead.
- Using the event body as the only place `eventId` lives, so a retry produces a new id and defeats dedupe. Assign the id once, when the outbox row is created.

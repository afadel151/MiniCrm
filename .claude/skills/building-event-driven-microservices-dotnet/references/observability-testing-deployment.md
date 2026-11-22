# Observability, testing and deployment

Code was written without compiling. Confirm package names and APIs against current docs.

Contents: 1 Observability, 2 Testing, 3 Deployment and operations

## 1. Observability

**Goal:** one trace per business flow, across HTTP, outbox, broker and consumers, plus alerts on the four numbers that reveal trouble early.

### Trace propagation through messages

Many broker clients do not propagate context automatically. Do it explicitly at the adapter layer:

```csharp
static readonly ActivitySource Source = new("Acme.Messaging");

// Producer side (in the outbox relay): store traceparent at write time, restore it here
using var activity = Source.StartActivity("orders.order-placed publish", ActivityKind.Producer);
activity?.SetTag("messaging.system", "kafka");
activity?.SetTag("messaging.destination.name", topic);
Propagators.DefaultTextMapPropagator.Inject(
    new PropagationContext(activity?.Context ?? default, Baggage.Current),
    headers, (h, k, v) => h.Add(k, Encoding.UTF8.GetBytes(v)));

// Consumer side
var parent = Propagators.DefaultTextMapPropagator.Extract(default, headers,
    (h, k) => h.TryGetLastBytes(k, out var b) ? [Encoding.UTF8.GetString(b)] : []);
using var consume = Source.StartActivity("orders.order-placed process", ActivityKind.Consumer, parent.ActivityContext);
```

Because the outbox publishes later, capture `Activity.Current?.Id` (the W3C `traceparent`) into the outbox row when it is written, and use it as the parent when the relay publishes. Otherwise the trace breaks at the outbox.

Register sources and exporters once: `AddOpenTelemetry().WithTracing(t => t.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation().AddSource("Acme.Messaging").AddOtlpExporter())`. Frameworks (MassTransit, Wolverine, NServiceBus) and the Azure SDK ship their own sources; enable those instead of hand-rolling where available.

### Logs

Use structured logging with a scope per message: `using (log.BeginScope(new Dictionary<string, object>{ ["eventId"] = id, ["correlationId"] = cid, ["consumer"] = name }))`. Never log full payloads containing personal data.

### Metrics and alerts

| Signal | Alert when | Meaning |
|---|---|---|
| Consumer lag (Kafka) / queue depth (RabbitMQ, Service Bus) | Growing for N minutes | Handler too slow, stuck, or under-scaled |
| Age of oldest unpublished outbox row | Over a few seconds to minutes | Relay stalled; events not leaving |
| Dead-letter depth | Above zero | Messages failing permanently; someone must look |
| Handler duration p95 and retry rate | Trending up | Downstream degradation before it becomes an outage |
| Rebalance count (Kafka) | Frequent | Handlers exceed poll interval or churn in pods |

### Health checks

- **Liveness:** the process is alive.
- **Readiness:** dependencies reachable (database, broker).
- **Stall detection:** record `lastMessageProcessedAt`; if the consumer has messages waiting but nothing processed for X minutes, report unhealthy. A consumer thread can be dead while the pod looks fine.

## 2. Testing

| Layer | What to test | Tooling |
|---|---|---|
| Unit | Handlers and domain logic with fakes; time via `FakeTimeProvider` | xUnit/NUnit, `Microsoft.Extensions.TimeProvider.Testing` |
| Contract | Golden JSON file per published event version; tolerant-reader tests (extra fields, minimal old payload) | Plain tests + committed JSON; Pact message contracts if teams are separate |
| Reliability | Deliver the same event twice and assert one effect; deliver out of order and assert the newest state wins; throw a permanent error and assert it reaches the DLQ with context | Integration harness below |
| Integration | Real broker and database in containers; API → outbox → broker → consumer → database | Testcontainers (PostgreSQL, Kafka, RabbitMQ; Service Bus emulator container, confirm availability) |
| Flow / end to end | A few critical business flows across all services | Aspire testing host (`DistributedApplicationTestingBuilder`) or docker compose |

Framework harnesses exist (MassTransit in-memory test harness, Wolverine tracked sessions) and make handler tests fast; they do not replace one real-broker integration test per transport.

Asynchronous assertions: poll with a deadline instead of `Thread.Sleep`.

```csharp
public static async Task Eventually(Func<Task<bool>> condition, TimeSpan? timeout = null, CancellationToken ct = default)
{
    var deadline = DateTimeOffset.UtcNow + (timeout ?? TimeSpan.FromSeconds(10));
    while (DateTimeOffset.UtcNow < deadline)
    {
        if (await condition()) return;
        await Task.Delay(100, ct);
    }
    throw new TimeoutException("Condition not met before deadline");
}
```

Test the unhappy paths on purpose: broker unavailable at publish time (outbox row remains), relay crash mid-batch (duplicates appear, consumers cope), consumer crash after effect but before ack (redelivery is harmless).

## 3. Deployment and operations

- **Scaling:** consumer replicas beyond partition count are idle. Scale on lag (KEDA has Kafka, RabbitMQ and Service Bus scalers; confirm current versions), not CPU.
- **Graceful shutdown:** on `SIGTERM`, stop pulling new messages, finish in-flight handlers, store offsets / complete messages, then exit. Set `HostOptions.ShutdownTimeout` above your longest handler, and the orchestrator's termination grace period above that.
- **Rolling deploys:** a pod restart triggers a rebalance. Use cooperative-sticky assignment and (for stateful consumers) static group membership to reduce disruption.
- **Release ordering for contract changes:** deploy consumers that understand the new version first, then producers; retire the old version only after traffic hits zero.
- **Database migrations:** expand, then contract. The outbox and inbox tables are part of every service's schema and migrate with it.
- **Provisioning:** topics, queues, subscriptions, DLQs and ACLs from infrastructure-as-code (Terraform, Bicep). Review partition counts and retention like schema changes.
- **Configuration:** broker credentials from a secret store (Key Vault or equivalent), never in appsettings committed to git; consumer-group and queue names follow a convention (`<service>.<event>`), so ownership is obvious.
- **Environment isolation:** separate brokers or strict prefixes per environment; a staging consumer on a production topic is a classic incident.
- **Runbooks:** how to inspect and replay the DLQ, how to reset a consumer group's offsets, how to pause the outbox relay, how to roll back a producer without orphaning events. Write them before the first on-call.

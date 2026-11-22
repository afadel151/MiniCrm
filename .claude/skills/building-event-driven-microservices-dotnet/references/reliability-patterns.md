# Reliability patterns

Code was written without compiling. It targets EF Core with PostgreSQL; SQL Server notes are inline. Adapt names to the project.

Contents: 1 Outbox, 2 Idempotent consumer, 3 Retries and dead-lettering, 4 Ordering and concurrency, 5 Sagas, 6 Eventual consistency at the API edge, 7 Read models, 8 Calling synchronous APIs from consumers

## 1. Transactional outbox

Problem: `SaveChanges()` then `producer.Produce()` is a dual write. A crash between them loses the event; reversing the order publishes events for state that never committed.

Fix: store the event in an outbox table in the **same transaction** as the state change, and let a relay publish it later.

```csharp
public sealed class OutboxMessage
{
    public long Seq { get; private set; }                       // identity column, used for ordering
    public Guid EventId { get; init; } = Guid.CreateVersion7();  // assigned once; the consumers' dedupe key
    public required string Type { get; init; }                   // "orders.order-placed.v1"
    public required string Key { get; init; }                    // partition key / aggregate id
    public required string Payload { get; init; }                // serialized envelope
    public required DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset? PublishedAt { get; set; }
}
```

Write path (the endpoint knows nothing about the broker):

```csharp
app.MapPost("/orders", async (PlaceOrder cmd, OrdersDb db, TimeProvider clock, CancellationToken ct) =>
{
    var now = clock.GetUtcNow();
    var order = Order.Place(cmd, now);
    db.Orders.Add(order);
    db.Outbox.Add(OutboxMessages.For(new OrderPlaced(order.Id, order.CustomerId, order.Lines, order.Total, "DZD"),
                                     key: order.Id.ToString(), now));
    await db.SaveChangesAsync(ct);                  // one transaction: state + announcement
    return Results.Accepted($"/orders/{order.Id}", new { order.Id, Status = "Pending" });
});
```

Relay (a `BackgroundService` in the worker):

```csharp
public sealed class OutboxRelay(IServiceScopeFactory scopes, IMessagePublisher publisher, ILogger<OutboxRelay> log)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(500));
        while (await timer.WaitForNextTickAsync(ct))
        {
            try { await DrainOnceAsync(ct); }
            catch (Exception ex) when (ex is not OperationCanceledException)
            { log.LogError(ex, "Outbox drain failed; will retry"); }
        }
    }

    private async Task DrainOnceAsync(CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<OrdersDb>();
        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var batch = await db.Outbox
            .FromSqlRaw("""
                SELECT * FROM outbox
                WHERE published_at IS NULL
                ORDER BY seq
                LIMIT 100
                FOR UPDATE SKIP LOCKED
                """)
            .ToListAsync(ct);

        foreach (var m in batch)
        {
            await publisher.PublishAsync(m.Type, m.Key, m.EventId, m.Payload, ct); // throw => rollback, batch retried
            m.PublishedAt = DateTimeOffset.UtcNow;
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }
}
```

Properties and caveats:

- Delivery is **at-least-once**: a crash after publish but before commit republishes the batch. That is why consumers must be idempotent (section 2) and `EventId` must be stable.
- **Ordering:** `SKIP LOCKED` lets several relay instances run, but two relays can publish different events of the same key out of order. For strict per-key order run one active relay (advisory lock or leader election) or shard the outbox by key hash.
- Publishing while holding a database transaction is acceptable for small batches; for slow brokers, claim rows first (set a `claimed_until` column) and publish outside the transaction.
- SQL Server equivalent hints: `WITH (UPDLOCK, READPAST, ROWLOCK)` and `TOP (100)`.
- Delete or archive published rows on a schedule, or the table grows without bound. Alert on the age of the oldest unpublished row.
- Alternatives: change-data-capture (Debezium) reading the outbox table (no polling, more infrastructure), or the built-in outbox of the chosen framework (Wolverine, MassTransit, NServiceBus). Prefer the framework outbox when one is already adopted; do not stack two.

## 2. Idempotent consumer

Redelivery is normal (rebalance, lock timeout, relay retry, producer retry). Pick one strategy per handler:

1. **Naturally idempotent effect:** upsert by key, set state rather than increment, `INSERT ... ON CONFLICT DO UPDATE`. Cheapest; use whenever the effect allows.
2. **Inbox table:** record `(event_id, consumer)` in the same transaction as the effect.

```csharp
public async Task HandleAsync(OrderPlaced evt, EventMeta meta, CancellationToken ct)
{
    await using var tx = await db.Database.BeginTransactionAsync(ct);

    var inserted = await db.Database.ExecuteSqlInterpolatedAsync(
        $"""
         INSERT INTO processed_messages (event_id, consumer, processed_at)
         VALUES ({meta.EventId}, {"billing.order-placed"}, {DateTimeOffset.UtcNow})
         ON CONFLICT DO NOTHING
         """, ct);
    if (inserted == 0) return;                       // duplicate: already applied, just acknowledge

    db.Invoices.Add(Invoice.CreateFor(evt));          // the business effect, same transaction
    await db.SaveChangesAsync(ct);
    await tx.CommitAsync(ct);
}
```

3. **Version guard for out-of-order updates:** carry an aggregate `version` or `occurredAt` and apply only if newer: `UPDATE customers SET address = @a, version = @v WHERE id = @id AND version < @v`.

External side effects (card charge, email, SMS) cannot join your database transaction. Send the provider an **idempotency key** derived from `EventId`; if the provider has none, record "intent" in your database first and run the effect from an outbox-style worker, so the retry path is under your control.

Purge `processed_messages` after the broker's maximum redelivery window plus a safety margin.

## 3. Retries and dead-lettering

Classify failures before choosing a policy:

| Failure | Examples | Action |
|---|---|---|
| Transient | Timeout, deadlock, 503, broker blip | Retry in-process 2 to 3 times with exponential backoff and jitter |
| Longer outage | Downstream down for minutes | Delayed retry (Service Bus scheduled redelivery or delivery count, RabbitMQ DLX + TTL, Kafka retry topics) |
| Permanent | Deserialization failure, validation error, unknown event version | Dead-letter immediately; retrying cannot help |
| Exhausted | Retries used up | Dead-letter with context |

```csharp
var pipeline = new ResiliencePipelineBuilder()
    .AddRetry(new RetryStrategyOptions
    {
        MaxRetryAttempts = 3,
        BackoffType = DelayBackoffType.Exponential,
        Delay = TimeSpan.FromMilliseconds(200),
        UseJitter = true,
        ShouldHandle = new PredicateBuilder().Handle<TransientException>().Handle<TimeoutException>(),
    })
    .Build();
```

A dead-lettered message must carry: original topic/queue, partition and offset (or message id), exception type and message, attempt count, first-failure time, consumer name. Without that, nobody can triage it.

- Kafka has no built-in DLQ. Publish to `<topic>.dlt` (or a parking-lot topic), **then** advance the offset; otherwise the partition is blocked.
- Alert when dead-letter depth is above zero. A DLQ nobody watches is a silent data-loss channel.
- Build or adopt replay tooling: inspect, fix, republish to the original destination. Replays rely on idempotent consumers.
- Ordered streams: delayed retries reorder events for that key. Either block the key (stop the partition, page someone) or make consumers tolerate reordering with version guards.

## 4. Ordering and concurrency

- Order exists only within a key: a Kafka partition, a Service Bus session, a RabbitMQ single-active-consumer queue or consistent-hash shard.
- Consumer instances beyond the partition count sit idle; size partitions for the maximum parallelism you will want.
- Inside one process, parallelise across keys but process sequentially per key: hash the key to one of N bounded `Channel<T>` workers.
- Bound everything: prefetch, max concurrent calls, channel capacity. Unbounded buffers turn a slow dependency into an out-of-memory crash.
- Handler duration must stay below the broker's liveness window (Kafka `max.poll.interval.ms`, Service Bus lock duration, RabbitMQ consumer timeout). Long jobs belong to a worker that the handler merely enqueues.

## 5. Sagas (multi-service workflows)

| Situation | Choose |
|---|---|
| 3 steps or fewer, few participants, no branching | **Choreography**: each service reacts to the previous event |
| More steps, branching, timeouts, compensation, a need to ask "where is order 123 right now?" | **Orchestration**: one process manager holds state and issues commands |

Implementation options for orchestration: framework sagas (NServiceBus, MassTransit, Wolverine), a durable execution engine (Temporal, Durable Task Framework / Durable Functions), or a hand-rolled process-manager table `(correlation_id, state, deadline, data)` driven by events and timeout messages.

Rules:

- Every step has a defined compensation: an idempotent action that semantically reverses it (refund, release stock). Some steps cannot be undone (email sent); order them last.
- Model timeouts as events or scheduled messages, not as sleeping threads.
- Expose intermediate states (`PaymentPending`, `Cancelling`) so the UI and support can reason about in-flight work.
- Choreography beyond three hops becomes a hidden state machine spread across services. Switch to orchestration when you catch yourself drawing arrows on a whiteboard to explain it.

## 6. Eventual consistency at the API edge

The write side commits instantly; read models update shortly after. Design the API so that gap is honest:

- Command endpoints return `202 Accepted` (or `201`) with the resource id, a `Location` link and the current state (`"Pending"`).
- Provide `GET /orders/{id}` that reads from the **write side** for the creator, so they see their own order immediately.
- Return a version or `ETag`; list endpoints can accept `If-Match`-style minimum-version hints, and fall back to a "still updating" flag.
- Push completion to clients with SignalR or Server-Sent Events, or let them poll the status resource with a sensible `Retry-After`.
- Never block an HTTP request waiting for a downstream event. If a short wait is essential for UX, bound it (a second or two), time out, and return `202`.

## 7. Read models and projections

- A projection consumer upserts denormalised rows keyed by entity id; it must be idempotent and version-guarded.
- Rebuild by resetting the consumer group's offsets (or re-reading from a replay topic) into a new table and swapping when caught up.
- Event sourcing (state derived from the event log) is a separate, heavier decision. Use it when history and audit are the product. For most services, normal state plus an outbox is simpler and enough.

## 8. Calling synchronous APIs from consumers

- Wrap calls in resilience: timeout, retry with jitter, circuit breaker; pass an idempotency key.
- A consumer that must call another service for every event is a smell: replicate the needed data locally via events instead.
- Turn inbound HTTP into events by writing state + outbox and returning `202`, not by publishing straight from the controller.

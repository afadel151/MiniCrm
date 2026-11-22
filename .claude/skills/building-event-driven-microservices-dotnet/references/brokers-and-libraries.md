# Brokers and libraries

Code below was written without compiling or running it. Treat signatures as [Likely] and confirm against current package docs.

## 1. Choosing a broker

| Need | Lean toward | Why / caveat |
|---|---|---|
| Replay, reprocessing, rebuilding read models from history, very high throughput, stream processing | **Kafka** (or a Kafka-compatible service) | Durable log, per-partition order, consumer groups. No per-message ack or native DLQ; you build a parking-lot topic. Heavier to operate. |
| Task-style work queues, flexible routing (topic/headers exchanges), per-message ack, modest volume | **RabbitMQ** | Dead-letter exchanges, quorum queues, streams for replay. Ordering weakens with competing consumers and requeues. |
| Already on Azure, want managed ops, built-in DLQ, sessions for ordered processing, scheduled delivery, duplicate detection | **Azure Service Bus** | Azure-only; local dev through an emulator (confirm current status). Lock duration and max delivery count shape retry behaviour. |
| On AWS | SNS + SQS (fan-out + queues), or MSK/Kinesis for log semantics | Same patterns; different settings names. |
| Lightweight, cloud-agnostic, simple ops | NATS JetStream | Smaller .NET ecosystem; confirm library maturity. |

Heuristic: pick the log (Kafka) only when replay or history is a real requirement. A few hundred messages a minute with no replay need is better served by Service Bus or RabbitMQ.

## 2. Raw client vs framework

| Option | Licence / status (verify before recommending) | Strengths | Watch out for |
|---|---|---|---|
| Raw clients: Confluent.Kafka, RabbitMQ.Client, Azure.Messaging.ServiceBus | Open source / Microsoft | Full control, no abstraction leaks, transparent behaviour | You write outbox, retries, DLQ, saga plumbing yourself |
| **MassTransit** | v8 Apache-2.0, official maintenance announced to end after 2026; v9 announced as commercial (public announcement, April 2025) | Mature sagas, outbox, many transports | New projects must budget for v9 licensing or accept v8 end-of-maintenance; check current state |
| **Wolverine** | Open source (MIT) [Likely] | Built-in durable outbox/inbox with EF Core/Marten, several transports, low ceremony | Newer, smaller community; conventions differ from MediatR-style code |
| **NServiceBus** | Commercial | Very mature sagas, outbox, tooling | Cost; broader transport support depends on tier |
| **Rebus** | Open source (MIT) [Likely] | Simple, small API | Fewer built-in advanced features |
| **Brighter** | Open source (MIT) [Likely] | Command-processor style, outbox support | Smaller ecosystem |
| **CAP (DotNetCore.CAP)** | Open source [Likely] | Outbox-centric, multi-broker | Opinionated storage schema |
| **Dapr pub/sub** | Open source | Polyglot sidecar, broker abstraction | Extra moving part; lowest common denominator features |
| MediatR | Moved to commercial licensing | In-process only | It is not a message broker client; do not use it as the integration layer |

Decision guide:

- Licence-averse and wants batteries included: Wolverine, or raw clients plus a hand-built outbox.
- Needs rich sagas and has budget: NServiceBus, or MassTransit with the licence cost understood.
- Kafka-centred stream processing: raw Confluent.Kafka for the consume/produce loop; add a framework only for outbox/saga plumbing.
- Small team that wants fewer concepts: a framework beats raw clients, because redelivery, serialization and tracing are already solved.

Whatever is chosen, keep broker types out of domain and handler logic. Handlers take a plain contract record and a small `EventMeta`; adapters translate. That keeps a later library swap local to `Infrastructure`.

## 3. Minimal raw-client consumers (at-least-once)

### Kafka (Confluent.Kafka)

```csharp
public sealed class PaymentsConsumer(
    IServiceScopeFactory scopes, IOptions<KafkaOptions> opts, ILogger<PaymentsConsumer> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await Task.Yield(); // Consume() blocks; do not hold up host startup

        var cfg = new ConsumerConfig
        {
            BootstrapServers = opts.Value.BootstrapServers,
            GroupId = "billing.order-placed",
            EnableAutoCommit = true,           // background commit...
            EnableAutoOffsetStore = false,     // ...but only of offsets WE store after processing
            AutoOffsetReset = AutoOffsetReset.Earliest,
            PartitionAssignmentStrategy = PartitionAssignmentStrategy.CooperativeSticky,
        };

        using var consumer = new ConsumerBuilder<string, byte[]>(cfg).Build();
        consumer.Subscribe("orders.order-placed.v1");
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var result = consumer.Consume(ct);
                await using var scope = scopes.CreateAsyncScope();
                var handler = scope.ServiceProvider.GetRequiredService<IEventDispatcher>();

                // Retries and parking-lot publishing happen inside; this only throws when we must NOT advance.
                await handler.DispatchAsync(result.Message.Key, result.Message.Value, result.Message.Headers, ct);

                consumer.StoreOffset(result);  // now eligible for auto-commit
            }
        }
        catch (OperationCanceledException) { /* shutting down */ }
        finally { consumer.Close(); }          // commits stored offsets, leaves the group cleanly
    }
}
```

Producer settings that matter: `Acks = Acks.All`, `EnableIdempotence = true`, a finite `MessageTimeoutMs`, and always set the message key. Await `ProduceAsync` (or handle delivery reports) so failures surface.

### Azure Service Bus

```csharp
var processor = client.CreateProcessor("orders", "billing", new ServiceBusProcessorOptions
{
    AutoCompleteMessages = false,                       // complete only after durable success
    MaxConcurrentCalls = 8,
    PrefetchCount = 32,
    MaxAutoLockRenewalDuration = TimeSpan.FromMinutes(5),
});

processor.ProcessMessageAsync += async args =>
{
    await dispatcher.DispatchAsync(args.Message, args.CancellationToken);
    await args.CompleteMessageAsync(args.Message, args.CancellationToken);
    // An unhandled exception abandons the message; after MaxDeliveryCount it moves to the dead-letter sub-queue.
};
processor.ProcessErrorAsync += args => { log.LogError(args.Exception, "SB error {Source}", args.ErrorSource); return Task.CompletedTask; };
await processor.StartProcessingAsync(ct);
```

For strict per-aggregate order, enable sessions on the entity and use a session processor with `SessionId = aggregateId`. For permanent failures call `DeadLetterMessageAsync` with a reason instead of letting it burn through delivery attempts.

### RabbitMQ (RabbitMQ.Client 7.x, async API)

```csharp
await using var conn = await factory.CreateConnectionAsync(ct);
await using var ch = await conn.CreateChannelAsync(cancellationToken: ct);
await ch.BasicQosAsync(prefetchSize: 0, prefetchCount: 20, global: false, ct);

var consumer = new AsyncEventingBasicConsumer(ch);
consumer.ReceivedAsync += async (_, ea) =>
{
    try
    {
        await dispatcher.DispatchAsync(ea.BasicProperties, ea.Body, ct);
        await ch.BasicAckAsync(ea.DeliveryTag, multiple: false, ct);
    }
    catch (Exception)
    {
        // requeue:false sends it to the queue's dead-letter exchange if one is configured
        await ch.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: false, ct);
    }
};
await ch.BasicConsumeAsync("billing.order-placed", autoAck: false, consumer, ct);
```

Declare the queue with a dead-letter exchange and (for quorum queues) a delivery limit; use publisher confirms on the producing side. Requeue-on-failure loops forever on a poison message, so do not requeue blindly.

## 4. Provisioning

Create topics, queues, subscriptions and DLQs through infrastructure-as-code, not by auto-creation at runtime in production. Auto-created topics get default partition counts and retention that are hard to change later, and partition count caps consumer parallelism.

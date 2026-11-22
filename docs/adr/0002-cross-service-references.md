# ADR-0002: Cross-service references are opaque ids, never foreign keys

- Status: **Proposed** (Phase 2 gate)
- Context: V1 Spec §4 was written for one database: tenant tables `FK businesses`, `contact_phones FK
  phone_identities`, `orders FK contacts`, etc. Tech Decisions v0.2 §2.4 (higher precedence) and CLAUDE.md §3
  require database-per-service, no cross-database queries, no FK to another service.
- Options: (a) keep spec FKs inside one shared DB; (b) opaque ids + event-fed read models; (c) opaque ids +
  synchronous validation on every write.
- Decision: **(b)**. Any column pointing at another service's entity is a plain `uuid` documented with
  `COMMENT ON COLUMN ... 'opaque ref: <service>.<table>'`. Values are validated by the writer from its local read
  model (or one gRPC call with deadline + fallback where freshness matters, max one hop). FKs remain **inside**
  a service (e.g. `order_items → orders`).
  Specific consequences of the spec mapping:
  - `contact_phones.phone_identity_id` (spec) → `contact_phones.phone_hash bytea` in crm; scoring resolves the
    hash to its own `phone_identities`. Raw phones never leave crm/orders (CLAUDE.md §5).
  - Every service keeps `app.tenants` (from `identity.business.*`) to refuse writes for suspended tenants,
    with **no FK** to it (events are asynchronous; a missing row must not block a write).
  - Orders keeps a contact snapshot on the order (name, phone, address at order time) — also legally the right
    thing: the order must show what was confirmed even if the contact changes later.
- Consequences: no referential integrity across services → orphan detection becomes a reconciliation job per
  read model; projections must be rebuildable (CLAUDE.md §4). Accepted trade-off for independent deployability.
- Revisit when: two services need the same entity transactionally (merge smell, v0.2 §2.6).

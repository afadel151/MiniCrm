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
    hash to its own `phone_identities`.
  - Every service keeps `app.tenants` (from `identity.business.*`) to refuse writes for suspended tenants,
    with **no FK** to it (events are asynchronous; a missing row must not block a write).
  - Orders keeps a contact snapshot on the order (name, phone, address at order time) — also legally the right
    thing: the order must show what was confirmed even if the contact changes later.
- Consequences: no referential integrity across services → orphan detection becomes a reconciliation job per
  read model; projections must be rebuildable (CLAUDE.md §4). Accepted trade-off for independent deployability.
- Revisit when: two services need the same entity transactionally (merge smell, v0.2 §2.6).

**Amendment, 2026-11-24 (Phase 1b review, product lead approved):** the original text said "raw phones never
leave crm/orders," following Tech Decisions v0.2 §2.4's three-service pepper list (crm, orders, scoring).
Phase 2's own already-built schemas (`identity-access.md` D7, `messaging.md` D6 — both written before this
ADR's Phase 1b review) correctly identified two more services with a real, unavoidable need for the raw phone
and the pepper-derived hash, not an oversight to fix:
- **identity-access** (`client_profiles.phone_raw/phone_e164/phone_hash`): OTP phone-owner self-view (CLAUDE.md
  §5 "phone-owner rights") requires proving the caller holds a phone matching scoring's hash — the raw number
  is needed to send the OTP itself, and the hash to prove the match.
- **messaging** (`conversations.phone_raw/phone_e164/phone_hash`): routing an inbound WhatsApp webhook to the
  right thread requires hashing the provider's raw E.164 *before* any thread is known — `channel_consent_states`
  does **not** need this (it receives an already-hashed phone via `scoring.consent.changed`); only inbound
  routing does.

Decision widened: **five services** read the pepper (crm, orders, scoring, identity-access, messaging), each
computing `phone_hash` independently with the same algorithm (HMAC-SHA256, pepper from the secret store, never
logged). Each additionally stores the raw phone only where its own job requires sending to or displaying it
(OTP delivery; WhatsApp message display/addressing) — never as a convenience copy. This is a wider blast radius
for the pepper than the original three-service trade-off accepted, consciously re-accepted here rather than
building a gRPC hash-resolver service for two rare, non-hot-path lookups (OTP challenge, inbound webhook
routing) that don't need the freshness or volume gRPC exists for (Tech Decisions v0.2 §3.1 rule 1: gRPC is for
queries that must be fresh — a phone's hash never changes). Every `phone_hash` column across all five services
must carry a `pepper_version`/`key_version` column (S16, already true in scoring; crm/orders/identity-
access/messaging's existing columns need the same before pepper rotation is attempted) so rotation doesn't
silently break five independently-deployed hash computations at once.
- Revisit when: a sixth service needs the pepper (re-run this same cost/benefit, strongly consider the
  gRPC-resolver alternative at that point); or when spike R1 (legal review) constrains how many services may
  hold phone-identifying secrets.

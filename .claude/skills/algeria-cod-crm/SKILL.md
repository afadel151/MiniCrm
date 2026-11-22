---
name: algeria-cod-crm
description: Expert guidance for building the cash-on-delivery (COD) layer of a CRM or e-commerce back-office for the Algerian market - order lifecycle, call-center confirmation, wilaya/commune addressing, home vs stop-desk delivery, carrier integration (Yalidine, ZR Express, Maystro, Procolis, Ecotrack-based carriers), cash remittance reconciliation, return-rate reduction and fraud control. Use this skill whenever the user builds or modifies a CRM, order system, delivery module, confirmation workflow, or reporting for Algerian merchants, or mentions COD, paiement a la livraison, wilaya, livreur, retour de colis, confirmation d'appel, or Algerian delivery companies - even if they never say "COD" explicitly.
---

# Algeria COD CRM

COD is the default payment method for Algerian e-commerce. The business is not
"take an order, ship it". It is a cash-collection pipeline where money is only
real after a courier hands over the parcel and the carrier remits the cash.
Every design decision below follows from that.

> Source note: this skill was drafted from general knowledge of the Algerian COD
> ecosystem. It was NOT verified against the egrow.com article
> "best-cod-software-algeria-2026". Items marked `[VERIFY]` (fees, carrier
> names, API details, legal rules) must be checked against current carrier docs
> before they are hard-coded. Prefer configuration over constants for all of them.

## Core principles

1. **An order is not revenue until cash is reconciled.** Track money state separately from delivery state.
2. **Confirm before you ship.** The cheapest return is the one that never leaves the warehouse. A human or automated confirmation step sits between "new" and "ready to ship".
3. **Everything Algerian-specific is data, not code.** Wilayas, communes, carrier tariffs, remittance delays, and phone rules change. Store them in tables/config.
4. **Model carriers behind one interface.** Merchants switch or combine carriers often. Never leak one carrier's status vocabulary into the core domain.
5. **Return rate is the north-star metric.** Build for measuring and reducing it from day one.

## Workflow when asked to build or change a COD feature

1. Identify which stage it touches: capture -> confirmation -> fulfillment -> delivery -> cash -> return/exchange -> reporting.
2. Read the matching reference file (below) before writing code.
3. Check the feature against the invariants in "Non-negotiable invariants".
4. Add or update tests for the state transitions and money math it touches.
5. If a rule depends on a `[VERIFY]` item, put it in config with a clear name and a TODO, and tell the user.

## Reference files (read as needed)

| Need | Read |
|---|---|
| Order and money state machines, data model | `references/data-model.md` |
| Phone, wilaya, commune, address, language, currency rules | `references/algeria-specifics.md` |
| Confirmation call-center flow, scoring, anti-fraud, return-rate reduction | `references/confirmation-and-returns.md` |
| Carrier abstraction, webhooks/polling, status mapping, remittance reconciliation | `references/carriers-and-cash.md` |
| Phone normalization helper | `scripts/normalize_phone.py` |

## Non-negotiable invariants

- Delivery status and cash status are **separate fields** with separate transitions.
- Amounts are stored as **integer DZD** (no floats). Order total = items + delivery fee - discount; COD amount to collect is stored explicitly, not recomputed later.
- Every status change is **append-only logged** (who/what/when/source), including carrier webhooks and agent actions.
- Carrier webhooks and polling must be **idempotent** (same event twice = no double effect).
- A parcel cannot be created at a carrier unless the order is `confirmed` and has a valid wilaya + commune + normalized phone.
- Never delete orders or customers; soft-delete/flag. Blacklists and return history must survive.
- Customer-facing text supports **Arabic (RTL) and French**; do not assume one language.

## Output expectations

When you design or implement, state which stage of the pipeline you touched, which state transitions you added, and which `[VERIFY]` assumptions you made. Prefer small, testable units: a state-transition function, a carrier adapter, a reconciliation job.

## Anti-patterns to avoid

- One `status` column mixing "confirmed", "delivered", "paid", "returned".
- Hard-coding the 58 wilayas or a single carrier's fee table.
- Treating "delivered" as "paid".
- Sending every new order straight to the carrier with no confirmation.
- Letting agents edit address or phone without logging, which makes return analysis impossible.
- Free-text address as the only address field.

---
name: crm-service-support
description: Build the customer service side of a CRM: cases/tickets, queues and routing, priorities, SLA clocks, escalation, resolution codes, knowledge base, canned replies, omnichannel inbox (email, WhatsApp, SMS, chat, phone), self-service portal, CSAT, and service analytics. Use when the user wants a helpdesk, complaint handling, returns/after-sales handling, support inbox, SLA tracking or service dashboards inside or alongside a CRM.
---

# CRM Service & Support

Service is the most structured process in most organisations and the richest source of data about why customers are unhappy. Keeping it in the same system as sales and orders gives (a) agents full context, (b) smooth handoffs (a service interaction can reveal a sales lead, and a sale creates onboarding work), and (c) analytics linking issue categories to customer segments, products and carriers.

## Core model

- **Case** (ticket): subject, customer (contact/account), related order/product, category + subcategory (lookup), priority, status, queue, owner, SLA policy and due times, channel of origin, resolution code, satisfaction score.
- **Case events**: append-only timeline (customer message, agent reply, internal note, status change, assignment, SLA events). Customer-visible vs internal flag per entry.
- **Queues** with routing rules (skills, language, product, VIP tier, channel), capacity limits and overflow.
- **SLA policies** by priority/segment: first-response and resolution targets in business hours; clocks pause on "waiting for customer"; breach warnings at 75%/90%.
- **Resolution processes**: different categories need different steps (refund, replacement, technical troubleshooting, delivery issue, return pickup). Model each as a small state machine; support multiple processes per case type.

## Status lifecycle (default)

`new -> open -> pending_customer <-> open -> pending_internal -> resolved -> closed` with `reopened` allowed within N days. Every transition emits an event; `resolved` requires a resolution code; `closed` is automatic after N days of silence.

## Omnichannel inbox

- Normalise inbound messages from each channel into a `conversation` + `messages` pair keyed by contact point; thread into one open case per contact per topic window (configurable), never one case per message.
- Show channel history inline on the contact timeline. Reply from the same channel by default; respect channel windows and templates (e.g., WhatsApp Business API requires approved templates outside the 24-hour customer-service window; verify current provider rules before building).
- Keep deliverability states (sent, delivered, read, failed) and surface failures to the agent.
- Attachments: virus scan, size limits, signed URLs with expiry.

## Knowledge and deflection

- Knowledge base with versions, status (draft/review/published), tags, language variants, and usage stats (views, "solved my problem" votes, links to cases).
- Suggest articles to agents while they type (search by subject/body), and to customers in the portal before they open a case.
- Canned replies/macros with variables and permission control; track usage and CSAT impact.

## Self-service portal

Customers log in (or use magic link) to create/update/view cases, track orders, download documents. Rate-limit, protect against enumeration, show only customer-visible events. Self-service reduces cost-to-serve, which feeds customer profitability (see `crm-customer-intelligence`).

## Escalation and handoffs

- Escalation triggers: SLA breach/imminent, priority upgrade, VIP/MVC customer, repeated contact (3rd contact on the same issue), negative sentiment, legal keywords, refund above threshold. Implement as rules (see `crm-workflow-automation`).
- Handoff to sales: a "sales opportunity spotted" action creates a lead/opportunity linked to the case and notifies the account owner.
- Handoff to operations (warehouse, carrier): create a task with structured data and track the reply, not a free-text email.

## Metrics (define precisely in `crm-reporting-kpis`)

First response time, resolution time, SLA attainment %, backlog age, reopen rate, first-contact resolution, contacts per order, CSAT/NPS/CES with response rate, deflection rate, cost per case, case volume by category x product x carrier x segment, agent productivity and quality scores (sampled reviews).

## Feedback loop to the business

Weekly: top 10 contact drivers with trend; for each, owner + action (fix listing, change packaging, retrain carrier, change policy). Without a named owner the data is decoration.

## UX priorities

One screen: customer context (360 summary, open orders, recent cases, risk/value tier, consent), timeline, composer with templates, next-best-action hints, keyboard shortcuts. Collision detection ("Sara is replying"). Bulk actions. Minimal clicks to resolve with code.

## Anti-patterns

- Closing cases to hit SLA numbers (track reopen rate and CSAT alongside).
- Free-text categories; no resolution codes.
- One person's inbox as the system of record. Everything flows through shared queues.
- Exposing internal notes to customers by default templates or API leaks. Test the visibility flag.

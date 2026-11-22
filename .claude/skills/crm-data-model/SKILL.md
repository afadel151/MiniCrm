---
name: crm-data-model
description: Design the CRM data model and database schema: accounts, contacts, leads, opportunities, activities, cases, products, quotes/orders, campaigns, custom fields, relationships, external IDs, soft delete, audit columns, dedupe and identity resolution. Use whenever the user asks for a CRM schema, ERD, entities, migrations, "how should I model customers", customer 360 / single customer view, duplicate customers, or custom fields in a CRM, even if they only say "customer table".
---

# CRM Data Model

The customer record is the centre; almost everything else hangs off it. Good models make three things easy: seeing the whole customer (360 view), reporting across departments, and changing fields without a developer.

## Modelling rules

1. **Separate organisations from people.** `accounts` (companies, households, or for B2C the "customer" itself) and `contacts` (individuals). For pure B2C you may collapse to one `customers` table, but keep a `person` abstraction so household/company can be added later. Link them many-to-many through a relationship table with a role (decision maker, billing, user, parent company).
2. **Prospects are not customers.** Keep leads/suspects separate from accounts until qualified; marketing needs to work on people who are not yet customers. Conversion creates/links account + contact + opportunity and never deletes the lead (keep for attribution).
3. **One timeline.** Calls, emails, WhatsApp messages, meetings, notes, status changes and system events all land in `activities` (polymorphic: `subject_type`, `subject_id`) so any record can show a complete history.
4. **Extensible without code.** Give each core entity a `custom` JSONB column plus a `custom_field_defs` registry (entity, key, type, label, picklist values, required?, visibility). Validate against the registry in the service layer. Index hot custom fields explicitly; promote a custom field to a real column when it becomes central to reporting.
5. **Picklists are data.** Stages, statuses, reasons, sources, lost-reasons, return-reasons live in lookup tables (`lookup_values`) with stable codes, labels per language, active flag and sort order. Never store the label as the key; never hard-code in the UI. Store *reason codes* for outcomes (lost, returned, cancelled, churned) because those drive the most valuable reports.
6. **Stable IDs and external IDs.** Use UUIDs (or ULIDs) internally. Store each external system's ID in `external_ids(entity, entity_id, system, external_id)`; this is the crosswalk that makes integrations and migrations re-runnable.
7. **Provenance.** Record where each person/lead came from (`source`, `source_detail`, `captured_at`, `captured_by`, consent text/version). The Handbook notes how few firms store the source of customer data; it is cheap to do now and painful later.
8. **History where it matters.** Keep stage history (`opportunity_stage_history`), owner history, and an append-only `audit_log` (who, when, entity, field, old, new). Reports on conversion time and velocity depend on it.
9. **Soft delete + merge.** Use `deleted_at` and a `merged_into_id` for duplicates. Hard delete only for privacy erasure workflows (see `crm-security-privacy`).
10. **Multi-tenant from the start** if there is any chance of more than one company using it: `tenant_id` on every table, composite uniqueness including it, and row-level security (RLS) in the database.
11. **Normalise contact points.** Phones and emails in their own tables (`contact_points`: type, value_normalized, value_raw, is_primary, verified_at, status). Phones: store E.164 and country. Track `bounced`/`invalid`/`wrong_number` states; they feed data-quality KPIs and avoid wasted outreach.
12. **Money and time.** Amounts as integer minor units + ISO currency code; store UTC timestamps plus the user's/record's timezone where scheduling matters; keep a `fx_rates` table if multi-currency.

## Core entities (see `references/schema.sql` for a PostgreSQL reference)

| Group | Tables |
|---|---|
| Identity | tenants, users, roles, permissions, teams, territories |
| Customers | accounts, contacts, account_contacts, contact_points, addresses, external_ids |
| Prospecting | leads, lead_sources, campaigns, campaign_members |
| Sales | pipelines, stages, opportunities, opportunity_stage_history, products, price_books, quotes, quote_lines, orders, order_lines |
| Service | cases, case_events, queues, sla_policies, kb_articles |
| Cross-cutting | activities, tasks, notes, attachments, tags, custom_field_defs, lookup_values, consents, audit_log, outbox_events, workflow_rules |

## Identity resolution (dedupe)

Duplicates are the first thing that makes users distrust a CRM. Implement at *write time* and as a *periodic job*; read `references/identity-resolution.md` for matching keys, scoring and merge rules. Principle: deterministic keys first (normalised phone/email/external ID), fuzzy scoring second, human review for the grey zone, reversible merges.

## Validation without "11/11/11" data

Mandatory fields force operators to invent values (the Handbook tells of ~10% of a bank's customers born on 11/11/11). So: require only what the next process step needs; allow `unknown` explicitly; validate formats (phone, email, address) instead of requiring presence; show a *completeness score* on the record to encourage enrichment.

## Customer 360 read model

Don't join twenty tables on every page load. Build a `customer_360` read model (materialised view or projection table fed by domain events) with: identity, contact points, owner, lifecycle stage, open opportunities/cases, last interaction date and channel, order count/revenue/AOV, return/refusal counts, risk tier, consent status, and key flags. This projection also serves lists, filters and scoring.

## Output checklist when asked for a schema

- ERD (Mermaid is fine) + DDL + indexes (tenant_id first in composite indexes; partial indexes for `deleted_at IS NULL`; trigram/GIN on names; unique on normalised contact points per tenant).
- Seed lookups (stages, sources, reasons) and an example custom field.
- A data dictionary: field, meaning, owner, source, required-when, used-by-report.
- Migration scripts that are reversible; no destructive changes without a backfill plan.

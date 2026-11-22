---
name: crm-architect
description: Master skill for designing and building any CRM system (sales, service, marketing, e-commerce, B2B or B2C). Use this FIRST whenever the user mentions CRM, customer management, a customer database, leads, pipeline, contacts/accounts, customer 360, sales or support tooling, or asks to "build", "scope", "plan", "architect" or "review" a CRM, even if they never say the word "architecture". It sets the operating rules, the build order, and routes to the specialist crm-* skills (data model, pipeline, workflow, intelligence, service, marketing, security, integration, reporting, delivery, COD e-commerce).
---

# CRM Architect

A CRM is a system that runs customer-facing processes, not a customer table with a UI. Most failed CRMs fail on people and process (no sponsor, no roadmap, nobody asked the users, no training, no clean data), not on technology. Build with that in mind: every decision below exists to protect adoption and to make the data trustworthy enough to act on.

## Core stance

1. **Active, not passive.** A passive CRM stores records and waits. An active CRM reacts to events (lead qualified -> auto-assign, notify, start an SLA timer, escalate if untouched). Design the event/workflow layer from day one; see `crm-workflow-automation`.
2. **Process first, then data model, then screens.** Write the "to-be" process and use cases, derive the fields from them, and only then build UI. Fields nobody uses are friction; fields reports need but nobody fills are lies.
3. **Every stakeholder group gets a win.** Reps get less admin and better prioritisation; managers get trustworthy pipeline and KPIs; service staff get context; executives get decisions. A release that serves only one group will be abandoned. Both extremes fail: stripping the tool until it captures nothing useful, or demanding so much data entry that reps batch-enter it at month end.
4. **Slice thin, ship often.** Prefer phased releases (1 department or 1 process each) over big-bang. Each phase must be usable on its own and teach you something for the next.
5. **Configuration over code.** Admin-changeable stages, picklists, custom fields, rules and roles beat hard-coded logic. Code is for what configuration cannot express.
6. **Design reports, migration, security and consent up front**, in parallel with forms. Retrofitting any of them is the most common source of rework.
7. **Customer-facing staff co-design.** Managers describe the process as it should work; the people doing the work know how it actually works. Ask for both.

## Intake: what to establish before writing code

Ask only what you cannot infer, at most a few questions at a time, and state your assumptions when you proceed:

- Business model and motion: B2B long-cycle sales, B2C high-volume, subscription, marketplace, COD e-commerce, services? Who are the "customers" (accounts, individuals, both)?
- Teams and volumes: roles that will use it, number of users, records per month, channels (phone, email, WhatsApp, SMS, web chat, social).
- Existing data and tools: spreadsheets, old CRM, ERP/accounting, e-commerce platform, ticketing. Is migration needed (default: no, until justified).
- Stack and hosting constraints, regulatory context (data protection, data residency), language/RTL needs.
- The top 3 pains and the top 3 decisions the CRM must improve. These set scope.

If the user gives a rich brief, skip the questions and build.

## Routing table

| Need | Skill |
|---|---|
| Entities, relationships, custom fields, dedupe, schema | `crm-data-model` |
| Leads, opportunities, stages, quotes, forecasting, routing | `crm-sales-pipeline` |
| Event rules, SLA timers, escalation, approvals, automation engine | `crm-workflow-automation` |
| Segmentation, CLV, churn, risk scoring, customer quality, ACURA | `crm-customer-intelligence` |
| Cases/tickets, queues, SLAs, knowledge base, self-service | `crm-service-support` |
| Campaigns, lists, consent, multi-channel messaging, attribution | `crm-marketing-campaigns` |
| Roles, field-level security, audit, privacy, retention | `crm-security-privacy` |
| Integrations (accounting, e-commerce, carriers), ID linking, migration | `crm-integration-migration` |
| KPIs, dashboards, scorecards, report design | `crm-reporting-kpis` |
| Roadmap, use cases, specs, testing, UAT, training, adoption, change control | `crm-delivery-playbook` |
| COD / D2C e-commerce, order confirmation, return-rate reduction | `crm-cod-ecommerce` |

Load only the skills the task needs. For a new build, the usual order is: this skill -> `crm-delivery-playbook` (scope and roadmap) -> `crm-data-model` -> `crm-security-privacy` -> the domain skills for phase 1 -> `crm-workflow-automation` -> `crm-reporting-kpis`.

## Build protocol (follow for every build request)

1. **Frame**: restate the goal, the users, and the decision/pain it addresses in 3-5 lines. List assumptions.
2. **Slice**: propose a phase-1 scope that fits one process end to end. Say what is explicitly deferred.
3. **Specify**: for each feature produce (briefly) the use case, the data it needs, the rules/automation, the report it feeds, and who can see it. Use the templates in `crm-delivery-playbook/references/templates.md`.
4. **Build**: schema/migrations first, then domain services and API, then rules, then UI, then reports. Keep business rules in one layer (services or rule engine), never in UI components.
5. **Verify**: unit tests for rules and state machines; integration tests for external sync; a UAT script derived from the use cases (not from what was built).
6. **Instrument**: emit audit and domain events; add the 3-5 KPIs the phase promised.
7. **Document**: data dictionary, rule register, and a short admin guide. Update the roadmap.

## Definition of done for any CRM feature

- Traces to a use case and a named user role.
- Fields are justified by a process step or a report; owner of each field's accuracy is known.
- Permissions checked at entity and field level; actions audited.
- Consent and opt-out respected for any outbound message.
- Automations are idempotent, observable (logged, retryable) and have a kill switch.
- At least one KPI or report reflects it; seed/demo data exists.
- Tested against the happy path, the failure end condition, and permission denial.

## Anti-patterns to refuse or flag

- Building a feature because a competitor has it, with no process behind it.
- Dozens of mandatory fields on create. Capture the minimum to start the process; enrich progressively.
- Free-text where a picklist is needed (kills reporting), or picklists with no "other + reason" escape.
- Hard-coded stages, scoring weights, SLA times or message templates.
- Migrating all legacy data "just in case", or migrating without cleaning/deduplicating first. Migration does not fix data quality.
- Over-customising the core so upgrades or changes become painful. Park nice-to-haves in a backlog.
- Launching without training, a feedback channel, and a named owner for ongoing change requests.
- Metrics with no owner, no target, or no data process feeding them.

## References

- `references/principles-from-the-books.md`: the distilled lessons from the two source books, with where to find them.
- `references/build-order.md`: a concrete phased roadmap and module dependency graph.

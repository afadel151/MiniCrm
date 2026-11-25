# ADR-0007: Homes for marketing, service desk, workflow automation and reporting (G7)

- Status: **Proposed** (Phase 1 gate)
- Context: CLAUDE.md §6 marked four CRM-Fundamentals areas "Not in v0.2 — Phase 1 must assign":
  marketing (segments/campaigns), service (cases/tickets/SLA), workflow automation (triggers/conditions/
  actions), reporting (dashboards/KPIs). `docs/00-context/gap-analysis.md` G7 flagged this as open, due
  "before M3." M3 (scoring) is already built (Phase 2 ran ahead of Phase 1 on explicit product-lead direction,
  G11), so this decision is overdue relative to the original schedule.
- Decision:

  | Area | Home | Why |
  |---|---|---|
  | Marketing — segments/lists | **crm** | A segment is a saved query over contacts/tags/score cache, all crm-owned fields; no new aggregate |
  | Marketing — campaigns, sends, attribution | **messaging** | messaging already owns templates, channel consent and the only send mechanism (`messaging.md` D1 already pulled WhatsApp templates in from integrations for the same reason); a campaign is "send this template to this segment" |
  | Service / support desk | **crm** | Cases are structurally an opportunity-shaped aggregate (stages, assignee, SLA) sharing crm's interaction timeline; a separate service would split contact/interaction ownership for no consistency benefit — exactly the merge-smell ADR-0002 and Tech Decisions v0.2 §2.6 warn against |
  | Workflow automation | **new context, not built in Phase 2** | The one area with no natural existing owner: reacts to any event from any service. Matches v0.2 §2.2's own stated trigger for a new service ("when two or more services need the same capability at runtime"). Deferred past M5 until there is event volume worth automating against |
  | Reporting | **no new service** — per-service read replica + materialised views now, CDC-fed columnar store later | CLAUDE.md §4's "don't report off OLTP primaries" is an infra pattern, not a bounded context. Single-service KPIs live on that service's own replica; cross-service KPIs get a purpose-built materialised view owned by whichever service can cheapest maintain it from events it already consumes |

- Consequences: no 8th/9th service added in V1; `crm` and `messaging` each gain scope they don't yet have
  schema for (cases, campaigns) — tracked as future Phase 2 work for those two services, not retrofitted into
  the schemas already built and validated. A genuinely new "automation" service is accepted as likely post-M5,
  consistent with the "services arrive with their milestone" rule.
- Revisit when: automation's event volume or marketing's campaign complexity make crm/messaging's "one more
  aggregate" answer strained (the same tripwire test as any other service split — Tech Decisions v0.2 §14.2);
  or when cross-service reporting queries start measurably loading an OLTP primary, triggering the CDC/columnar
  step early.

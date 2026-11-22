# Build order and module dependencies

## Dependency graph (build left to right)

```
Identity & security -> Core data model -> Activities/timeline -> Pipeline (sales) --\
        |                    |                                  Cases (service)  ---+-> Workflow engine -> Reporting
        |                    +-> Consent & channels -> Campaigns/messaging --------/
        +-> Audit log                      Integrations / migration (design from day 1, ship when needed)
```

## Suggested roadmap (adapt; each phase must ship value to every user group it touches)

**Phase 0: Discovery (days, not weeks).** Intake questions, as-is process notes, top pains, 3-5 KPIs to move, sponsor and champions named, tech/stack decision, data inventory. Output: one-page charter + phase-1 scope + risks.

**Phase 1: Foundation + one process.** Auth, roles, audit; accounts/contacts (+ dedupe); activity timeline; ONE pipeline or ONE service flow end to end; list views, search, filters; 3-5 KPIs; import tool (CSV) rather than full migration. Exit criteria: users can run a normal day in it; managers trust the pipeline/ticket report.

**Phase 2: Make it active.** Workflow engine (assignment, SLA timers, reminders, escalations), email/WhatsApp/SMS templates with consent checks, tasks and notifications, first integration (the one that removes the most re-keying).

**Phase 3: Insight.** Segmentation, CLV estimate, risk/quality scoring, churn flags, dashboards by role, forecast, cohort and funnel reports.

**Phase 4: Reach and scale.** Campaigns and attribution, self-service portal, more integrations, multi-channel inbox, data-quality jobs, performance tuning, advanced permissions.

**Continuous.** Steering review monthly, change-control backlog, training refreshers, adoption dashboard (logins, record completeness, stale opportunities).

## Slicing heuristics

- Prefer vertical slices (UI + API + data + report for one use case) over horizontal layers.
- If a phase cannot be explained as "X team can now do Y without Z", it is not a phase.
- Postpone: custom dashboards builders, mobile offline, AI features that need data you do not yet have, multi-currency/multi-language beyond what the first market requires.
- Never postpone: permissions model, audit trail, consent flags, unique IDs for external links, soft delete.

---
name: crm-sales-pipeline
description: Build the sales side of a CRM: leads, qualification, lead routing/assignment, opportunities, pipeline stages and exit criteria, sales methodology, quotes, forecasting, win/loss analysis, sales activity tracking, SFA (sales force automation) and sales dashboards. Use when the user wants a pipeline, Kanban deal board, lead scoring or assignment, forecast, quotes/proposals, or sales process automation in a CRM.
---

# CRM Sales Pipeline

Sales is where most CRMs start. The value is: managers see an honest pipeline, reps spend less time on admin and more on the next action, and marketing's spend can be tied to revenue.

## Design from the process

1. Write the **to-be sales process** in plain steps with the people and handoffs (marketing -> SDR -> AE -> onboarding). Ask the reps how it really works.
2. Define **stages as buyer-verified milestones**, not rep activities. Each stage has: name, definition, entry/exit criteria (what must be true and recorded), default win probability, typical duration, stuck-threshold in days.
3. Keep stages few (5-7 open stages is plenty). More stages = less data quality.
4. Capture only what the next stage needs. Example exit criteria: Qualified requires need + budget range + decision maker identified + next step date; Negotiation requires a quote sent.
5. Separate **lead** (unqualified interest) from **opportunity** (qualified, has amount and expected close). Conversion is an explicit action that carries over source, campaign, notes and activity history.

## Reference stage set (adapt)

| Stage | Exit criteria (examples) | Prob. | Stuck if > |
|---|---|---|---|
| New | contact reachable | 5% | 2 d |
| Qualified | need, budget range, decision maker, next step | 20% | 7 d |
| Solution / Demo | demo done, stakeholders mapped | 40% | 14 d |
| Proposal | quote sent, validity date | 60% | 10 d |
| Negotiation | terms discussed, approver known | 80% | 10 d |
| Won / Lost | win reason or lost reason code (required) | 100/0 | - |

Probabilities are defaults; recalibrate from your own stage-to-win conversion once you have ~50+ closed deals.

## Lead handling

- **Capture**: forms, ads, WhatsApp/click-to-chat, imports, partner referrals; always store source/campaign/consent.
- **Speed matters**: auto-acknowledge instantly; assign within minutes; start an SLA timer (e.g., first touch within 15 min for hot leads). See `crm-workflow-automation`.
- **Routing**: round-robin, weighted by capacity, by territory, by language, by product line, by account ownership (existing customers go to the account owner). Keep routing rules in data; log why each lead went where. Include fallback pool and reassignment when owner is on leave or breaches SLA.
- **Scoring**: two scores: *fit* (who they are: segment, size, geography) and *intent* (what they did: replies, visits, requests). Start with a transparent rules-based points table, store the contributing reasons, review monthly against actual conversion; only then consider a model. Never hide scores behind opaque weights; reps stop trusting them.
- **Qualification**: record structured answers (need, budget, authority, timing or your methodology's equivalent) as fields, not free text.
- **Disqualification** needs a reason code; recycle to nurture rather than delete.

## Opportunity mechanics

- Stage change goes through a **service method** that enforces exit criteria, writes stage history, updates `closed_at`, emits `opportunity.stage_changed`, and recalculates forecast fields. UI cannot bypass it.
- Always keep **next step + due date** on open opportunities; list "no next step" and "overdue next step" as default views. This single habit prevents most pipeline rot.
- Weighted amount = amount x stage probability (or rep-adjusted override with audit). Forecast categories (commit / best case / pipeline) are optional; add only if the team forecasts that way.
- Products and price books -> quote lines. Quotes have versions, validity date, discount rules and approval thresholds (see approvals in `crm-workflow-automation`). Won quote -> order -> integration to accounting (see `crm-integration-migration`).
- Multiple contacts per opportunity with roles (champion, economic buyer, blocker).
- Competitor and loss data: a `competitors` lookup and lost-reason codes feed win/loss analysis.

## Forecasting

- Use snapshots: store a daily/weekly `pipeline_snapshots` table (opportunity, stage, amount, close date, prob). You cannot reconstruct "what we thought last month" from current data.
- Core reports: pipeline by stage, coverage ratio (open pipeline / target), conversion by stage, average cycle length, velocity (opps x win rate x avg deal / cycle), aging/stuck deals, win rate by source/segment/rep, slipped close dates, forecast accuracy (forecast vs actual).
- Define each metric precisely in the metric catalog (see `crm-reporting-kpis`); "forecasted revenue" is the textbook example of a metric that fails unless defined exactly.

## UX rules that drive adoption

- Kanban + list + "my day" view (tasks due, deals needing next step, new leads). One-click log call/email/WhatsApp; click-to-call/WhatsApp; email/calendar sync so reps do not double-enter.
- Inline edit, keyboard shortcuts, mobile-first for field reps. Defaults and auto-fill over typing.
- Show the rep their own benefit first (reminders, prioritised list), then the manager's reports.

## Anti-patterns

- Stage defined by "I did a demo" rather than by buyer commitment.
- Probability set by gut per deal with no audit.
- Requiring close amounts for leads, or forcing product line items at stage 1.
- Reps and managers using different spreadsheets "because the CRM is wrong". Treat that as a product bug, find why.

## Deliverables checklist

Stage definitions table; lead routing spec; scoring table with reasons; opportunity state machine (allowed transitions + guards); quote/approval rules; forecast snapshot job; the 8-10 sales KPIs with owners/targets; seed data and demo pipeline.

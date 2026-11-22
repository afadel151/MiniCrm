---
name: crm-reporting-kpis
description: Design CRM reports, dashboards, scorecards and KPIs: choosing metrics, defining them precisely, owners and targets, funnel/pipeline/service/marketing/retention metrics, snapshots, report design, role-based dashboards, data freshness, and ROI of the CRM itself. Use when the user asks for dashboards, KPIs, analytics, "what should we measure", forecasts, management reports, or reporting performance in a CRM.
---

# CRM Reporting and KPIs

Much of a CRM's value is realised through reports, and some employees (executives, analysts) get *only* that value. Reports also create the data-entry requirement, so design them early, with the process, not after the forms.

## Principles for good metrics (from *CRM Fundamentals* ch. 6)

A KPI should be:
1. **Specific**: a precise definition any reasonable person reads the same way. "Forecasted revenue" is the classic offender: write down which stages, which date field, weighted or not.
2. **Owned**: a named person/department is accountable for moving it. No owner = interesting trivia, not a KPI.
3. **Measurable**: a process and system actually capture it. If satisfaction is not collected, it is not a KPI yet.
4. **Timely**: available at the cadence of decisions; do not put monthly metrics on a weekly scorecard.
5. **Few**: a manageable handful per scorecard; people can only focus on so many. (One example in the book: a 50-page monthly book took 20 days to assemble and nobody read it.)
6. **Targeted**: each KPI has a target that is time-bound, controllable by the owner, respects seasonality, and is captured by an existing process.
7. **Aligned** with organisational goals (growth vs profitability produce different scorecards).

Good metrics = well-defined + aligned with goals + credible data.

## Process

1. List the **decisions** each role must make (reorder follow-ups, reassign leads, change a policy, spend budget).
2. Pick the minimum metrics that inform those decisions; write each into the **metric catalog** (`references/metric-catalog.md`): name, definition, formula, grain, source tables/fields, filters, owner, target, cadence, caveats.
3. Trace each metric to the **capture point** (which form/field/event, by whom, when). If nobody captures it, change the process or drop the metric.
4. Design the report (see below), prototype with real data, review with the owner.
5. Include reports in system and user acceptance testing; train users on the *meaning and source* of data, not just how to click.

## Scorecards by role (start here, 5-8 metrics each)

- **Rep / agent ("my day")**: tasks due, leads untouched, deals with no next step, cases near SLA, personal conversion vs target.
- **Team manager**: pipeline coverage, stage conversion and aging, activity vs outcomes, SLA attainment, backlog, forecast vs target, coaching list.
- **Marketing**: leads by source/campaign, cost per lead/acquisition, lead-to-opportunity and opportunity-to-won by source, revenue by campaign, list health.
- **Customer / retention owner**: active customers, retention/churn by segment and cohort, repeat rate, share of wallet/product density, CLV by segment, complaint rate, NPS/CSAT.
- **Executive**: revenue and margin, pipeline health, customer growth and value mix (MVC/STC/BZ), cost-to-serve, CRM adoption, ROI.
- **CRM program owner**: adoption (active users, record completeness, stale records), data quality, automation success/error rates, backlog of change requests.

Handbook ch. 6 lists customer metrics to draw on: acquisition and retention rates; satisfaction; CLV; experience within and across channels; complaints; segment/micro-segment profitability; share of wallet; product density; recommendation/advocacy; value gained through cross-sell and upsell. Also people/process metrics (employee performance, satisfaction, productivity, process efficiency) and strategic metrics. Use a balanced-scorecard view and linkage models (e.g., service-profit chain: employee satisfaction -> service quality -> customer satisfaction/loyalty -> profit) to explain *why* a metric should move.

## Report design rules

- One question per chart; title states the question or the answer ("Win rate fell in March").
- Show targets and trend/comparison; avoid unexplained gauges and 3D charts.
- Drill-through from every number to the underlying records (trust comes from clicking through).
- Filters by owner/team/period/segment/channel; saved views; schedule by email/WhatsApp if wanted.
- Respect the **security model** in every report, export and BI connection.
- Show data freshness ("updated 08:15") and definitions via tooltip/link to the catalog.
- Performance: pre-aggregate heavy metrics (materialised views / daily snapshot tables); keep operational queries off the hot path (replica); paginate and cap exports.

## Data foundations

- **Snapshots** for metrics that change state over time (pipeline, tiers, SLA backlog). Otherwise last month's numbers silently change.
- **Time handling**: define business calendar, timezone and fiscal periods once; use a date dimension.
- **Event/fact tables** (orders, interactions, stage changes, case events) + **dimensions** (customer, product, channel, owner, campaign, date). A star schema in a warehouse or views is enough at small scale.
- **Reason codes** everywhere outcomes occur (lost, returned, churned, cancelled) so reports can answer *why*.
- Data quality tests on metrics inputs (null rates, duplicates, impossible dates).

## Measuring CRM ROI (Handbook ch. 6)

Link CRM activity to business results with a baseline: conversion rate, cycle time, admin hours saved, retention, cost-to-serve, revenue per rep, returns avoided, campaign efficiency. Compare against pre-CRM data (one reason migrating history helps), attribute carefully, and separate one-off project cost from running cost. Present as a simple before/after with assumptions visible.

## Anti-patterns

- Vanity metrics (opens, logins) without outcomes; 50-metric dashboards; targets nobody controls.
- Metrics computed differently in different reports. Centralise definitions (views/semantic layer).
- Reports built on fields users are never asked to fill.
- Executive-only reporting that adds work for reps without giving them anything back.

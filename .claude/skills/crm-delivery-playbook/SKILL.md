---
name: crm-delivery-playbook
description: Plan and deliver a CRM project end to end: discovery, readiness and maturity assessment, roadmap and phasing, stakeholder and team roles, as-is/to-be process, use cases, functional and technical specifications, build vs buy, project charter, testing (unit, system, integration, performance, UAT), training, cutover, launch, adoption, change control, steering committee and post-launch evolution. Use when the user asks how to run, scope, plan, document, test, launch or roll out a CRM, or wants specs, use cases, a test plan, a roadmap or a training/adoption plan.
---

# CRM Delivery Playbook

Technology is rarely why CRM programs fail. People, process, expectations and pitfalls dominate (*CRM Fundamentals* ch. 2). Use this playbook to keep the build honest, even when the "team" is one developer and one business owner: the roles still need to exist.

## 1. Roles (can be combined in small teams)

Executive sponsor (sells the vision, holds people accountable, removes blockers) - steering committee (cross-department priorities) - project manager - subject-matter experts - IT representative - departmental champions (peers who test, train and advocate) - trainers - CRM admin team after launch: program lead, business analyst, administrator, developer, trainer. If there is no sponsor, stop and fix that first; the most common cause of CRM failure is weak sponsorship.

## 2. Readiness and maturity (Handbook ch. 7)

Quick audit before scoping: strategy and objectives clear? processes documented? data quality and sources? skills? investment? leadership? measurement? functional boundaries? Place the organisation on the maturity ladder (pre-CRM planning -> building a data repository -> moderately developed -> well developed -> highly advanced) and **aim one step up, not five**. Early stage = identification and data quality problems dominate (who are our customers?), so invest in clean identity and capture before advanced analytics. IT staff tend to rate maturity higher than marketing colleagues; ask both.

## 3. Roadmap (Fundamentals ch. 3)

1. Assess current processes and customer-info applications; find the pain; link to strategic goals; note technology issues and red flags.
2. Split the vision into projects (by department or process); line up people.
3. Use a **pilot / proof of concept** for the riskiest assumption.
4. Sequence by value, dependency and synergy; make sure each project gives every involved group some benefit.
5. Re-plan midstream as feedback arrives.
Prefer phased over big-bang: earlier value, lessons feed later phases, fewer moving parts. See `crm-architect/references/build-order.md`.

## 4. Build vs buy vs configure

Evaluate against: alignment with objectives, customisation flexibility, existing infrastructure, user experience, technology standards, vendor viability/ecosystem, cost (licensing, hosting, people). Deployment: on-premises, hosted, SaaS. Be honest about total cost of ownership of building: auth, permissions, audit, email/WhatsApp deliverability, reporting, admin UI, upgrades, support. Recommend building only where the process is a differentiator or constraints rule out products; otherwise extend an existing platform. If the user has decided to build, proceed; do not relitigate more than once.

## 5. Design stage artifacts (templates in `references/templates.md`)

- **As-is** process (how work really happens, with the people doing it) and **to-be** process (what changes and why).
- **Rules and escalations** register (see `crm-workflow-automation`).
- **Use cases**: business need, description (before/after), author, issues/questions, assumptions, preconditions, triggers, successful end conditions, failed end conditions, notes, flow + wireframe. Use cases become the UAT scripts, so tests check what was *approved*, not merely what was built.
- **Functional specification** per feature: context, scenarios, data model, wireframes, access and security, performance assumptions, workflow/automation, reporting requirements, migration requirements.
- **Technical specification** for anything beyond configuration.
- Avoid common design pitfalls: delayed report design; leaving data migration design until the end; letting technology override process (push the tool to meet the process, not the reverse). Design for the *whole* stakeholder set, including "doers".

## 6. Delivery method

Short iterations with demos to champions every 1-2 weeks; a change-control gate for scope; a parking-lot list for nice-to-haves (over-customising is a cost trap); issue log with owners; budget tracking; vendor management where third parties are involved; an executive-approved project charter (objectives, scope, out of scope, success metrics, team, risks, timeline, budget, governance). Environments: development, test/staging (production-like), production, with source control and automated deployment; no production PII in lower environments without masking.

## 7. Testing strategy

| Type | Purpose | Who |
|---|---|---|
| Unit | each rule/service branch, state machine, permission check | developers |
| System | features work together in a test environment | QA/dev |
| Integration | data flows correctly between CRM and other systems; translations right | dev + SMEs of each system |
| Performance | realistic data volumes and concurrent users, especially with custom code; search, list, report latency | dev/ops |
| Security | permission matrix, IDOR, injection, secrets, export controls | dev/security |
| Data migration | mock migration with full data, reconciliation, spot checks | project team + users |
| **UAT** | real users run approved business scenarios on production-like data and sign off | business users (cannot be outsourced) |

Build UAT scripts from use cases: steps, where they occur, expected result, who executes. Track defects with severity; define go/no-go criteria in advance (e.g., zero critical, no more than N medium with workarounds).

## 8. Training and enablement (adoption is the outcome)

Training is the first thing executives cut and a key driver of adoption. Plan it as a workstream: address **process and application together**; define terms; multiple exposures (before, at, after launch); tailor by role; scenario/exercise-based; executive participation; quick-reference guides, short recorded demos, in-app tips, office hours, a champions network, a visible "how do I...?" channel. Measure comprehension and usage.

## 9. Launch

Cutover plan (freeze, final migration, validation, go/no-go, rollback); communications (what changes for whom, when, why it helps them); hypercare support for the first weeks with fast fixes; daily triage of feedback; celebrate early wins.

## 10. Adoption management

Combine carrot and stick deliberately: make the CRM the easiest path (defaults, automation, mobile, fewer fields), make it the *only* source for pipeline/forecast/customer-service reviews, recognise good usage, and where appropriate tie KPIs (and sometimes compensation) to CRM-based measures. Watch adoption metrics (active use, completeness, stale records, time-to-update) and treat low adoption as a product signal, not user failure.

## 11. Evolution (Fundamentals ch. 7)

Steering committee on a fixed cadence (e.g., monthly): agenda = KPIs and adoption, issue log, change requests ranked by value/effort, roadmap progress, risks, budget. Change-control process: request -> triage -> estimate -> prioritise -> schedule -> test -> release notes -> training update. Release management: scheduled deployments, release notes, regression suite. Monitor the vendor/tool ecosystem and plan upgrades. Keep documentation (data dictionary, rule register, admin guide) current.

## 12. Common project issues and remedies

| Issue | Remedy |
|---|---|
| Over-scoping | phase; cut to one process end to end |
| Overly complicated design | remove fields/stages; progressive capture; default values |
| Software-driven project | restart from process and pains |
| Lack of executive support | re-engage sponsor; show metrics; escalate through steering |
| Conflicting priorities | steering decides using roadmap value ranking |
| Poor adoption | fix usability, retrain, remove duplicate tools, tie reviews to CRM data |
| Data distrust | publish data quality metrics, fix capture points, dedupe |

## Deliverables checklist for a new CRM project
Charter; stakeholder map; as-is/to-be; use cases; rule register; functional specs; data dictionary; metric catalog; integration scenario table; migration decision memo; test plans (system, integration, UAT); training plan; cutover plan; communications plan; adoption dashboard; steering agenda template; roadmap.

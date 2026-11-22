# Business rule register: template

Use one row per automation. Keep it in the repo (`docs/rules.md` or a table in the admin UI). Derived from the business-rule tracking idea in *CRM Fundamentals* ch. 6.

| ID | Entity | Name | Trigger | Conditions | Actions | Owner | Exceptions | Customer-visible message | Proof (report/KPI) | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| R-001 | Lead | Assign by territory | lead.created | owner is empty AND source != 'partner' | set owner by territory; create task "Call within 15 min"; notify owner | Head of Sales | existing customer -> account owner | none | % leads touched < 15 min | Active |
| R-002 | Lead | First-touch escalation | timer 30 min after assignment | no outbound activity | notify manager; at 60 min reassign to pool | Head of Sales | outside business hours -> next open time | none | SLA breach rate | Active |
| R-003 | Opportunity | Stage guard: Proposal | opportunity.stage_changing -> Proposal | missing quote OR missing decision maker | block + list missing items | Sales Ops | none | none | Stage skip count | Active |

## Event naming
`entity.verb_pastTense` for facts (`case.resolved`), `entity.verb_ing` for pre-commit checks (`opportunity.stage_changing`).

## Rule review checklist
- Does it have a named business owner and a review date?
- What happens when it runs twice? When it runs late? When the data is missing?
- Does any message action check consent, channel preference, language, quiet hours, frequency cap?
- Can an admin disable it quickly? Is there a dry-run result from real data?
- Which metric tells us it is helping?

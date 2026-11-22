---
name: crm-workflow-automation
description: Design and implement the automation layer of a CRM: event-driven rules, triggers/conditions/actions, assignment, SLA timers, reminders, escalations, approvals, scheduled jobs, notifications, idempotency, retries, and an admin-editable rule engine. Use when the user says "automate", "when X happens do Y", "workflow", "escalate", "SLA", "auto-assign", "reminder", "approval", "trigger", or wants the CRM to be proactive instead of a passive database.
---

# CRM Workflow Automation (the "active CRM" layer)

Without automation a CRM is an electronic filing cabinet. With it, the system takes actions, keeps work moving, and prevents dropped leads. Example from *CRM Fundamentals*: a qualified lead is automatically re-assigned by territory, both reps are emailed, a timer starts, and if the sales rep has not updated the lead in two days a reminder goes to the rep and the manager.

## Architecture

```
Domain service --(same DB txn)--> outbox_events --relay--> event bus/queue --> Rule engine --> Action executors
                                                                  ^                              |
                                              Scheduler (timers, cron, SLA clocks) --------------+--> audit + metrics
```

- **Events** are facts, named `entity.verb` (`lead.created`, `opportunity.stage_changed`, `case.sla_breached`, `order.confirmed`, `customer.risk_tier_changed`). Payload carries ids, changed fields (old/new), actor, timestamp, tenant.
- **Transactional outbox**: write the event row in the same transaction as the data change; a relay publishes it. This avoids "saved but no event" and "event but rolled back".
- **Rule engine**: `trigger (event) + conditions (predicate over record/context) + actions (ordered list) + settings (active, order, stop-on-match, schedule window)`. Store rules as data (`workflow_rules`), versioned, editable by admins without deploys. Validate rules on save.
- **Scheduler**: durable timers, not in-memory `setTimeout`. Model them as rows (`timers(id, fire_at, rule_id, subject, status)`) polled with `FOR UPDATE SKIP LOCKED`, or use a queue with delayed delivery. Cancel timers when the condition clears (e.g., lead updated -> cancel the "untouched in 2 days" timer).
- **Executors** are small, idempotent functions: assign_owner, create_task, send_message (template + channel), update_field, change_status, add_tag, create_record, call_webhook, request_approval, notify.

## Condition and action vocabulary (keep it small and composable)

Conditions: field comparisons (eq, in, gt, contains, is_empty, changed_to), time-based (age > N hours, no activity in N days, within business hours), relational (account.segment = X, count of open cases > 2), computed (risk_tier, score), user/team membership.
Actions: listed above plus branching (`if/else`), `wait` (duration or until condition), `stop`.

## Non-negotiable engineering properties

1. **Idempotency**: every action has an idempotency key (`rule_id + event_id + action_index`). Replays and retries must not double-send a message or double-create tasks.
2. **Loop protection**: automations that update records can fire other automations. Tag events with `caused_by_rule` and a depth counter; refuse beyond depth N; forbid a rule from re-triggering itself on its own field change.
3. **Ordering and concurrency**: per-aggregate ordering (partition by entity id); optimistic locking (`version` column) on records changed by rules.
4. **Observability**: `rule_runs` table (rule, event, started, outcome, actions executed, error). A "why did this happen?" panel on every record showing automation-generated activities with the rule name. This is how you keep users' trust.
5. **Safety rails**: dry-run/simulation mode against recent events; per-rule rate limits; global kill switch; message actions always check consent and quiet hours (see `crm-marketing-campaigns`, `crm-security-privacy`).
6. **Failure handling**: retry with exponential backoff and jitter; dead-letter queue with an admin UI; alert on error-rate spikes.
7. **Time**: business-hours calendars and holidays per team; store timezone; compute SLA clocks in business time and pause on "waiting for customer".
8. **Permissions**: actions run as a system actor but are limited by the rule owner's scope; log `actor_type='automation'`.

## Pattern catalogue (build these first)

| Pattern | Trigger | Logic |
|---|---|---|
| Lead assignment | `lead.created` | route by territory/language/capacity -> set owner -> notify -> start first-touch timer |
| First-touch SLA | timer on lead/case | if no outbound activity by due time: reminder; +X min: notify manager; +Y: reassign |
| Stale opportunity | daily schedule | open opp with no activity N days or overdue next step -> task for owner, flag in manager view |
| Stage guard | `opportunity.stage_changing` (pre-event) | validate exit criteria; block with message listing missing fields |
| Discount approval | quote saved with discount > threshold | create approval request to manager; lock quote; on approve -> unlock + notify; on timeout escalate |
| Hand-off | `lead.qualified`, `opportunity.won` | create onboarding case/tasks, notify account manager, push to accounting |
| Case escalation | priority/SLA breach/negative sentiment/VIP | raise priority, move queue, page on-call |
| Welcome / lifecycle | `customer.created`, `order.delivered` | send sequence with waits; stop on reply or opt-out |
| Dedupe on create | `contact.created` | run identity resolution; flag/merge/link |
| Risk re-score | order/return/cancel events | recompute customer quality score; change tier; apply policy (see `crm-customer-intelligence`) |
| Data quality | nightly | find invalid phones/emails/addresses, missing source; create fix tasks |

## Rule specification template

For each automation the team asks for, produce a row in the **business rule register** (the book's "business rule tracking" template) before coding. See `references/rule-spec-template.md`. Columns: ID, entity, name, trigger, conditions, actions, owner (business), exceptions, notification text, report that proves it works.

## Approvals

Model as `approval_requests(subject, policy, approver_chain, status, decided_by, decided_at, comment)`. Support single and sequential approvers, delegation when absent, timeouts with escalation, and an audit trail. Keep approval policies in data.

## Testing automation

- Unit-test each rule as a pure function of (event, state) -> planned actions.
- Scenario tests over a fake clock for timers (advance 2 days, assert reminder).
- Replay test: feed a day of anonymised real events in dry-run and review planned actions.
- Chaos tests: duplicate events, out-of-order events, executor timeouts.

## Anti-patterns

- Business logic embedded in UI handlers or DB triggers that nobody can see.
- Rules that message customers without consent checks or quiet hours.
- One giant "God rule". Prefer many small rules with clear names.
- Automations nobody owns. Every rule has a business owner and a review date.

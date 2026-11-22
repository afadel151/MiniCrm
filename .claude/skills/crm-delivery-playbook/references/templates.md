# Templates

## Use case
```
Use case #: UC-___    Title: ________
Business need: ________
Description (before -> after): ________
Author / date: ________
Actors: ________
Issues / questions: ________
Assumptions: ________
Preconditions: (what must be true/approved before this can happen)
Trigger: (user or system action that starts it)
Main flow: 1. ... 2. ... 3. ...
Alternate / exception flows: ...
Successful end condition: ________
Failed end condition: ________
Data touched (entities/fields): ________
Automation/rules involved: R-___
Reports fed: ________
Permissions: roles that can perform / see
Wireframe / flow diagram: link
Notes: ________
```

## Functional specification (table of contents)
1. Feature context: name, purpose, key users
2. Business scenarios and use cases
3. Data model (entities, fields, lookups, validation)
4. User interface wireframes
5. Access and security (roles, field-level rules)
6. Performance assumptions (volumes, concurrency, latency targets)
7. Workflow and automation overview
8. Reporting requirements
9. Data migration requirements
10. Open questions and decisions log

## Project charter (executive-approved)
Background and pain; objectives and success metrics (3-5 KPIs with baselines and targets); scope and explicit out-of-scope; stakeholders and sponsor; team and roles; approach and phases; timeline and milestones; budget; risks and mitigations; assumptions and dependencies; governance (steering cadence, change control); communication plan.

## UAT script
| Step | Action (by role) | Where | Expected result | Pass/Fail | Defect id |
|---|---|---|---|---|---|
Include: happy path, failed end condition, permission denial, edge data (very long names, Arabic/Latin mixed, missing phone), and at least one end-to-end scenario crossing departments.
Sign-off block: tester, role, date, comments, go/no-go recommendation.

## System test plan outline
Scope; environments and data; entry/exit criteria; test cases by feature (ID, precondition, steps, expected, result); regression suite; performance scenarios (users x data volume x operations); integration test matrix (system x entity x direction x event); defect severity definitions.

## Change request
Id; requester; date; description and business reason; affected users/processes/reports; effort estimate; value/risk; priority; decision (approve/defer/reject + who); release; communication/training impact.

## Steering committee agenda (60 min)
1. KPIs and adoption dashboard (10) 2. Issues and feedback themes (10) 3. Change requests for decision (15) 4. Roadmap progress and next release (10) 5. Risks/budget (5) 6. Decisions and actions (10).

## Training plan outline
Audience and role matrix; learning objectives per role; process + application modules; scenarios/exercises; schedule (pre-launch, launch, +30 days); materials (quick guides, videos, sandbox); trainers/champions; assessment; feedback loop; refresher calendar.

## Communication plan outline
Message, audience, channel, sender, date: announcement (why/benefit), progress updates, training invitations, cutover notices, launch-day instructions, "you said / we did" follow-ups.

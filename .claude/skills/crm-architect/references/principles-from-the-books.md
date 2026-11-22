# Principles distilled from the source books

Sources: *CRM Fundamentals* (Kostojohn, Johnson, Paulen, Apress 2011; "Fundamentals") and *Handbook of CRM: Achieving Excellence in Customer Management* (Adrian Payne; "Handbook"). Chapter pointers help you re-read the original; paraphrases are mine. Engineering guidance elsewhere in this pack is general practice and is labelled as such.

## From Fundamentals

**People / Process / Technology / Expectations / Pitfalls (ch. 2).**
- People: executive sponsor, steering committee, implementation team, departmental champions, a standing CRM admin team (program lead, business analyst, administrator, developer, trainer). Even a small build needs these *roles*, though one person may hold several.
- Process: operational processes (metrics visibility, cross-department handoffs, structured sales methodology, focused marketing spend, targeted touches, self-service, escalations, analytics), maintenance processes (support, training, DR) and enhancement processes (change control, roadmap).
- Technology: environments (production, development, test), source control, and the common functional areas: customers, marketing, sales, service, security, configuration/customisation, reporting, workflow automation.
- Passive vs active CRM (ch. 2): workflow plus custom logic on system events turns the CRM into an active participant.
- Pitfalls: weak sponsorship; not engaging "doers"; no roadmap; inadequate training; skipping migration/cleanup; not giving all stakeholders value; two flawed extremes (too easy for users -> no useful data; too demanding -> month-end batch entry); doing too much at once.

**Roadmap (ch. 3).** Phase the program. Assess current processes and customer-information applications, find the pain, tie to strategic goals, split the vision into projects, line up people, and use a pilot / proof-of-concept before committing.

**Evaluation (ch. 4).** When choosing build vs buy, evaluate: alignment with objectives, customisation flexibility, fit with existing infrastructure, user experience, technology standards, vendor viability and ecosystem, and cost. Deployment models: on-premises, hosted, SaaS. Licensing models differ on what is licensed and for how long.

**Planning (ch. 5).** SDLC options (waterfall, scrum, iterative), ROI, scheduling, big-bang vs phased, resourcing, change management, expectations setting, budget, issue and vendor management, an executive-approved project charter.

**Execution (ch. 6).**
- Design: as-is and to-be process, rules and escalations tracked in a business-rule template, use cases (business need, description, author, issues, assumptions, preconditions, triggers, successful and failed end conditions, notes), functional specification (feature context, scenarios, data model, wireframes, access and security, performance, workflow, reporting, migration). Pitfalls: delayed report design, late migration design, technology overriding process.
- Custom development: technical specification; manage as part of the project.
- Integration: data-level vs UI integration; table of integration scenarios (app, entity, direction, trigger, notes); data mapping; keep each system's ID on the other's record (or a separate ID-crosswalk table); test instances of every app; SMEs in testing.
- Reporting: effective KPIs are specific, owned, measurable, timely, few, targeted and aligned to goals.
- Data migration: default to *not* migrating until justified; assess access, schema, quality; entity -> field -> value mapping (pick-lists, lookups, parsing); mock migration with full data on production-like hardware, scripted and logged; validate by error logs, query testing, spot testing; go/no-go.
- Testing: unit, system, integration, performance, user acceptance (UAT executed by users; use cases become test plans).
- Training: process plus application, defined terms, multiple exposures, role-tailored, exercises, executive participation, help resources.
- Launch: cutover, final migration, communications, post-deployment support. Adoption: carrot vs stick, tie KPIs and sometimes compensation to usage.
- Common issues: over-scoping, over-complicated design, software-driven projects, lack of executive support, differing priorities, poor adoption.

**Maintain and evolve (ch. 7).** Steering committee cadence and agenda; feedback capture and issue triage; change control; roadmap execution; release management; upgrades; monitoring the vendor ecosystem.

## From the Handbook

**Strategic frame (ch. 1).** CRM aims to acquire and retain *profitable* customers. Five cross-functional processes: strategy development, value creation, multi-channel integration, information management, performance assessment. A CRM system has two IT components: a data repository and analytical/operational tools. It is a value trade-off: value delivered to the customer versus value extracted.

**Strategy development (ch. 2).** Segment the market, choose a CRM strategy appropriate to the business: product-based selling, customer-based marketing, managed service and support, individualised CRM. Not every business needs the most sophisticated tier.

**Value creation (ch. 3).** Value the customer receives (value proposition) and value the organisation receives (profitability, acquisition and retention economics, CLV). CLV = net present value of future profit flows over the relationship; discount factor D = (1+i)^n. ACURA: acquisition, cross-sell, upsell, retention, advocacy. Peppers and Rogers tiers as quoted in the Handbook: MVC (most valuable: retain), STC (second tier: grow), BZ (below zero: divest or migrate to cheaper channels). Retention improvement impacts profit strongly; framework: measure retention, find causes of defection, correct.

**Multi-channel integration (ch. 4).** Channels must be integrated around the customer relationship life-cycle and the experience *across* channels, not only within one.

**Information management (ch. 5).** Data repository = tactical databases + data marts + data warehouse; an operational data store (ODS) gives front-office systems a single identity per customer. Analytical tasks: segmentation, affinity grouping, churn management (reactive: give agents offers at the moment of threat; proactive: target at-risk segments), profiling, profitability (needs service cost data per customer), OLAP. Front-office: SFA, call-centre/help-desk, product configuration, campaign management. Data protection and privacy are board-level issues; record the *source* of customer data on each record.

**Performance assessment (ch. 6).** Customer metrics: acquisition and retention rates, satisfaction, CLV, experience across channels, complaints, segment profitability, share of wallet, product density, recommendation/advocacy, cross-sell/upsell value. Plus people/process metrics, strategic metrics. Use a balanced scorecard and linkage models (service-profit chain); measure CRM ROI.

**Organising (ch. 7).** Five maturity stages (pre-CRM planning; building a data repository; moderately developed; well developed; highly advanced). Early stages are dominated by *who are our customers?* data quality (multiple records per customer; fake default values such as 11/11/11 dates caused by mandatory fields). Barriers: skills, investment, data quality, benefits not understood, functional boundaries, leadership, measurement. Run a readiness audit; pilot; engage employees.

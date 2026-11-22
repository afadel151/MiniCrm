---
name: crm-customer-intelligence
description: Add analytics and decision logic to a CRM: customer segmentation, RFM, customer lifetime value (CLV/LTV, NPV-based), profitability, ACURA (acquisition, cross-sell, upsell, retention, advocacy), MVC/STC/BZ customer tiers, churn and retention analysis, customer quality or risk scoring, blacklisting rules, next-best-action, data warehouse/data mart design for CRM. Use when the user asks who the best or worst customers are, wants scores, tiers, churn prediction, segmentation, "customer value", or analytics on top of CRM data.
---

# Customer Intelligence

CRM aims to acquire and retain *profitable* customers (Handbook ch. 1). Intelligence turns the interaction and order history into decisions: whom to prioritise, whom to protect, whom to nurture, whom to restrict. Build it in layers; each layer must be explainable to the user who acts on it.

## Layer 0: Data you must collect for any of this

- Order/transaction history with margin or cost (revenue alone misleads).
- **Cost-to-serve**: support time, number of contacts, returns/refusals, failed deliveries, discounts. The Handbook stresses that without per-customer service cost, costs get averaged and seemingly valuable customers hide as unprofitable ones.
- Interaction history (all channels) and outcomes; complaints and reasons.
- Source/campaign; acquisition cost per channel.
- Consent and preferences.
- Outcome reason codes (lost, returned, cancelled, churned).

## Layer 1: Descriptive (ship first, no ML)

**Segmentation.** Start with simple, actionable segments: lifecycle (lead / new / active / at-risk / lapsed / won-back), value tier, channel, geography, product affinity, behaviour (RFM). Criteria for a viable segment (Handbook ch. 2): identifiable, sizeable, reachable, distinct in response, stable enough to act on. Store segment membership as computed attributes refreshed on a schedule plus event-driven updates; expose segment filters everywhere (lists, campaigns, automation conditions).

**RFM.** Recency (days since last order), Frequency (orders in window), Monetary (net margin or revenue in window). Score 1-5 by quintile *within tenant*; combine into named segments (Champions, Loyal, Potential, New, At risk, Hibernating). Formulas in `references/formulas.md`.

**Value tiers (Peppers and Rogers as cited in the Handbook).** Rank customers by (potential) lifetime value into quintiles and treat three groups deliberately:
- **MVC** (most valuable customers): objective = retention; protect with service priority, proactive outreach.
- **STC** (second-tier customers, highest unrealised potential): objective = growth; cross-sell/upsell, win more share of wallet.
- **BZ** (below-zero customers, cost more than they return): objective = reduce cost-to-serve, migrate to cheaper channels, require prepayment/minimums, or divest *where ethically and legally appropriate*. Review criteria transparently and allow appeal.

**ACURA** (Handbook ch. 3): for each priority segment define strategies and a rough profit impact for Acquisition, Cross-sell, Upsell, Retention, Advocacy. Pick 2-4 segments with the greatest long-term profit potential; attach metrics per segment.

## Layer 2: CLV and profitability

CLV = net present value of expected future profit flows over the relationship, including cross-sell, upsell and advocacy/reference effects where relevant (Handbook ch. 3). Be conservative. Discount factor D = (1+i)^n (worked example in the book: profits 1000, 2000, 3000, 4000, 5000 at 10% discount; exact NPV is about 10,652, the book prints 10,670, see `references/formulas.md`).

Practical model for most CRMs:
```
margin_per_period = avg_order_margin x orders_per_period - cost_to_serve_per_period
retention = P(active in next period)   # from cohort data, per segment
CLV = sum_{t=1..T} margin_per_period x retention^(t-1) / (1+i)^t
```
Compute at segment level first; individual-level only when data volume justifies. Show *ranges* and confidence. The point is comparing marketing programs and prioritising, not an exact number.

## Layer 3: Retention and churn

Framework (Handbook ch. 3): (1) measure retention by segment/cohort/channel/time; (2) identify causes of defection and key service issues (use reason codes and case categories, not guesses); (3) corrective action.
- Define churn per business (no order in X days, cancelled subscription, closed account). Calibrate X from the inter-purchase interval distribution.
- Leading indicators: lengthening gaps between orders, rising complaints/returns, declining engagement, negative feedback, price-sensitive behaviour.
- **Reactive** (agent offers help/incentive when customer threatens to leave) and **proactive** (targeted outreach to at-risk segments). Log every intervention to measure uplift.
- Keep a **holdout** group to prove retention actions work before scaling.

## Layer 4: Predictive scoring (only after descriptive layers are trusted)

- Candidate models: churn propensity, purchase propensity, lead conversion, delivery/return risk. Start with logistic regression or gradient-boosted trees; keep features explainable; log model version and top reasons with each score.
- Leakage and bias checks: no features that are proxies for protected attributes; evaluate by segment; monitor drift; human override with audit.
- Next-best-action: rules first (eligibility + priority + frequency caps), model-based ranking second.

## Customer quality / risk score (rules-based, transparent)

Useful wherever customer behaviour carries cost (returns, refusals, chargebacks, non-payment). Implementation pattern:

```
inputs: orders_total, orders_delivered, returns_count(+reasons), refusals, failed_delivery_attempts,
        confirmation_rate, avg_confirmation_latency, contact_accuracy_flags, account_age, AOV, LTV
score = weighted points with caps (store weights in config) -> tier: A trusted / B normal / C watch / D restricted
policy by tier: A: skip extra checks; B: standard confirmation; C: mandatory agent call, partial prepayment above value X; D: manual approval or prepayment only
```
Guardrails: clear, reviewable criteria (e.g., 3+ returns in 6 months is a *trigger for review*, not an automatic permanent ban); time-decay so people can recover; reason codes distinguishing customer-caused from our-caused returns (wrong item, damaged); appeal path; audit log of tier changes; legal check on automated decisions and on sharing blacklists across businesses (do not share personal data without a lawful basis). Weighted rules and examples in `references/formulas.md`.

## Data architecture for analytics (Handbook ch. 5)

- Start with **one operational database + read replicas + materialised views**; add a warehouse (columnar store) when queries slow the app or you need history across systems.
- Layers: tactical DB (the CRM) -> data mart per subject (sales, service, marketing) -> enterprise warehouse -> BI. An **operational data store** (the `customer_360` projection) gives front-office a single identity quickly.
- Build **snapshot tables** for anything whose past you will want to see (pipeline, customer tier, segment membership, risk score).
- Store score *explanations* and `scored_at`/`model_version`.
- Data quality monitors: completeness, validity, uniqueness, freshness; alert on drops.

## Outputs to produce

Segment definitions (SQL/views) + refresh schedule; tier/score config tables; CLV query and assumptions page; churn definition and dashboard; list of automations driven by tiers (link to `crm-workflow-automation`); a measurement plan with holdouts; privacy/fairness notes.

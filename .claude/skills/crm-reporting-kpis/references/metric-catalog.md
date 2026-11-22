# Metric catalog (template + starter definitions)

Template fields: **Name | Definition | Formula | Grain | Source | Filters | Owner | Target | Cadence | Caveats**

## Sales
| Metric | Definition / formula | Notes |
|---|---|---|
| Pipeline coverage | open pipeline amount (stages 2+, close date in period) / target for period | target 3x is a common starting heuristic; calibrate with history |
| Stage conversion | opps that ever reached stage N+1 / opps that reached stage N, per cohort of creation month | needs stage history |
| Win rate | won / (won + lost), by close month; also by source, segment, owner | exclude opportunities closed as duplicate/invalid |
| Sales cycle | median days created -> won (won deals only) | report median and P75 |
| Velocity | (#open opps x win rate x avg won amount) / avg cycle days | directional |
| Stale deals | open opps with no activity > N days or overdue next step | owner-level list |
| Forecast accuracy | |forecast at start of period - actual closed| / forecast | requires snapshots |
| First-touch time | median minutes from lead creation to first outbound activity | SLA input |

## Service
| Metric | Definition / formula |
|---|---|
| First response time | median business minutes from case creation to first agent reply |
| Resolution time | median business hours created -> resolved (paused while pending customer) |
| SLA attainment | cases meeting target / cases due in period |
| Reopen rate | cases reopened within 7 days / cases resolved |
| FCR | resolved with one customer contact / resolved |
| CSAT | % 4-5 of responses (state response rate) |

## Marketing
| Metric | Definition / formula |
|---|---|
| Cost per lead | spend / leads created (by source) |
| CAC | acquisition spend (marketing + sales cost allocated) / new customers |
| Lead -> customer | customers from lead cohort / leads in cohort |
| Revenue per campaign | order margin attributed (first- or last-touch, state which) |
| Unsubscribe rate | unsubscribes / delivered |
| List health | % contacts with a valid, consented, reachable channel |

## Customer / retention
| Metric | Definition / formula |
|---|---|
| Active customers | customers with >= 1 order in trailing N days |
| Retention (period) | active in both t and t+1 / active in t |
| Repeat purchase rate | customers with >= 2 orders / customers with >= 1 order |
| AOV | revenue / orders |
| CLV (segment) | discounted margin stream, see crm-customer-intelligence |
| Product density | average distinct products/categories per active customer |
| Share of wallet | our spend / customer's total category spend (needs survey or estimate) |
| NPS | %promoters (9-10) - %detractors (0-6) |

## Operations (e-commerce / COD)
| Metric | Definition / formula |
|---|---|
| Confirmation rate | confirmed / orders needing confirmation |
| Unconfirmed rate | unconfirmed after final attempt / orders |
| Delivery success | delivered / dispatched; first-attempt success separately |
| Return/refusal rate | returned or refused / shipped, by product, city, carrier, agent, reason |
| Time to deliver | median days dispatched -> delivered (urban/other) |
| Net margin per order | revenue - COGS - shipping - fees - returns cost - support cost |

## CRM program health
| Metric | Definition |
|---|---|
| Weekly active users / licensed | distinct users with meaningful actions (not just login) |
| Record completeness | % key fields filled on active records |
| Duplicate rate | candidate duplicate pairs / 1,000 records |
| Automation success rate | successful actions / attempted; DLQ size |
| Change backlog age | median age of open change requests |

## Target-setting reminders
Targets must be time-bound, within the owner's control, captured by a real process, and adjusted for seasonality rather than spread evenly across months.

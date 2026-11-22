# Formulas and SQL sketches

## RFM scoring (PostgreSQL)

```sql
WITH base AS (
  SELECT c.id AS customer_id,
         CURRENT_DATE - MAX(o.placed_at)::date          AS recency_days,
         COUNT(*) FILTER (WHERE o.status='delivered')    AS frequency,
         COALESCE(SUM(o.margin_minor) FILTER (WHERE o.status='delivered'),0) AS monetary
  FROM contacts c JOIN orders o ON o.contact_id=c.id
  WHERE o.placed_at >= now() - interval '12 months' AND c.tenant_id = $1
  GROUP BY c.id
), scored AS (
  SELECT *,
    6 - NTILE(5) OVER (ORDER BY recency_days ASC)  AS r,   -- recent = 5
    NTILE(5) OVER (ORDER BY frequency)             AS f,
    NTILE(5) OVER (ORDER BY monetary)              AS m
  FROM base
)
SELECT *, CASE
  WHEN r>=4 AND f>=4 AND m>=4 THEN 'champion'
  WHEN r>=3 AND f>=3            THEN 'loyal'
  WHEN r>=4 AND f<=2            THEN 'new_or_promising'
  WHEN r<=2 AND f>=3            THEN 'at_risk'
  WHEN r<=2 AND f<=2            THEN 'hibernating'
  ELSE 'potential' END AS segment
FROM scored;
```
(Quintile cut-offs depend on distribution; for skewed small data use fixed business thresholds.)

## Retention and churn
- Period retention = customers active in period t+1 who were active in t / customers active in t.
- Cohort retention table: rows = acquisition month, columns = months since first order, cell = % ordering again.
- Churn rate = 1 - retention. Expected lifetime in periods ~ 1 / churn (rough, for stable segments).
- Reorder gap threshold: use the P80-P90 of inter-purchase days per segment as the "lapsed" cut-off.

## CLV (discounted)
```
CLV = SUM_{t=1..T} [ (m - c) * r^(t-1) ] / (1+i)^t
m = margin per period, c = cost-to-serve per period, r = retention per period, i = discount rate per period
```
Worked check from the Handbook (ch. 3): profits 1000, 2000, 3000, 4000, 5000 (in thousands) at a 10% discount rate. The book's rounded factors (0.91, 0.83, 0.75, 0.68, 0.62) give rows of 910, 1660, 2250, 2720, 3100, which sum to 10,640, yet the book prints a total of 10,670, a small arithmetic slip in the source. With exact factors (1/1.1^n) the NPV is about 10,652. Use unrounded factors in code, and do not "fix" your code to match the printed 10,670.

## Customer profitability
```
customer_profit = revenue - COGS - discounts - shipping_paid_by_us - payment_fees
                  - returns_cost (reverse logistics + write-offs) - support_cost (minutes x rate) - acquisition_cost_allocated
```
Allocate acquisition cost by source/campaign; flag customers with negative contribution for tiering (BZ review).

## Risk / quality score (weights are config, shown as defaults to calibrate)

| Signal | Points | Cap |
|---|---|---|
| Return/refusal where customer-caused, last 6 months | +25 each | 75 |
| Failed delivery attempts (customer unavailable) | +10 each | 30 |
| Order cancelled after confirmation | +10 each | 30 |
| Unconfirmed after 3 attempts | +10 | 10 |
| Contact data mismatch (phone/address changed or invalid) | +10 | 20 |
| Delivered orders without issue | -5 each | -25 |
| Account age > 12 months with >= 3 delivered | -10 | -10 |

Tier thresholds (example): A <= 0, B 1-24, C 25-49, D >= 50. Recompute on events; decay customer-caused events after 6-12 months. Calibrate by checking realised return rates per tier (A should be clearly lower than D); if tiers do not separate outcomes, change the weights.

## Uplift measurement
Randomly hold out 10% of an eligible segment from an intervention; compare outcome rates; report absolute uplift and confidence interval before rolling out wider.

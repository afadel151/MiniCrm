# Confirmation, fraud control and return-rate reduction

## Contents
- Why confirmation exists
- Confirmation workflow
- Outcome codes
- Order risk scoring
- Return-rate levers
- Metrics to build

## Why confirmation exists

Orders from social ads are impulse purchases and many are fake, accidental, or placed by someone who will not answer the door. A short confirmation call (or WhatsApp/SMS message) before shipping filters most of them. Merchants either run their own call center or outsource it, so the CRM must support multiple agents, queues, and per-agent performance.

## Confirmation workflow

1. Order enters `pending_confirmation` and is auto-assigned to an agent queue (round robin or by language/wilaya).
2. Attempt 1 soon after creation. If no answer, schedule further attempts at different times of day. Make the attempt count and spacing **configurable** (typical practice is several attempts over 1-2 days `[VERIFY]`).
3. During the call the agent confirms: product and quantity, **total to pay including delivery**, wilaya/commune/address, delivery type, phone, and a delivery window if the carrier supports it.
4. Agent records an outcome code. Address or phone corrections are logged as field changes.
5. On `confirmed`: reserve stock, freeze `cod_amount_dzd`, push to `ready_to_ship`.
6. After max attempts with no contact: `unreachable -> cancelled_unconfirmed`.

Automations worth building: WhatsApp/SMS confirmation with reply keywords, auto-reminder before delivery, one-click postpone.

## Outcome codes

`confirmed`, `no_answer`, `phone_off`, `busy`, `wrong_number`, `refused`, `asked_to_call_back`, `postponed`, `changed_order`, `duplicate_order`, `price_dispute`, `address_incomplete`.

Each outcome maps to a defined next action and next-attempt time. Keep codes as a lookup table so merchants can add their own.

## Order risk scoring

Compute a simple, explainable score at creation and again at confirmation. Inputs (weights are tunable config):

- Customer history: prior returns/refusals by normalized phone, prior successful deliveries (strong positive).
- Blacklist hit (phone, address fragment).
- Duplicate orders within a short window on the same phone.
- Source/campaign historical return rate.
- Order value high for the commune or category.
- Wilaya/commune historical failed-delivery rate per carrier.
- Phone type (landline = riskier), suspicious patterns (sequential digits).
- Address completeness (missing commune, very short address line).
- Time-to-confirm and number of attempts needed.

Use the score to **route**, not to silently reject: low risk -> normal flow; medium -> mandatory call + stop-desk suggestion; high -> require partial prepayment, extra verification, or manual approval. Always show agents the reasons behind the score.

## Return-rate levers

- Confirm before shipping (largest effect).
- Nudge stop-desk delivery for remote or high-risk areas.
- Clear total price (including delivery) stated on the call and on the order page to avoid refusal at the door.
- Verify address quality; capture landmarks and a second phone number.
- Pick the best carrier per wilaya based on measured delivery success, not only price.
- Limit COD or require deposit for repeat returners; blacklist with an appeal path.
- Fast reattempt policy: schedule a second delivery attempt and call the customer after the first failure.
- Product-side causes: track return reasons (not as described, size, price, changed mind) so the merchant can fix listings.

## Metrics to build

- Confirmation rate = confirmed / total orders.
- Delivery success rate = delivered / shipped.
- Return rate = returned / shipped, by wilaya, carrier, product, campaign, agent.
- Net delivered rate = delivered / total orders (the honest funnel number).
- Cost per delivered order (ad spend + call center + delivery + return fees) / delivered.
- Cash cycle time = delivered date to remitted date, by carrier.
- Agent metrics: calls per hour, confirm rate, and, crucially, **delivery rate of orders they confirmed** (so agents are not rewarded for confirming bad orders).

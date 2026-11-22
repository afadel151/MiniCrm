# Data model and state machines

## Contents
- Two state machines, not one
- Core entities
- Transition rules
- Money fields

## Two state machines, not one

### Order / fulfillment status
```
new -> pending_confirmation -> confirmed -> ready_to_ship -> shipped
    -> out_for_delivery -> delivered
```
Side exits:
- `pending_confirmation -> unreachable` (no answer, retry window) -> `cancelled_unconfirmed`
- `pending_confirmation -> cancelled_by_customer`
- `postponed` (customer asks for a later date; has `postponed_until`)
- `shipped | out_for_delivery -> delivery_failed -> (reattempt | return_in_transit)`
- `return_in_transit -> returned_to_merchant`
- `delivered -> exchange_requested -> exchange_shipped` (exchange creates a linked child order)

### Cash status (independent)
```
not_applicable (cancelled before shipping)
expected -> collected_by_courier -> remitted_by_carrier -> reconciled
                                  -> disputed
```
- `expected`: COD amount set when order is confirmed.
- `collected_by_courier`: set when carrier reports delivered.
- `remitted_by_carrier`: set from carrier payout/settlement batch.
- `reconciled`: merchant confirms amount matches (after fees and return charges).
- `disputed`: mismatch; needs manual resolution.

## Core entities (names are suggestions)

- `customer`: id, full_name, phone_primary (normalized), phone_secondary, preferred_language, blacklist_flag, notes.
- `order`: id, customer_id, source (facebook, tiktok, instagram, website, whatsapp, manual), utm fields, fulfillment_status, cash_status, delivery_type (`home` | `stopdesk`), wilaya_code, commune_id, address_line, stopdesk_id nullable, subtotal_dzd, delivery_fee_dzd, discount_dzd, cod_amount_dzd, created_at.
- `order_item`: order_id, product_id, variant_id, qty, unit_price_dzd, unit_cost_dzd.
- `confirmation_attempt`: order_id, agent_id, channel (call/whatsapp/sms), outcome, note, attempted_at, next_attempt_at.
- `shipment`: order_id, carrier_code, tracking_number, carrier_status_raw, normalized_status, label_url, created_at, attempt_count.
- `shipment_event`: shipment_id, raw_status, normalized_status, payload_json, received_at, dedupe_key (unique).
- `remittance_batch`: carrier_code, period, gross_collected_dzd, fees_dzd, return_fees_dzd, net_paid_dzd, paid_at, reference.
- `remittance_line`: batch_id, shipment_id, collected_dzd, fee_dzd, return_fee_dzd, match_status.
- `status_log`: entity_type, entity_id, from_status, to_status, actor (user/system/carrier), reason, at.
- `wilaya`, `commune`, `stopdesk`, `carrier_tariff`: reference tables, editable, versioned. See `algeria-specifics.md`.

## Transition rules

Implement transitions in one place (a function or class) that:
1. Validates `from -> to` is allowed.
2. Checks preconditions (e.g. `ready_to_ship` requires normalized phone, valid commune, nonzero COD amount unless prepaid).
3. Writes `status_log`.
4. Triggers side effects (stock reservation/release, notifications) via events, not inline.

Stock rules:
- Reserve stock at `confirmed`.
- Release on any cancel path.
- Restock on `returned_to_merchant` only after an inspection flag (damaged returns exist).

## Money fields

- All DZD integers. Round only at the point of computing delivery fee or discount, and document the rule.
- Keep `cod_amount_dzd` as the amount the courier must collect. It can differ from subtotal + fee (negotiated at confirmation, partial prepayment, free delivery).
- Margin per order = subtotal - item cost - delivery fee paid to carrier - return fee exposure - ad cost attribution. Provide it in reporting, since margin and return rate are what merchants actually decide on.

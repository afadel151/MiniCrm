# Carriers and cash reconciliation

## Contents
- Carrier landscape
- Adapter interface
- Status normalization
- Webhooks vs polling
- Fees and tariffs
- Remittance reconciliation
- Failure handling

## Carrier landscape `[VERIFY]`

Commonly used Algerian COD carriers include Yalidine, ZR Express, Maystro Delivery, Procolis, and several carriers built on the Ecotrack platform (which gives them a similar API shape). Availability, coverage and API access differ and change; confirm current docs and credentials per merchant. Many merchants use two or more carriers and route by wilaya.

## Adapter interface

Define one interface and implement one adapter per carrier. Nothing outside adapters should know carrier-specific fields.

```
CarrierAdapter
  create_shipment(order) -> {tracking_number, label_url, fee_estimate}
  cancel_shipment(tracking_number)
  get_status(tracking_number) -> NormalizedEvent
  parse_webhook(request) -> list[NormalizedEvent]
  list_wilayas() / list_communes(wilaya) / list_stopdesks(commune)
  get_tariff(wilaya, commune, delivery_type, weight) -> fee_dzd
  fetch_remittances(period) -> list[RemittanceLine]   # if the carrier exposes it
```

Requirements:
- Credentials per merchant, stored encrypted, never logged.
- Timeouts, retries with backoff, and a circuit breaker; carrier APIs are sometimes slow or down.
- Rate-limit awareness; batch where supported.
- Return a clear, typed error for "commune not served" so the UI can suggest another carrier or stop-desk.

## Status normalization

Map every carrier status to a small internal vocabulary:

`created`, `picked_up`, `in_transit`, `at_destination_hub`, `out_for_delivery`, `delivery_attempt_failed`, `delivered`, `return_initiated`, `return_in_transit`, `returned_to_sender`, `lost_or_damaged`, `cancelled`.

Keep the raw status and payload in `shipment_event`. Maintain the mapping in a table so new carrier statuses degrade to `unknown` (alert) instead of crashing or being silently dropped.

Rules:
- Statuses can arrive out of order or duplicated. Use `dedupe_key` (carrier + tracking + raw status + timestamp) and only allow forward transitions unless the carrier explicitly reverses.
- `delivered` sets cash status to `collected_by_courier`, not `reconciled`.
- `delivery_attempt_failed` increments `attempt_count` and triggers the customer-call task.

## Webhooks vs polling

Prefer webhooks when offered; always keep a polling fallback job for shipments in non-terminal states older than a threshold. Verify webhook authenticity (secret/signature) and respond fast; process asynchronously from a queue.

## Fees and tariffs `[VERIFY]`

Fees typically depend on wilaya/zone, home vs stop-desk, and weight. Return fees and COD handling fees may apply. Store per merchant + carrier in `carrier_tariff` with effective dates. Compute the **customer-facing delivery fee** (what the merchant charges) separately from the **carrier cost** (what the merchant pays); the difference is margin or subsidy.

## Remittance reconciliation

Carriers collect cash and pay merchants in periodic batches, net of fees. The CRM must reconcile, because this is where merchants lose money silently.

Job outline:
1. Ingest the carrier's settlement (API, CSV/Excel upload, or manual entry) into `remittance_batch` + `remittance_line`.
2. Match each line to a shipment by tracking number.
3. Compare `collected_dzd` with the order's `cod_amount_dzd`. Compare fees with the expected tariff.
4. Classify each line: `matched`, `amount_mismatch`, `fee_mismatch`, `missing_from_batch` (delivered but not paid after the expected delay), `paid_not_delivered`.
5. Surface exceptions in a queue with the evidence (events, timestamps) so the merchant can dispute.
6. When all lines are accepted, set cash status `reconciled` and compute the batch net.

Also track: aging report of delivered-but-unpaid orders per carrier, and expected cash inflow forecast.

## Failure handling

- Shipment creation fails: keep order `ready_to_ship`, record the error, allow retry or switching carrier; never lose the order.
- Parcel stuck with no events for N days: raise an alert task.
- Customer refuses at the door: record the refusal reason, trigger the return flow, and update the customer's risk history.
- Lost or damaged parcel: open a claim record linked to the shipment and the cash line.

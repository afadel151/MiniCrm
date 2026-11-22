# Mapping templates

## Entity mapping
| Source system | Source entity | CRM entity | Filter (which records) | Notes |
|---|---|---|---|---|
| OldCRM | Company | accounts | active in last 24 months | merge duplicates by phone/domain |
| OldCRM | Person | contacts | linked to migrated account | split "name" into full_name + optional first/last |
| Sheet "Orders" | row | orders | 2025-01-01 onward | status mapping below |

## Field mapping
| Source field | CRM field | Transform | Required? | Reject rule |
|---|---|---|---|---|
| Phone | contact_points(kind=phone).value_norm | E.164 with default country | no | invalid -> keep raw, status=unverified |
| Street1/Street2/City | addresses.line1/line2/city | trim | no | |
| SalesRep | opportunities.owner_id | lookup via users crosswalk | yes | unmapped -> default queue owner + flag |

## Value mapping (pick-lists; codes differ even if labels match)
| Source field | Source value | CRM field | CRM value | Notes |
|---|---|---|---|---|
| Sales Stage | New (3) | stage | New | |
| Sales Stage | In-Progress (1) | stage | Qualified | confirm with sales lead |
| Sales Stage | In-Contracts (2) | stage | Negotiation | |
| Sales Stage | Won (4) | stage | Won | set closed_at from source close date |

## Integration data map (ongoing)
| CRM field | CRM value | Other system field | Other value | Direction | System of record | Conflict rule |
|---|---|---|---|---|---|---|
| order.status | confirmed | carrier.status | READY_FOR_PICKUP | -> | CRM | n/a |
| order.status | delivered | carrier.status | DELIVERED | <- | carrier | carrier wins |
| customer.phone | E.164 | store.phone | raw | <-> | CRM after verification | latest verified wins |

## Migration run log (per run)
run_id, started_at, source snapshot id, script version, counts read/created/updated/skipped/rejected per entity, error file path, reconciliation results, sign-off name/date, go/no-go decision.

## Validation checklist
- Counts reconcile per entity (explain every delta).
- 50+ random records spot-checked field by field including relationships.
- Zero orphans; zero duplicate external IDs; zero null in required fields.
- Reports on migrated data match the legacy report totals within an agreed tolerance.
- Users from each team signed off on samples from their area.

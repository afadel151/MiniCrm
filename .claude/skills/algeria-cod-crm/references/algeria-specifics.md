# Algeria-specific rules

## Contents
- Phone numbers
- Wilayas and communes
- Home delivery vs stop-desk
- Language and UI
- Currency
- Compliance and platform notes

## Phone numbers

- Mobile numbers are 10 digits locally, starting `05`, `06` or `07`; international form `+213` followed by 9 digits (drop the leading 0).
- Customers type them as `0555 12 34 56`, `+213 555123456`, `00213555123456`, `555123456`, with spaces, dots or dashes.
- Store ONE canonical form (recommended: E.164 `+213XXXXXXXXX`) and keep the raw input too.
- Landlines (`021...`, `031...`, etc.) are valid numbers but poor for COD confirmation; flag them.
- Validate on capture, again before shipment creation. Use `scripts/normalize_phone.py` as the reference behavior.
- Duplicate detection key = normalized phone (+ optionally normalized name). Same phone ordering many times, or many different names on one phone, are signals for fraud/return analysis.

## Wilayas and communes

- Algeria historically had 58 wilayas with codes 01-58, and the administrative structure has been reformed recently. `[VERIFY]` the current official list and codes before shipping; carriers may lag behind or use their own ids.
- Never hard-code. Keep `wilaya` and `commune` as reference tables with an `active` flag, and a per-carrier mapping table (`carrier_wilaya_map`, `carrier_commune_map`) because each carrier has its own ids and spellings.
- Customers misspell communes in Arabic, French and Latin-transliterated Arabic. Provide dropdown selection (wilaya -> commune) rather than free text; if importing free text, fuzzy-match and flag low-confidence matches for an agent.
- Some communes are not served for home delivery or are served only by some carriers. Availability is per carrier + commune + delivery type.

## Home delivery vs stop-desk

- **Home delivery**: courier brings the parcel to the address. Higher fee, higher failed-attempt risk (wrong address, absent customer).
- **Stop-desk / pickup point (bureau/agence)**: customer collects at a carrier office. Lower fee, usually lower return rate because the customer commits to a trip, but not available everywhere.
- Model `delivery_type` on the order and make the fee depend on carrier + wilaya (+ commune zone) + delivery type + weight bracket `[VERIFY]`.
- Offer stop-desk as a nudge during confirmation for high-risk orders or remote communes.

## Language and UI

- Agents and customers use Arabic, French, and mixed Arabic/French/Latin-script Arabic. Support RTL layouts for Arabic UI and customer messages.
- Keep templates (SMS/WhatsApp confirmation scripts, call scripts) in both Arabic and French, selected by `preferred_language`.
- Store names and addresses as UTF-8 and never transliterate destructively.
- Sort/search should be accent-insensitive for French and tolerant of Arabic variants (alef forms, ta marbuta).

## Currency

- DZD, no decimals in practice. Integer storage. Display with thousands separator and `DA` or `DZD` per user locale.

## Compliance and platform notes `[VERIFY]`

- Personal data of customers (phone, address) should be handled according to Algerian data-protection law (Law 18-07) and the merchant's own policy. Keep access role-based; call-center agents should not need bulk export rights.
- Ad platforms (Meta, TikTok) feed most orders. Capture campaign/ad ids for attribution, since return rate varies strongly by source.
- Carrier terms (fees, remittance delay, return fees, insurance, maximum COD amount) are contractual and change. Keep them in configuration per merchant + carrier.

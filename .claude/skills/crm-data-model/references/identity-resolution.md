# Identity resolution and deduplication

Goal: one real customer = one golden record, without destroying evidence, and without merging two different people.

## 1. Normalise first
- Phone -> E.164 (use libphonenumber with a default country from the tenant). Strip spaces, leading zeros, "+" variants. Mark landline/mobile when detectable.
- Email -> trim, lowercase; for known providers optionally canonicalise dots/plus-tags into a *match key* (keep the raw value untouched).
- Names -> casefold, strip diacritics and titles ("Dr."), transliterate or store both scripts for Arabic/Latin names, order-insensitive token comparison ("Ahmed Ben Ali" vs "Ben Ali Ahmed"). Beware naive splitting ("Van Winkle", compound surnames): store `full_name` and treat first/last as optional.
- Address -> standardise city/region via lookup; compare postal code and street tokens.
- Company -> strip legal suffixes (Ltd, SARL, LLC), punctuation, case.

## 2. Matching tiers
| Tier | Rule | Action |
|---|---|---|
| A: certain | same external ID, or same verified email, or same verified phone + same normalised name | auto-link (attach to existing record) |
| B: probable | same phone OR email, name similarity >= 0.85 | auto-link but flag `needs_review=false`; log reason |
| C: possible | name similarity >= 0.8 + same city/postal, or shared phone across different names | queue for human review; never auto-merge |
| D: none | otherwise | create new |

Shared phones/emails (family, company switchboards, agents ordering for others) cause false merges: keep a `shared_contact_point` flag and require a second signal.

## 3. Write-time protocol
1. Normalise input. 2. Look up by contact_points(value_norm) and external_ids. 3. If tier A/B hit, return the existing record and add any new contact point/address to it. 4. If tier C, create the record with `possible_duplicate_of` and surface a banner. 5. Always return which rule matched (for debugging and trust).

## 4. Batch job
Nightly: block by (phone_norm), (email_norm), (soundex/metaphone or trigram of name + city). Score pairs within blocks. Store pairs in `duplicate_candidates(a_id, b_id, score, reasons, status)`.

## 5. Merge rules
- Survivorship: prefer verified > most recent > most complete per field; owner and lifecycle stage by explicit rule; never drop contact points, addresses, consents (consent: most restrictive wins).
- Re-point children (activities, orders, cases, opportunities) to the survivor; set `merged_into_id` on the loser; keep a `merge_log` with the full pre-merge snapshot so it can be undone.
- Merge is an audited, permissioned action. Events: `contact.merged` (so integrations re-link external IDs).

## 6. Quality metrics to track
Duplicate rate (candidate pairs per 1,000 records), % records with verified phone, % invalid/bounced contact points, % records with source, completeness score distribution, failed-delivery address rate.

# ADR-0001: Money stored as `numeric(12,2)` DZD

- Status: **Accepted** (product lead, 2026-11-20)
- Context: V1 Spec §4.1 says `numeric(12,2)` in DZD. CLAUDE.md §7 said "integer DZD". Precedence
  (ADRs > v0.2 > spec > CLAUDE.md) favours the spec, and CLAUDE.md requires raising conflicts, so the product
  lead was asked.
- Options: (a) `bigint` whole dinars; (b) `numeric(12,2)` per spec; (c) `bigint` centimes.
- Decision: **(b)**. Every money column is `numeric(12,2)` with `CHECK (>= 0)` unless a sign is meaningful
  (adjustments), plus `currency char(3) DEFAULT 'DZD'` on money-bearing aggregates. C# type `decimal`;
  JSON as a string or number with exactly 2 decimals (fixed in the event schemas, Phase 3).
- Consequences: exact arithmetic, no floats (the real invariant in both sources is preserved). Max value
  9 999 999 999.99 per column, ample for COD orders. Rounding rule: banker's rounding is **not** used; amounts are
  entered, not computed, except totals (sum of exact values). CLAUDE.md §7 amended to match.
- Revisit when: multi-currency pricing or computed taxes/fees with fractional results arrive.

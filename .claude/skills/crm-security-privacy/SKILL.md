---
name: crm-security-privacy
description: Design CRM security, access control and data privacy: authentication, RBAC/ABAC, entity-level and field-level security, record sharing by owner/team/territory, security exceptions, row-level security, audit logging, encryption, PII handling, consent, data subject requests, retention and deletion, data residency, secrets and API security. Use when the user asks about permissions, roles, who can see what, GDPR or similar compliance, audit trails, protecting customer data, or securing a CRM API.
---

# CRM Security and Privacy

Customer data is among the most sensitive a company holds, and the Handbook ranks data protection and privacy as a board-level issue. Security that is bolted on later is both weaker and more disruptive; model it with the data.

## Access control model

Support four layers, evaluated together and enforced **server-side** (never only in the UI):

1. **Entity-level**: can this role create/read/update/delete/export `accounts`, `opportunities`, `cases`...
2. **Record-level (scope)**: own / team / territory / business unit / all, via ownership, team hierarchy, manager chain and sharing rules.
3. **Field-level**: hide or mask sensitive fields (national ID, compensation, margin, full phone numbers for some roles). The security model must apply everywhere data appears: UI, search, reports, exports, API, webhooks, and BI connections.
4. **Exceptions**: temporary or explicit grants to a record/set of records outside normal scope (with approver, reason, expiry). Log and review them.

Bundle permissions into **roles**; assign roles to users/groups; avoid per-user permissions. Keep the permission matrix as data (see `roles.permissions` in `crm-data-model/references/schema.sql`) and write a `can(user, action, entity, record?)` function plus a query filter builder used by every list/report endpoint. Defence in depth: database row-level security keyed to tenant (and optionally owner/team) so a missed filter cannot leak across tenants.

Start with a small role set (admin, manager, sales rep, service agent, marketing, read-only, integration/service account) and test the matrix with a table-driven test suite: for each (role, action, entity, record relation) assert allow/deny.

## Authentication and sessions
SSO (OIDC/SAML) for organisations, MFA for admins and anyone with export rights, short-lived access tokens with refresh rotation, secure cookies, session revocation, device/IP anomaly alerts, lockout/rate limiting. Service-to-service: scoped API keys or OAuth client credentials; rotate; never put secrets in the repo.

## Audit
Append-only audit log for: logins and failures, permission changes, record create/update/delete (field-level old/new for sensitive fields), exports/bulk actions, merges, consent changes, automation-initiated changes, admin configuration changes. Include actor, actor type, IP, request id. Protect from tampering (write-once storage or hash chaining for high-assurance). Provide an admin UI to answer "who changed this and why?".

## Privacy engineering

- **Data inventory**: for each field, classify (public, internal, personal, sensitive), purpose, lawful basis, retention, who can see it. Keep it with the data dictionary.
- **Minimise**: collect only what a process step needs (also better data quality).
- **Provenance and consent**: store source of every personal record and consent evidence (see `crm-marketing-campaigns`). The Handbook's research found that few firms stored the source of customer data consistently or had clear data-quality standards; do better by default.
- **Data subject requests** (access/export, rectification, erasure, restriction, objection): implement as workflows with identity verification, a deadline timer, and a checklist across systems (CRM, messaging providers, warehouse, backups policy). Erasure = delete or irreversibly anonymise personal fields while preserving aggregate/financial records you must retain; keep a minimal suppression record (hashed identifier) so the person is not re-imported or re-messaged.
- **Retention**: per entity and purpose (e.g., inactive leads purged after N months, closed cases anonymised after N years); automate with scheduled jobs and a dry-run report.
- **Cross-border and residency**: ask where customers live and where data may be stored; keep region as a tenant attribute if needed; check provider locations.
- **Sharing data with third parties** (carriers, payment providers, other businesses, shared blacklists): need a documented basis and contract; send the minimum; never publish customer blacklists across companies without legal review.
- Regulations differ by country and change; say so, state assumptions, and recommend the user's counsel/DPO confirm requirements. Do not claim legal compliance.

## Application security checklist

Input validation and output encoding; parameterised queries; CSRF protection; strict CORS; object-level authorization on every endpoint (prevent IDOR by checking record scope, not just authentication); pagination and rate limits on search/export; file-upload scanning; signed webhook verification; secrets in a vault; dependency scanning; encryption in transit (TLS) and at rest, with field-level encryption for the most sensitive values; backups encrypted and restore-tested; log scrubbing (no tokens or full PII in logs); least-privilege DB users; separate environments (production, development, test) with **no production PII in lower environments** unless masked.

## Anti-patterns

- Open-by-default visibility with "we trust everyone" (works until the first departing salesperson exports the book of business). Export rights are a separate, audited permission.
- Hiding fields only in the frontend.
- Reports and BI connections that bypass the security model.
- Shared admin accounts; shared integration keys across systems.
- Storing full card data (use a payment provider/tokenisation; never store card numbers or CVV).

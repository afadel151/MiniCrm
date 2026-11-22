# ADR-0006: Database role model — powers come from roles, never from session settings

- Status: **Proposed** (Phase 2 gate) — driven by the 2026-11-20 security review (docs/02-data/reviews/2026-11-20-phase2-review.md)
- Context: the first schemas used ONE runtime role (`<db>_app`) for every caller and granted extra powers through
  session settings the role can set itself (`app.platform_role='web_master'`, `app.user_id` for clients). The SQL
  review reproduced: staff self-reviews, forged ratings/badges, web-master takeover by `set_config`, client rewriting
  merchant messages, any API session flipping `global_score_visible`, cross-tenant outbox forgery.
- Decision:
  | Role | Who connects | Powers |
  |---|---|---|
  | `<db>_migrator` | migration job | owner, BYPASSRLS; never used at runtime |
  | `<db>_app` | tenant-facing API | tenant tables under RLS; INSERT own-tenant outbox rows; read `app.tenants`; no inbox, no cross-tenant claim functions |
  | `<db>_worker` | consumers, outbox relay, schedulers, scanners | inbox, outbox relay (cross-tenant SELECT/UPDATE), read models, `app.tenants` writes (version-guarded), claim functions, platform events; still NOBYPASSRLS and sets the tenant per event |
  | `<db>_admin` | web-master console endpoints only | explicit admin policies/functions; separate credentials, separate connection pool |
  | `<db>_<extra>` | declared per service in `Database/roles.conf` (e.g. `presence_public`, `messaging_client`, `scoring_portal`) | only the grants/policies written `TO` that role |
- Rules:
  1. A policy that widens access is written `TO <specific role>`, never keyed on a setting.
  2. Settings (`app.business_id`, `app.user_id`) only **narrow** access (which tenant, which client) and protect
     against bugs; they are not authentication. The app sets them from the validated token.
  3. Every SECURITY DEFINER function revokes EXECUTE from PUBLIC and grants it to the one role that needs it.
  4. Bootstrap always creates `_app`, `_worker`, `_admin` and re-asserts NOBYPASSRLS/NOSUPERUSER on every run.
  5. Each service's T-tests assert the role matrix (what each role can and cannot do).
- Consequences: more connection strings per service (pooled separately); the API cannot do worker things even
  under a bug or injection. Slightly more grant boilerplate per service.
- Revisit when: a managed provider restricts role creation (then roles map to provider users 1:1).

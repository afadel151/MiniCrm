# Phase 2 fix-round brief (one service)

Repo `/home/fadel/gitHub/MiniCrm`. You FIX one service's schema after two independent reviews. Nothing is deployed yet,
so edit `V0001__initial.sql` in place (no V0002) — keep it clean and commented.

## Read first
1. `docs/02-data/reviews/2026-11-20-phase2-review.md` — the review record. Your rows are listed in your task. Disposition
   FIX = implement; DEFAULT = implement the conservative default described, as configurable settings, and note it under
   "Open questions"; DECIDE/P3/LATER = do not implement, just make sure your doc lists it.
2. `docs/adr/0006-database-role-model.md` (NEW, binding) and the updated building blocks
   `src/BuildingBlocks/Database/sql/C0001__app_base.sql`, `C0002__outbox_inbox_audit_files.sql` (role matrix table at the top).
   What changed under you:
   - Bootstrap now always creates `<db>_app`, `<db>_worker`, `<db>_admin`; extra roles come from
     `src/Services/<Svc>/<Svc>.Infrastructure/Database/roles.conf` (one suffix per line, e.g. `client` → `<db>_client`).
   - Default privileges on schema `public` go to BOTH `_app` and `_worker`; nothing by default to `_admin` or extra roles.
     Schema `app` has NO default privileges any more (explicit matrix in C0002).
   - `app.outbox`: `_app` may only INSERT rows with `tenant_id = app.current_business_id()`; platform events (tenant NULL)
     and relay = `_worker` (or `_admin`). Any trigger of yours that inserts into the outbox runs as the caller's role.
   - `app.inbox`, `app.tenants` writes, `app.files.scan_status` = worker only. `app.files` inserts by `_app` must be `pending`.
   - `app.make_append_only` also blocks TRUNCATE and revokes from app/worker/admin; whitelisted columns go to app+worker.
   - `app.lock_partitions` revokes every non-owner grantee on partitions.
3. Your current files: migration, seed, tests, `docs/02-data/<service>.md`.

## Rules
- Powers come from roles (`CREATE POLICY ... TO <role>`), never from settings. Settings (`app.business_id`, `app.user_id`)
  only narrow. Remove any policy keyed on `app.platform_role` or similar.
- SECURITY DEFINER: pinned `search_path`, `REVOKE EXECUTE ... FROM PUBLIC`, `GRANT EXECUTE` to exactly the role that needs it.
  Cross-tenant claim/relay/scheduler functions → `_worker`. Web-master actions → `_admin`.
- Every FK between two tables that both have `business_id` is composite `(business_id, x_id)`; FKs to `app.files` use
  `(business_id, file_id) REFERENCES app.files (business_id, id)` (for SET NULL use `ON DELETE SET NULL (file_id)`).
  `docker exec -i minicrm-pg psql -U postgres -d <db> -XtA < tools/db/audit-fks.sql` must return 0 rows.
- NULL-safe CHECKs (`IS NOT DISTINCT FROM`, `coalesce(..., false)`), count-then-insert limits under
  `pg_advisory_xact_lock`, settings readers fail CLOSED (strict default when a key is missing).
- Shared vocabulary (cross-service, from the review): tenant-layer score confidence = `none | low | medium | high`;
  global label shown to merchants = `not_enough_data | low | high`; score events to tenants carry the TENANT layer only.

## Validation (mandatory)
`tools/db/bootstrap-service-db.sh <db> <Svc> [--geo] --reset` must print `OK <db>`; FK audit 0 rows. Tests must now include a
**role matrix** test: for `_app`, `_worker`, `_admin` and each extra role, assert the key allowed and refused operations
(use `SET ROLE`, expect `insufficient_privilege` / 0 rows). Add a regression test for every **V** finding of your service.

## Doc
Update `docs/02-data/<service>.md`: roles section (role → what it can do), deviations, security notes, open questions
(include your DECIDE/DEFAULT items, referencing the review row ids). Keep it ≤ 300 lines.

## Final reply (≤ 35 lines)
Rows fixed (by id), rows deferred and why, test tail (last ~12 lines), FK audit result, scaffold honesty.

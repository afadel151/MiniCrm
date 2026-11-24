#!/usr/bin/env bash
# Creates one service database with its two roles, then applies the shared building blocks and the service's
# migrations, seeds and SQL tests. LOCAL DEV ONLY (CLAUDE.md §14: no destructive SQL outside local dev).
#
# Usage: tools/db/bootstrap-service-db.sh <db_name> <ServiceDir> [--geo] [--reset]
#   db_name     identity_access | crm | orders | scoring | integrations | messaging | presence
#   ServiceDir  IdentityAccess | Crm | Orders | Scoring | Integrations | Messaging | Presence
#   --geo       also apply C0003__reference_geo.sql
#   --reset     drop and recreate the database first
# Env: PG_CONTAINER (default minicrm-pg), CONTAINER_ENGINE (default docker; podman also works)
set -euo pipefail

db="${1:?db name}"; svc="${2:?service dir}"; shift 2
geo=0; reset=0
for a in "$@"; do case "$a" in --geo) geo=1;; --reset) reset=1;; *) echo "unknown flag $a" >&2; exit 2;; esac; done

root="$(cd "$(dirname "$0")/../.." && pwd)"
container="${PG_CONTAINER:-minicrm-pg}"
psql_admin() { "${CONTAINER_ENGINE:-docker}" exec -i "$container" psql -v ON_ERROR_STOP=1 -X -q -U postgres "$@"; }
# Run a file as the migrator inside the target database (roles are cluster-wide).
psql_as() { local role="$1" file="$2"; { echo "SET ROLE ${role};"; cat "$file"; } | psql_admin -d "$db"; }

[[ "$db" =~ ^[a-z_]+$ ]] || { echo "invalid db name" >&2; exit 2; }
[[ "$svc" =~ ^[A-Za-z]+$ ]] || { echo "invalid service dir" >&2; exit 2; }

if (( reset )); then
  psql_admin -c "DROP DATABASE IF EXISTS ${db} WITH (FORCE);"
fi

# Standard roles (ADR-0006): migrator (owner, BYPASSRLS), app (API), worker (consumers/relay/jobs), admin (console).
# Attributes are RE-ASSERTED on every run so a drifted role can never keep BYPASSRLS or SUPERUSER.
ensure_role() {  # name bypassrls(0/1)
  local r="$1" bypass="NOBYPASSRLS"; [[ "$2" == 1 ]] && bypass="BYPASSRLS"
  psql_admin -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${r}') THEN CREATE ROLE ${r} LOGIN PASSWORD 'devonly_${r}'; END IF; END \$\$;"
  psql_admin -c "ALTER ROLE ${r} LOGIN ${bypass} NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;"
}
ensure_role "${db}_migrator" 1
for r in app worker admin; do ensure_role "${db}_${r}" 0; done
# Extra runtime roles declared by the service (one role suffix per line in Database/roles.conf, e.g. "engine"
# -> <db>_engine). Always LOGIN NOBYPASSRLS non-owner; the service migration grants them what they need.
roles_conf="$root/src/Services/$svc/$svc.Infrastructure/Database/roles.conf"
if [[ -f "$roles_conf" ]]; then
  # Read the config on fd 3, not stdin: ensure_role's `docker exec -i` would otherwise inherit fd 0 == this
  # file and steal bytes from it, silently dropping every line after the first (caught only by checking the
  # actual role list after a bootstrap on a FRESH cluster — a stray manually-created role can mask this).
  while IFS= read -r suffix <&3; do
    [[ -z "$suffix" || "$suffix" == \#* ]] && continue
    [[ "$suffix" =~ ^[a-z_]+$ ]] || { echo "invalid role suffix '$suffix' in roles.conf" >&2; exit 2; }
    ensure_role "${db}_${suffix}" 0
  done 3< "$roles_conf"
fi
psql_admin -tc "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1 || psql_admin -c "CREATE DATABASE ${db} OWNER ${db}_migrator;"
psql_admin -d "$db" -c "REVOKE ALL ON DATABASE ${db} FROM PUBLIC; GRANT CONNECT ON DATABASE ${db} TO ${db}_app, ${db}_worker, ${db}_admin; REVOKE CREATE ON SCHEMA public FROM PUBLIC; ALTER SCHEMA public OWNER TO ${db}_migrator;"

bb="$root/src/BuildingBlocks/Database/sql"
files=("$bb/C0001__app_base.sql" "$bb/C0002__outbox_inbox_audit_files.sql")
(( geo )) && files+=("$bb/C0003__reference_geo.sql")
dbdir="$root/src/Services/$svc/$svc.Infrastructure/Database"
shopt -s nullglob
files+=("$dbdir"/migrations/V*.sql "$dbdir"/seed/*.sql)

for f in "${files[@]}"; do
  echo "apply  ${f#$root/}"
  psql_as "${db}_migrator" "$f"
done

for t in "$dbdir"/tests/*.sql; do
  echo "test   ${t#$root/}"
  psql_admin -d "$db" < "$t"
done
echo "OK $db"

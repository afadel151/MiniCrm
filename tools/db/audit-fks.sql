-- audit-fks.sql — must return 0 rows (00-conventions.md §4, fix-brief validation step).
-- Finds any foreign key, inside this database, from a table with a business_id column to another table that
-- also has a business_id column, where the FK is NOT composite on (business_id, ...). A single-column FK
-- between two tenant tables lets tenant B attach its row to tenant A's parent if it learns the id (RLS checks
-- the child's OWN business_id, not the parent's, so this bypasses isolation entirely).
-- Usage: docker exec -i minicrm-pg psql -U postgres -d <db> -XtA < tools/db/audit-fks.sql

WITH fk AS (
  SELECT
    con.oid AS constraint_oid,
    con.conname,
    con.conrelid::regclass::text AS child_table,
    con.confrelid::regclass::text AS parent_table,
    array_agg(att.attname ORDER BY k.ord) AS child_columns
  FROM pg_constraint con
  JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS k (attnum, ord) ON true
  JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = k.attnum
  WHERE con.contype = 'f'
    AND con.connamespace = 'public'::regnamespace
  GROUP BY con.oid, con.conname, con.conrelid, con.confrelid
),
tenant_tables AS (
  SELECT c.oid::regclass::text AS table_name
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'business_id' AND NOT a.attisdropped
  WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
)
SELECT fk.conname, fk.child_table, fk.parent_table, fk.child_columns
FROM fk
JOIN tenant_tables ct ON ct.table_name = fk.child_table
JOIN tenant_tables pt ON pt.table_name = fk.parent_table
WHERE NOT ('business_id' = ANY (fk.child_columns));

-- C0003__reference_geo.sql — versioned wilaya/commune reference data (ADR-0005; CLAUDE.md §7: "69 wilayas and
-- 1 541 communes since the November 2025 reform ... never hard-code the list").
-- Applied only with --geo, to services that store addresses. Carrier code maps live in `integrations`, not here.
--
-- Natural key (dataset_version, code), not a surrogate uuid: a service address column is
-- `(wilaya_dataset_version, wilaya_code) REFERENCES ref.wilayas (dataset_version, code)`, so a reform bump is a
-- new dataset_version row set, old addresses keep resolving under their original version, and the FK is a plain
-- composite PK reference rather than needing a partial-unique-index workaround.
--
-- NO ROWS ARE SEEDED BY THIS FILE. Fabricating official administrative codes/names would be exactly the kind of
-- unverified guess CLAUDE.md §8 rule 5 forbids ("never present a guess as verified"). Seed data must come from an
-- authoritative source (e.g. the official ANDI/interior-ministry gazette for the 2025 reform) as a separate,
-- reviewed seed migration — tracked as an open item, not invented here. Until seeded, any FK into this table
-- will correctly refuse every row (there is nothing to reference), which is why every consuming column must be
-- nullable: "no address on file yet" has to stay representable.

CREATE SCHEMA IF NOT EXISTS ref;

CREATE TABLE IF NOT EXISTS ref.datasets (
  version int PRIMARY KEY,
  effective_from date NOT NULL,
  description text NOT NULL -- e.g. 'pre-2025 reform (58 wilayas)', 'post-2025 reform (69 wilayas)'
);

CREATE TABLE IF NOT EXISTS ref.wilayas (
  dataset_version int NOT NULL REFERENCES ref.datasets (version),
  code text NOT NULL, -- official wilaya code, as a string (some carriers still use old codes)
  name_ar text NOT NULL,
  name_fr text NOT NULL,
  PRIMARY KEY (dataset_version, code)
);

CREATE TABLE IF NOT EXISTS ref.communes (
  dataset_version int NOT NULL,
  code text NOT NULL,
  wilaya_code text NOT NULL,
  name_ar text NOT NULL,
  name_fr text NOT NULL,
  PRIMARY KEY (dataset_version, code),
  FOREIGN KEY (dataset_version, wilaya_code) REFERENCES ref.wilayas (dataset_version, code)
);
CREATE INDEX IF NOT EXISTS ix_communes_wilaya ON ref.communes (dataset_version, wilaya_code);
-- Superset of the PK, so a service can FK "address.(dataset_version, commune_code, wilaya_code)" declaratively
-- and get "this commune really belongs to this wilaya" enforced by the database (crm R2).
CREATE UNIQUE INDEX IF NOT EXISTS ux_communes_code_wilaya ON ref.communes (dataset_version, code, wilaya_code);

DO $$
DECLARE db text := current_database();
BEGIN
  -- Read-only reference data for every runtime role, including extras (addresses are looked up everywhere).
  EXECUTE format('GRANT USAGE ON SCHEMA ref TO %I, %I, %I', db || '_app', db || '_worker', db || '_admin');
  EXECUTE format('GRANT SELECT ON ref.datasets, ref.wilayas, ref.communes TO %I, %I, %I',
    db || '_app', db || '_worker', db || '_admin');
END;
$$;

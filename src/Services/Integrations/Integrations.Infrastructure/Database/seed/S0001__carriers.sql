-- S0001__carriers.sql — carrier names only (doc open Q2: "nothing seeded beyond carrier names; mappings and geo
-- codes load from sandbox-verified sources" — not invented here).

INSERT INTO carriers (code, name, api_family) VALUES
  ('yalidine', 'Yalidine', 'yalidine'),
  ('zr_express', 'ZR Express', 'zr_express'),
  ('maystro', 'Maystro Delivery', 'maystro'),
  ('procolis', 'Procolis', 'procolis'),
  ('ecotrack_generic', 'Ecotrack-hosted carrier', 'ecotrack');

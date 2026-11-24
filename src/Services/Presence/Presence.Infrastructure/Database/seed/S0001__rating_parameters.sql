-- S0001__rating_parameters.sql — initial Bayesian rating constants. [Guessing] — no production data yet to
-- derive the platform mean from; refresh_rating_parameters() recomputes m_mean once reviews exist.

INSERT INTO rating_parameters (key, c_constant, m_mean) VALUES ('current', 10, 4.0);

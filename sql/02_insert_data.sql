-- ============================================================
-- Tariff-Aware Landed Cost Optimizer
-- 02_insert_data.sql
-- Loads all master data
-- ============================================================

-- Suppliers (5 global suppliers across 4 countries)
INSERT INTO suppliers (name, country_code, reliability_score) VALUES
('ShanghaiTech Manufacturing', 'CHN', 0.85),
('VietCraft Industries',       'VNM', 0.90),
('MexiParts SA',               'MEX', 0.92),
('IndiCore Supplies',          'IND', 0.88),
('DomesticMFG Corp',           'USA', 0.97);

-- Products (6 SKUs across 3 categories with real USITC HS codes)
INSERT INTO products (sku, name, category, hs_heading) VALUES
('ELEC-001', 'Wireless Sensor Module',   'electronics', '8517'),
('ELEC-002', 'Power Control Board',      'electronics', '8537'),
('MECH-001', 'Precision Bearing Set',    'mechanical',  '8482'),
('MECH-002', 'Aluminium Mounting Frame', 'mechanical',  '7616'),
('TEXT-001', 'Industrial Safety Gloves', 'textiles',    '6116'),
('TEXT-002', 'Protective Workwear Set',  'textiles',    '6211');

-- Supplier offers in LOCAL currency (FX conversion happens in the engine)
INSERT INTO supplier_offers
(supplier_id, product_id, unit_price_local, freight_cost_local, lead_time_days, currency_code) VALUES
(1, 1, 90.85,    8.71,   28, 'CNY'),  -- ShanghaiTech ELEC-001
(1, 2, 326.70,   18.15,  28, 'CNY'),  -- ShanghaiTech ELEC-002
(1, 3, 63.50,    7.26,   30, 'CNY'),  -- ShanghaiTech MECH-001
(2, 1, 353846,   38462,  21, 'VND'),  -- VietCraft ELEC-001
(2, 4, 974359,   76923,  25, 'VND'),  -- VietCraft MECH-002
(2, 5, 158974,   20513,  22, 'VND'),  -- VietCraft TEXT-001
(3, 3, 191.92,   12.12,  10, 'MXN'),  -- MexiParts MECH-001
(3, 4, 828.28,   36.36,  12, 'MXN'),  -- MexiParts MECH-002
(3, 6, 565.66,   40.40,  14, 'MXN'),  -- MexiParts TEXT-002
(4, 1, 1000.84,  151.26, 35, 'INR'),  -- IndiCore ELEC-001
(4, 2, 3529.41,  184.87, 38, 'INR'),  -- IndiCore ELEC-002
(4, 5, 487.39,   75.63,  40, 'INR'),  -- IndiCore TEXT-001
(5, 2, 68.00,    0.00,   5,  'USD'),  -- DomesticMFG ELEC-002
(5, 3, 14.00,    0.00,   3,  'USD'),  -- DomesticMFG MECH-001
(5, 6, 42.00,    0.00,   2,  'USD');  -- DomesticMFG TEXT-002

-- FX rates (hardcoded baseline - updated daily by n8n workflow)
INSERT INTO fx_rates (currency_code, rate_to_usd) VALUES
('USD', 1.000000),
('CNY', 0.137800),
('VND', 0.000039),
('MXN', 0.049500),
('INR', 0.011900);

-- USITC HTS 2026 MFN base duty rates
-- Source: hts.usitc.gov (public domain)
INSERT INTO hs_base_rates
(hs_heading, product_category, description, mfn_base_rate) VALUES
('8517', 'electronics', 'Wireless transmission apparatus - 8517.62.00',          0.00),
('8537', 'electronics', 'Electric control boards/panels <1000V - 8537.10.91',    2.70),
('8482', 'mechanical',  'Ball and roller bearings - 8482.10.50',                  9.00),
('7616', 'mechanical',  'Articles of aluminium - other - 7616.99.51',            2.50),
('6116', 'textiles',    'Knitted gloves - coated synthetic fiber - 6116.10.55',  13.20),
('6211', 'textiles',    'Protective workwear - man-made fibers - 6211.33.90',    16.00);

-- Country tariff overlays (Section 301, USMCA etc.)
INSERT INTO country_tariff_overlay
(country_code, product_category, overlay_rate, note) VALUES
('CHN', 'electronics', 25.00, 'Section 301 additional duty'),
('CHN', 'mechanical',  25.00, 'Section 301 additional duty'),
('CHN', 'textiles',     7.50, 'Section 301 additional duty'),
('VNM', 'electronics',  0.00, 'No additional overlay'),
('VNM', 'mechanical',   0.00, 'No additional overlay'),
('VNM', 'textiles',     0.00, 'No additional overlay'),
('MEX', 'electronics',  0.00, 'USMCA - duty free'),
('MEX', 'mechanical',   0.00, 'USMCA - duty free'),
('MEX', 'textiles',     0.00, 'USMCA - duty free'),
('IND', 'electronics',  0.00, 'No additional overlay'),
('IND', 'mechanical',   0.00, 'No additional overlay'),
('IND', 'textiles',     0.00, 'No additional overlay'),
('USA', 'electronics',  0.00, 'Domestic - no import duty'),
('USA', 'mechanical',   0.00, 'Domestic - no import duty'),
('USA', 'textiles',     0.00, 'Domestic - no import duty');

-- Save baseline scenario for simulation resets
INSERT INTO tariff_scenarios (scenario_name, country_code, product_category, overlay_rate)
SELECT 'baseline_2026', country_code, product_category, overlay_rate
FROM country_tariff_overlay
WHERE country_code = 'CHN';

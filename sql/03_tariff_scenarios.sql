-- ============================================================
-- Tariff-Aware Landed Cost Optimizer
-- 03_tariff_scenarios.sql
-- Scenario simulation and utility queries
-- ============================================================

-- ── CHECK CURRENT STATE ──────────────────────────────────────

-- View current tariff rates for all countries
SELECT country_code, product_category, overlay_rate, note
FROM country_tariff_overlay
ORDER BY country_code, product_category;

-- View current cheapest supplier per SKU
SELECT
    p.sku,
    p.name AS product,
    s.name AS cheapest_supplier,
    s.country_code,
    r.total_landed_cost_usd,
    r.computed_at
FROM landed_cost_results r
JOIN products p ON p.id = r.product_id
JOIN suppliers s ON s.id = r.supplier_id
WHERE r.is_cheapest_landed = true
ORDER BY p.sku;

-- View full landed cost breakdown for all suppliers
SELECT
    p.sku,
    s.name AS supplier,
    s.country_code,
    r.fx_adjusted_price_usd AS unit_price,
    r.freight_cost_usd AS freight,
    r.tariff_cost_usd AS duty,
    r.lead_time_risk_usd AS lead_time_risk,
    r.total_landed_cost_usd AS total,
    r.is_cheapest_sticker,
    r.is_cheapest_landed
FROM landed_cost_results r
JOIN products p ON p.id = r.product_id
JOIN suppliers s ON s.id = r.supplier_id
ORDER BY p.sku, r.total_landed_cost_usd;

-- View all sourcing alerts
SELECT * FROM sourcing_alerts ORDER BY detected_at DESC;


-- ── SCENARIO SIMULATION ──────────────────────────────────────

-- SCENARIO 1: Reduce China Section 301 duties to 10%
-- (Models potential US-China trade normalization)
UPDATE country_tariff_overlay
SET overlay_rate = 10.00
WHERE country_code = 'CHN';

-- SCENARIO 2: Increase China electronics duty to 35%
-- (Models escalated trade war scenario)
UPDATE country_tariff_overlay
SET overlay_rate = 35.00
WHERE country_code = 'CHN'
AND product_category = 'electronics';

-- SCENARIO 3: Add 15% duty on Vietnam electronics
-- (Models Section 301 extension scenario)
UPDATE country_tariff_overlay
SET overlay_rate = 15.00
WHERE country_code = 'VNM'
AND product_category = 'electronics';

-- SCENARIO 4: Remove all China overlays (full normalization)
UPDATE country_tariff_overlay
SET overlay_rate = 0.00
WHERE country_code = 'CHN';


-- ── RESTORE BASELINE ─────────────────────────────────────────

-- Restore all China overlays to 2026 baseline
UPDATE country_tariff_overlay c
SET overlay_rate = s.overlay_rate
FROM tariff_scenarios s
WHERE s.scenario_name = 'baseline_2026'
AND c.country_code = s.country_code
AND c.product_category = s.product_category;

-- Verify baseline restored
SELECT country_code, product_category, overlay_rate
FROM country_tariff_overlay
WHERE country_code = 'CHN';


-- ── RESET TO CLEAN STATE ─────────────────────────────────────

-- Clear computed results and alerts for a fresh start
TRUNCATE landed_cost_results;
TRUNCATE previous_cheapest;
TRUNCATE sourcing_alerts;

-- Restore baseline tariff
UPDATE country_tariff_overlay c
SET overlay_rate = s.overlay_rate
FROM tariff_scenarios s
WHERE s.scenario_name = 'baseline_2026'
AND c.country_code = s.country_code
AND c.product_category = s.product_category;


-- ── USEFUL ANALYTICS ─────────────────────────────────────────

-- Compare sticker price vs landed cost ranking
SELECT
    p.sku,
    p.name,
    sticker.name AS cheapest_sticker,
    sticker.country_code AS sticker_country,
    sticker.total_landed_cost_usd AS sticker_cost,
    landed.name AS cheapest_landed,
    landed.country_code AS landed_country,
    landed.total_landed_cost_usd AS landed_cost,
    CASE WHEN sticker.name != landed.name THEN 'YES - MISLEADING' ELSE 'No' END AS sticker_misleads
FROM (
    SELECT r.product_id, s.name, s.country_code, r.total_landed_cost_usd
    FROM landed_cost_results r JOIN suppliers s ON s.id = r.supplier_id
    WHERE r.is_cheapest_sticker = true
) sticker
JOIN (
    SELECT r.product_id, s.name, s.country_code, r.total_landed_cost_usd
    FROM landed_cost_results r JOIN suppliers s ON s.id = r.supplier_id
    WHERE r.is_cheapest_landed = true
) landed ON sticker.product_id = landed.product_id
JOIN products p ON p.id = sticker.product_id
ORDER BY p.sku;

-- Summary: how many SKUs have misleading sticker prices
SELECT
    COUNT(*) FILTER (WHERE is_cheapest_sticker = true AND is_cheapest_landed = false) AS sticker_traps,
    COUNT(DISTINCT product_id) AS total_skus,
    COUNT(*) AS total_offers
FROM landed_cost_results;

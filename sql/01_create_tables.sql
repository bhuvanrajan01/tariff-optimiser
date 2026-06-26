-- ============================================================
-- Tariff-Aware Landed Cost Optimizer
-- 01_create_tables.sql
-- Creates all database tables
-- ============================================================

-- Suppliers master table
CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    country_code VARCHAR(3),
    reliability_score NUMERIC(3,2)
);

-- Products master table with HS codes
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50),
    name VARCHAR(100),
    category VARCHAR(50),
    hs_heading VARCHAR(10)
);

-- Supplier offers in local currency
CREATE TABLE supplier_offers (
    id SERIAL PRIMARY KEY,
    supplier_id INT REFERENCES suppliers(id),
    product_id INT REFERENCES products(id),
    unit_price_local NUMERIC(10,2),
    freight_cost_local NUMERIC(10,2),
    lead_time_days INT,
    currency_code VARCHAR(3)
);

-- Live FX rates (updated daily by n8n workflow)
CREATE TABLE fx_rates (
    id SERIAL PRIMARY KEY,
    currency_code VARCHAR(3),
    rate_to_usd NUMERIC(10,6),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- USITC HTS 2026 MFN base duty rates
CREATE TABLE hs_base_rates (
    id SERIAL PRIMARY KEY,
    hs_heading VARCHAR(10),
    product_category VARCHAR(50),
    description VARCHAR(150),
    mfn_base_rate NUMERIC(5,2),
    source VARCHAR(100) DEFAULT 'USITC HTS 2026'
);

-- Country policy overlays (Section 301, USMCA etc.)
CREATE TABLE country_tariff_overlay (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(3),
    product_category VARCHAR(50),
    overlay_rate NUMERIC(5,2),
    note VARCHAR(150)
);

-- Computed landed cost results (refreshed daily)
CREATE TABLE landed_cost_results (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    supplier_id INT REFERENCES suppliers(id),
    unit_price_usd NUMERIC(10,2),
    freight_cost_usd NUMERIC(10,2),
    tariff_cost_usd NUMERIC(10,2),
    fx_adjusted_price_usd NUMERIC(10,2),
    lead_time_risk_usd NUMERIC(10,2),
    total_landed_cost_usd NUMERIC(10,2),
    is_cheapest_sticker BOOLEAN,
    is_cheapest_landed BOOLEAN,
    computed_at TIMESTAMP DEFAULT NOW()
);

-- Snapshot of previous cheapest suppliers for change detection
CREATE TABLE previous_cheapest (
    sku VARCHAR(20) PRIMARY KEY,
    supplier_name VARCHAR(100),
    country_code VARCHAR(3),
    total_landed_cost NUMERIC(10,4),
    recorded_at TIMESTAMP DEFAULT NOW()
);

-- Audit trail of detected supplier switches
CREATE TABLE sourcing_alerts (
    id SERIAL PRIMARY KEY,
    alert_type VARCHAR(50),
    sku VARCHAR(20),
    previous_supplier VARCHAR(100),
    new_supplier VARCHAR(100),
    previous_country VARCHAR(3),
    new_country VARCHAR(3),
    new_landed_cost NUMERIC(10,4),
    message TEXT,
    detected_at TIMESTAMP DEFAULT NOW()
);

-- Saved tariff scenarios for simulation
CREATE TABLE tariff_scenarios (
    id SERIAL PRIMARY KEY,
    scenario_name VARCHAR(100),
    country_code VARCHAR(3),
    product_category VARCHAR(50),
    overlay_rate NUMERIC(5,2),
    created_at TIMESTAMP DEFAULT NOW()
);

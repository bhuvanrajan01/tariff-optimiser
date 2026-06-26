// ============================================================
// Tariff-Aware Landed Cost Optimizer
// landed_cost_engine.js
// n8n Code Node - Computes 4-component landed cost
// Place this in the "Landed cost engine" Code node in n8n
// ============================================================

// Daily holding rate: 18% annually = 0.0005 per day
// Standard inventory carrying cost used in supply chain literature
const DAILY_HOLDING_RATE = 0.0005;

// Get all rows from the previous Postgres node
const offers = items.map(item => item.json);

// ── COMPONENT CALCULATION ────────────────────────────────────
// For each supplier-SKU offer, compute 4-component landed cost:
//
// Component 1: FX-adjusted unit price
//   unit_price_local × fx_rate → price in real USD
//
// Component 2: Freight cost in USD
//   freight_cost_local × fx_rate → shipping in USD
//
// Component 3: Duty cost
//   fx_adjusted_price × (base_tariff + overlay) / 100
//   Two-layer tariff model: MFN base rate + country policy overlay
//
// Component 4: Lead-time risk
//   fx_adjusted_price × 0.0005 × lead_time_days
//   Carrying cost penalty for longer supply chains

const results = offers.map(row => {
  const unitPrice   = parseFloat(row.unit_price_local);
  const fxRate      = parseFloat(row.rate_to_usd);
  const freight     = parseFloat(row.freight_cost_local) * fxRate;
  const baseRate    = parseFloat(row.mfn_base_rate);
  const overlayRate = parseFloat(row.overlay_rate);
  const leadTime    = parseInt(row.lead_time_days);

  // Step 1: FX-adjusted price (convert local currency to USD)
  const fxAdjustedPrice = unitPrice * fxRate;

  // Step 2: Duty cost (applied to FX-adjusted price)
  // Domestic suppliers (USA) pay no import duty
  const totalTariffRate = row.country_code === 'USA'
    ? 0
    : (baseRate + overlayRate) / 100;
  const dutyCost = fxAdjustedPrice * totalTariffRate;

  // Step 3: Lead-time risk (carrying cost penalty)
  const leadTimeRisk = fxAdjustedPrice * DAILY_HOLDING_RATE * leadTime;

  // Step 4: Total landed cost
  const totalLandedCost = fxAdjustedPrice + freight + dutyCost + leadTimeRisk;

  return {
    sku:                row.sku,
    product_name:       row.product_name,
    supplier_name:      row.supplier_name,
    country_code:       row.country_code,
    sticker_price_usd:  parseFloat((unitPrice * fxRate).toFixed(4)),
    fx_adjusted_price:  parseFloat(fxAdjustedPrice.toFixed(4)),
    freight_cost_usd:   parseFloat(freight.toFixed(4)),
    duty_cost_usd:      parseFloat(dutyCost.toFixed(4)),
    lead_time_risk_usd: parseFloat(leadTimeRisk.toFixed(4)),
    total_landed_cost:  parseFloat(totalLandedCost.toFixed(4)),
    lead_time_days:     leadTime,
    tariff_rate_pct:    baseRate + overlayRate
  };
});

// ── RANKING ──────────────────────────────────────────────────
// For each SKU, identify:
// - Cheapest by sticker price (naive procurement)
// - Cheapest by landed cost (true economic cost)
// - Whether sticker price misleads (they differ)

const finalResults = results.map(row => {
  const skuOffers = results.filter(r => r.sku === row.sku);

  const cheapestSticker = skuOffers.reduce((a, b) =>
    a.sticker_price_usd < b.sticker_price_usd ? a : b);

  const cheapestLanded = skuOffers.reduce((a, b) =>
    a.total_landed_cost < b.total_landed_cost ? a : b);

  return {
    ...row,
    is_cheapest_sticker: row.supplier_name === cheapestSticker.supplier_name,
    is_cheapest_landed:  row.supplier_name === cheapestLanded.supplier_name,
    sticker_misleads:    cheapestSticker.supplier_name !== cheapestLanded.supplier_name
  };
});

return finalResults.map(r => ({ json: r }));

// ============================================================
// Tariff-Aware Landed Cost Optimizer
// fx_transform.js
// n8n Code Node - Transforms live FX rates from ExchangeRate-API
// Place this in the "FX Transform" Code node in n8n
// ============================================================

// Input: full currency list from ExchangeRate-API (open.er-api.com)
// Output: 4 clean rows (CNY, INR, MXN, VND) with rates inverted
//
// The API gives "1 USD = X currency"
// We need "1 currency = Y USD"
// So we invert: rate_to_usd = 1 / (USD→currency rate)
//
// Example: 1 USD = 6.81 CNY → 1 CNY = 1/6.81 = 0.1468 USD
//
// Note: VND is not covered by ECB reference rates (Frankfurter)
// ExchangeRate-API was selected for its 166-currency coverage
// including VND alongside CNY, INR, and MXN

const apiData = items[0].json;
const rates = apiData.rates;
const apiDate = apiData.time_last_update_utc;

// The 4 currencies our suppliers price in
const wanted = ['CNY', 'INR', 'MXN', 'VND'];

// 8 decimal places for VND precision (rate ~0.000038)
const converted = wanted.map(code => ({
  json: {
    currency_code: code,
    rate_to_usd: parseFloat((1 / rates[code]).toFixed(8)),
    source_date: apiDate
  }
}));

return converted;

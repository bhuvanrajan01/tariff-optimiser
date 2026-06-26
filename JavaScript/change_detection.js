// ============================================================
// Tariff-Aware Landed Cost Optimizer
// change_detection.js
// n8n Code Node - Detects supplier switches after each run
// Place this in the "Change detection" Code node in n8n
//
// Input: output from Merge node (landed cost results joined
//        with previous_cheapest snapshot via SQL)
// Output: SUPPLIER_SWITCH alerts or NO_CHANGE signal
// ============================================================

// Each item has both new landed cost AND previous cheapest
// merged by SKU from the Merge node
const allItems = $input.all().map(i => i.json);

const alerts = [];

allItems.forEach(row => {
  // Only check the cheapest landed supplier per SKU
  if (row.is_cheapest_landed !== true) return;

  const newSupplier  = row.supplier_name;
  const prevSupplier = row.previous_cheapest_supplier;

  // Flag when the optimal supplier has changed
  if (prevSupplier && newSupplier !== prevSupplier) {
    alerts.push({
      json: {
        alert_type:        'SUPPLIER_SWITCH',
        sku:               row.sku,
        previous_supplier: prevSupplier,
        previous_country:  row.previous_country,
        new_supplier:      newSupplier,
        new_country:       row.country_code,
        new_landed_cost:   row.total_landed_cost,
        message:           `SOURCING ALERT: ${row.sku} — Switch from ${prevSupplier} (${row.previous_country}) to ${newSupplier} (${row.country_code}) at $${row.total_landed_cost} landed cost`,
        detected_at:       new Date().toISOString()
      }
    });
  }
});

// Return NO_CHANGE if nothing switched
if (alerts.length === 0) {
  return [{
    json: {
      alert_type:    'NO_CHANGE',
      message:       'No supplier switches detected. Current recommendations unchanged.',
      checked_at:    new Date().toISOString(),
      skus_checked:  allItems.filter(r => r.is_cheapest_landed === true).length
    }
  }];
}

return alerts;

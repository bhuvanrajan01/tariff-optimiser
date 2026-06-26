# Tariff-Aware Landed Cost Optimizer

I built this because I kept seeing the same mistake in procurement case studies — companies picking suppliers based on unit price and ignoring everything that happens between the factory gate and the warehouse door. Duties, freight, currency, lead-time risk. None of it shows up on the quote sheet.

This project automates the full cost picture. It pulls real U.S. tariff rates, live exchange rates, and supplier data, runs them through a landed cost model, and flags when a policy change flips the optimal sourcing decision. The whole thing runs on a schedule and emails you when something changes.

No paid APIs. No cloud subscription. Runs entirely on your laptop for $0.

---

## Why I built this

In 2026, tariffs are not a background variable — they are the variable. An 82% majority of supply chain leaders say their operations are affected by new tariffs (McKinsey, Dec 2025). Yet most procurement tools still rank suppliers by sticker price.

I wanted to build something that quantifies what tariff exposure actually costs, not just in theory but per SKU, per supplier, per day. And then automate the decision loop around it so a procurement team doesn't need to run spreadsheets every time a policy changes.

---

## What it actually found

The clearest example is MECH-001, a precision bearing set sourced from three countries:

| Supplier | Country | Sticker Price | Effective Tariff | Landed Cost |
|---|---|---|---|---|
| ShanghaiTech Manufacturing | China | $8.75 | 34% (9% base + 25% Section 301) | $12.86 |
| MexiParts SA | Mexico | $9.50 | 9% (USMCA — no overlay) | **$11.00** ✓ |
| DomesticMFG Corp | USA | $14.00 | 0% | $14.02 |

China looks cheapest. China is the most expensive. The gap is $1.86 per unit — at 10,000 units a year that is $18,600 sitting invisible behind the sticker price.

The model gets more interesting when you run scenarios. Drop China's Section 301 overlay from 25% to 10% — a plausible policy shift given current trade negotiations — and China flips back to cheapest at $12.29. The system detects this automatically and sends an alert. That is the whole point: policy changes should trigger sourcing reviews without anyone having to remember to check.

---

## How it works

The pipeline runs every morning at 7am:

```
1. Fetch live FX rates from ExchangeRate-API (166 currencies, no API key needed)
2. Convert and store rates for CNY, INR, MXN, VND
3. Read all supplier offers and join with real USITC tariff data
4. Compute landed cost for each supplier-SKU combination
5. Compare against yesterday's cheapest supplier per SKU
6. If anything changed — log the alert and send an email
7. Write fresh results to the database
8. Metabase dashboard updates automatically
```

The landed cost formula has four components:

```
landed_cost = (unit_price × fx_rate)                      ← price in real USD
            + (freight × fx_rate)                          ← shipping in USD
            + (fx_price × (base_tariff + overlay) / 100)  ← duty cost
            + (fx_price × 0.0005 × lead_time_days)        ← lead-time risk
```

The lead-time risk term (0.0005/day = 18% annual holding rate) is standard inventory carrying cost theory. A supplier 35 days away ties up meaningfully more working capital than one 5 days away — the model prices that difference.

---

## The tariff model

This is the part I spent the most time getting right. Tariffs in the U.S. come in two layers and most models collapse them into one number, which loses the policy signal.

**Layer 1 — MFN base rate:** The standard duty on a product, set by its HS code. I looked up each of the six product categories directly in the USITC Harmonized Tariff Schedule 2026 (public domain, free to download). These are the rates customs actually charges.

| Product | HS Code | MFN Base Rate | Notes |
|---|---|---|---|
| Wireless Sensor Module | 8517 | 0.00% | Electronics largely duty-free |
| Power Control Board | 8537 | 2.70% | Control equipment moderate |
| Precision Bearing Set | 8482 | 9.00% | Bearings historically protected |
| Aluminium Mounting Frame | 7616 | 2.50% | Standard aluminium articles |
| Industrial Safety Gloves | 6116 | 13.20% | Textiles carry high base rates |
| Protective Workwear Set | 6211 | 16.00% | Highest base rate in the dataset |

**Layer 2 — Country overlay:** Additional duties layered on specific countries by policy. Section 301 duties on China are modeled at 25% for electronics and mechanical, 7.5% for textiles — consistent with published USTR structures. Mexico carries 0% overlay under USMCA.

Separating these two layers is what makes the scenario simulator work. You change one number in the overlay table and the entire cost ranking recalculates. That is the mechanism a trade analyst would actually use.

---

## Tech stack

| Tool | Role | Why I picked it |
|---|---|---|
| n8n | Workflow orchestration | Visual pipeline builder, self-hostable, free |
| PostgreSQL | Database | Relational model fits the joins this analysis needs |
| Docker | Environment | Reproducible setup, everything runs in containers |
| ExchangeRate-API | FX data | Free, no key, 166 currencies including VND |
| Metabase | Dashboard | Direct Postgres connection, no CSV export step |
| JavaScript | Cost logic | Native in n8n Code nodes, no separate service needed |

Everything runs in Docker on a laptop. Total cost: $0.

---

## Database design

Ten tables. The ones that matter most:

- **`hs_base_rates`** — the USITC lookup table. Source of truth for base duties.
- **`country_tariff_overlay`** — the policy layer. This is the scenario lever.
- **`supplier_offers`** — prices stored in local currency so FX conversion is real, not decorative.
- **`landed_cost_results`** — the output. Refreshed daily, keeps the last run only.
- **`previous_cheapest`** — snapshot before each run. Change detection compares against this.
- **`sourcing_alerts`** — the audit trail. Every detected supplier switch, timestamped.

---

## Setup

You need Docker Desktop and about 15GB of free disk space.

```bash
git clone https://github.com/yourusername/tariff-optimiser
cd tariff-optimiser
docker compose up -d
```

Three services start: n8n at `localhost:5678`, Postgres at `5432`, Metabase at `localhost:3000`.

First-time Metabase setup takes about 5 minutes to initialize. Connect it to Postgres using host `postgres`, database `supplychain`, user `scm`.

---

## Honest limitations

Supplier pricing is synthetic. Real supplier contract prices are proprietary — no public dataset will give you "ShanghaiTech charges $8.75 for this bearing." The model architecture is production-ready; the price data is illustrative and documented as such.

The schedule runs locally, so it only fires when Docker is open. For a real deployment this moves to a cloud VM. I noted this as a known extension rather than pretending it runs 24/7.

VND (Vietnamese dong) is not covered by the ECB reference rates that power Frankfurter, so I switched to ExchangeRate-API which covers 166 currencies. The rate source difference is documented.

---

## What I learned

Building this clarified something I had read in textbooks but not felt: the complexity in global sourcing is not in the math, it is in the data architecture. Getting the tariff model right — two layers, correct HS codes, defensible overlay rates — took longer than writing the cost engine. The engine is arithmetic. The model is judgment.

The other thing: automation without change detection is just a scheduled report. The part that makes this genuinely useful is the comparison step — knowing not just what costs are today but whether they changed from yesterday and why.

---

*Masters project — Business Analytics (Supply Chain Management)*  
*Built independently as a portfolio project, June 2026*

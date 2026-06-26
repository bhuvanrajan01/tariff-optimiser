# Tariff-Aware Landed Cost Optimizer

Sticker price is a lie. This project proves it — and automates the correction.

Built in one week as an independent post-graduation project. Masters in Business Analytics (Supply Chain Management), graduated May 2026. The system computes true landed cost across global suppliers, applies real U.S. tariff policy, detects when trade policy shifts change the optimal sourcing decision, and emails you automatically when it happens.

**Live system:** http://129.159.184.31:5678 (n8n workflow — cloud hosted, always on)

---

## The finding that motivated this

For a precision bearing set (MECH-001), three suppliers quote:

| Supplier | Country | Sticker Price | Effective Tariff | **Landed Cost** |
|---|---|---|---|---|
| ShanghaiTech | China | $8.75 | 34% (9% base + 25% Section 301) | $12.86 |
| MexiParts SA | Mexico | $9.50 | 9% (USMCA) | **$11.00 ✓** |
| DomesticMFG | USA | $14.00 | 0% | $14.02 |

China looks cheapest. China is the most expensive. The gap is $1.86/unit — $18,600/year at volume — hiding entirely behind the sticker price.

The model caught it. Automatically. Every morning.

---

## What it does

- Fetches live FX rates daily (ExchangeRate-API, 166 currencies, no key needed)
- Applies real USITC 2026 HTS tariff rates — looked up manually from the official schedule
- Computes 4-component landed cost: unit price + freight + duty + lead-time risk
- Compares yesterday's optimal supplier against today's
- Fires an email alert when a policy change flips the recommendation
- Runs on a 7am schedule with zero manual intervention

The scenario simulator is the demo centerpiece: one SQL update changes a tariff overlay, the workflow re-runs, and the system detects and alerts on the supplier switch automatically.

---

## The landed cost formula

```
landed_cost = (unit_price_local × fx_rate)
            + (freight_local × fx_rate)
            + (fx_price × (mfn_base_rate + overlay_rate) / 100)
            + (fx_price × 0.0005 × lead_time_days)
```

The `0.0005` daily holding rate (18% annual) is standard inventory carrying cost theory. A supplier 35 days away ties up more working capital than one 5 days away — the model prices that difference.

---

## Tariff model

Two layers, kept separate because that's how real trade policy works:

**Layer 1 — MFN base rate** (product-level, from USITC HTS 2026, public domain):

| Product | HS Code | Base Rate |
|---|---|---|
| Wireless Sensor Module | 8517 | 0.00% |
| Power Control Board | 8537 | 2.70% |
| Precision Bearing Set | 8482 | 9.00% |
| Aluminium Mounting Frame | 7616 | 2.50% |
| Industrial Safety Gloves | 6116 | 13.20% |
| Protective Workwear Set | 6211 | 16.00% |

**Layer 2 — Country overlay** (policy-level, scenario lever):
- China: +25% electronics/mechanical, +7.5% textiles (Section 301)
- Mexico: +0% (USMCA)
- Vietnam, India: +0% (no current overlay)

Separating these layers is what makes the scenario simulator work. Change the overlay, re-run, the system detects the impact automatically.

---

## Stack

| Tool | Role |
|---|---|
| n8n (self-hosted) | Workflow orchestration and scheduling |
| PostgreSQL 16 | Data storage |
| Docker + Compose | Environment (one command setup) |
| ExchangeRate-API | Live FX rates |
| Metabase | Procurement intelligence dashboard |
| JavaScript | Cost computation logic (n8n Code nodes) |

Total infrastructure cost: $0.

---

## Repository structure

```
tariff-optimiser/
├── docker-compose.yml          # Start everything: docker compose up -d
├── README.md
├── sql/
│   ├── 01_create_tables.sql    # All 10 tables
│   ├── 02_insert_data.sql      # Suppliers, products, tariffs, FX
│   └── 03_tariff_scenarios.sql # Scenario simulation queries
└── js/
    ├── landed_cost_engine.js   # 4-component cost model
    ├── fx_transform.js         # Rate inversion logic
    └── change_detection.js     # Supplier switch detection
```

---

## Setup

```bash
git clone https://github.com/bhuvanrajan01/tariff-optimiser
cd tariff-optimiser
docker compose up -d
```

Connect to Postgres and run `sql/01_create_tables.sql` then `sql/02_insert_data.sql`.

Import `workflow.json` into n8n at `localhost:5678`. Add your Postgres credential and SMTP credential. Publish the workflow.

That's it. The system runs itself from there.

---

## Honest limitations

Supplier prices are synthetic — real contract pricing is proprietary. The tariff and FX data are real. The model architecture is production-ready; the pricing data is illustrative and documented as such.

The schedule runs on a cloud VM (Oracle Free Tier). If you're running locally, it only fires when Docker is running.

---

*Masters in Business Analytics — Supply Chain Management (Graduated May 2026) | Independent project, June 2026*
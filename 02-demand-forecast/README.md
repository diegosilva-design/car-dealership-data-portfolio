# Case 02 · Demand forecast

**Is the dealership ordering the right cars? Forecasting demand by segment and turning it into an order plan**

| | |
|---|---|
| **Company** | Redwood Auto Group (fictional) · Dallas–Fort Worth, Texas · ~500 leads per month |
| **Problem** | Stock is ordered from last year's sales (+5%). Sedans pile up on the lot while hybrids sell out and have to be borrowed from sister stores. |
| **My role** | Trend and seasonality analysis, forecasting models, backtesting, and an inventory plan with a cost comparison |
| **Tools** | Python (pandas, statsmodels, matplotlib) · Jupyter · Chart.js dashboard |

## Executive summary

**What's changing.** Customer demand is shifting from sedans to SUVs, pickups and especially hybrids/EVs, which tripled their share from 4% to 13% in under three years. Demand also follows a clear calendar: March and December are the busiest months, October the quietest.

**Why the current rule fails.** Ordering "same month last year +5%" assumes every segment grows at the same slow pace. It under-orders what is growing fast and over-orders what is shrinking. Result: about 150 days of sedan supply against a healthy 45–60, and hybrids constantly short.

**What the forecast does better.** Four models were tested on months they had never seen (rolling backtest, 7 starting points, 3 months ahead). The most accurate model for each segment cuts the average error from **11.9% to 7.2%**. For hybrids it drops from **29% to 11%**.

**What it says for Oct – Dec 2026:**

| Segment | Leads forecast | Current rule | Difference |
|---|---|---|---|
| Hybrid / EV | **186** (likely 160–219) | 136 | **+37%** |
| Pickup | 287 | 271 | +6% |
| Compact SUV | 522 | 505 | +3% |
| Midsize SUV | 174 | 174 | — |
| Sedan / compact | **363** | 386 | **−6%** |

**From forecast to orders.** Both ordering approaches were run against the same expected demand for Oct – Dec 2026, starting from today's stock:

| | Current rule | Forecast plan |
|---|---|---|
| Cars ordered | 109 | 201 |
| Customers who find no car | 50 (25 borrowed from sister stores, 25 lost) | 0 |
| Segments ending in the healthy 45–60 days | 0 of 5 | **5 of 5** |
| Sedan supply at the end of December | 108 days | 54 days |
| Quarter cost (holding + transfers + lost gross profit) | ~$151K | **~$113K** |

**Recommendation.** Order from the forecast, not from last year: about **$38K less cost per quarter (~$150K a year)**, no lost customers, and sedan orders cut from 35 to 12. The conclusion holds as long as more than about 21% of customers who find no car would buy elsewhere; the Inventory plan page lets you test that and the holding cost.

## Walk through the case

1. 📓 [Forecast notebook](demand_forecast.ipynb): the full analysis, with code, charts and explanations
2. 📈 [Demand & Mix page](https://diegosilva-design.github.io/car-dealership-data-portfolio/01-lead-to-sale/4-measurement/demand.html): trends, seasonality, affordability, demand by area and inventory health
3. 🔮 [Forecast page](https://diegosilva-design.github.io/car-dealership-data-portfolio/01-lead-to-sale/4-measurement/forecast.html): next-quarter forecast by segment, accuracy vs the current rule
4. 📦 [Inventory plan page](https://diegosilva-design.github.io/car-dealership-data-portfolio/01-lead-to-sale/4-measurement/plan.html): recommended orders by month, where each plan leaves the lot, cost comparison and a what-if panel

## Method in brief

| Step | What and why |
|---|---|
| Forecast **leads**, not sales | Leads measure interest directly. Sales also depend on stock and the sales team; the Jul 2026 pilot raised conversion, which is not extra demand |
| Four models | Current rule (LY +5%), last year × growth, Holt-Winters, regression with trend + seasonal waves |
| Rolling backtest | Train up to month *t*, forecast *t+1…t+3*, compare with reality; repeat from Dec 2025 to Jun 2026. Error = WAPE |
| Champion per segment | Keep the most accurate model for each segment. Where the simple rule wins (Midsize SUV), keep it |
| Likely range | 10th–90th percentile of the champion's backtest errors: honest, model-agnostic uncertainty |
| Leads → sales | Store-wide pilot conversion (10.7%); per-segment rates over 3 months are too noisy |
| Order plan | End each month with 50 days of expected sales + a safety buffer for the high end of the range. Shortages: half borrowed ($400 each), half lost ($2,978 gross profit each). Holding: $400 per car per month |

## Run it yourself

```bash
py -m pip install -r requirements.txt
```

```bash
py -m jupyter nbconvert --to notebook --execute --inplace demand_forecast.ipynb
```

Re-running the notebook rewrites `data/forecast.csv`, `data/backtest.csv`, `data/forecast.js`, `data/inventory_plan.csv` and `data/inventory_plan.js`, which the Forecast and Inventory plan pages read. If the data is regenerated with `data/generate_data.ps1`, re-run the notebook afterwards.

> All data is synthetic, with trends built in on purpose. The method, not the numbers, is the point.

# Case 02 · Demand forecast

**Is the dealership ordering the right cars? Forecasting demand by segment to plan inventory**

| | |
|---|---|
| **Company** | Redwood Auto Group (fictional) · Dallas–Fort Worth, Texas · ~500 leads per month |
| **Problem** | Stock is ordered from last year's sales (+5%). Sedans pile up on the lot while hybrids sell out and have to be borrowed from sister stores. |
| **My role** | Trend and seasonality analysis, forecasting models, backtesting, and turning the forecast into planning numbers |
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

**Recommendation.** Plan hybrid stock from the forecast, not from last year: the current rule would miss about 50 hybrid customers this quarter. Slow sedan orders until stock is back in the healthy range.

## Walk through the case

1. 📓 [Forecast notebook](demand_forecast.ipynb): the full analysis, with code, charts and explanations
2. 📈 [Demand & Mix page](https://diegosilva-design.github.io/car-dealership-data-portfolio/01-lead-to-sale/4-measurement/demand.html): trends, seasonality, affordability, demand by area and inventory health
3. 🔮 [Forecast page](https://diegosilva-design.github.io/car-dealership-data-portfolio/01-lead-to-sale/4-measurement/forecast.html): next-quarter forecast by segment, accuracy vs the current rule

## Method in brief

| Step | What and why |
|---|---|
| Forecast **leads**, not sales | Leads measure interest directly. Sales also depend on stock and the sales team; the Jul 2026 pilot raised conversion, which is not extra demand |
| Four models | Current rule (LY +5%), last year × growth, Holt-Winters, regression with trend + seasonal waves |
| Rolling backtest | Train up to month *t*, forecast *t+1…t+3*, compare with reality; repeat from Dec 2025 to Jun 2026. Error = WAPE |
| Champion per segment | Keep the most accurate model for each segment. Where the simple rule wins (Midsize SUV), keep it |
| Likely range | 10th–90th percentile of the champion's backtest errors: honest, model-agnostic uncertainty |
| Leads → sales | Store-wide pilot conversion (10.7%); per-segment rates over 3 months are too noisy |

## Run it yourself

```bash
py -m pip install -r requirements.txt
```

```bash
py -m jupyter nbconvert --to notebook --execute --inplace demand_forecast.ipynb
```

Re-running the notebook rewrites `data/forecast.csv`, `data/backtest.csv` and `data/forecast.js`, which the Forecast page reads. If the data is regenerated with `data/generate_data.ps1`, re-run the notebook afterwards.

> All data is synthetic, with trends built in on purpose. The method, not the numbers, is the point.

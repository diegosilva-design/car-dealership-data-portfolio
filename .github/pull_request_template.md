## What changes

<!-- One or two lines: what this release changes and why -->

## QA checklist (staging → production)

Test locally (or on the staging preview) before merging into `main`. Merging publishes to the live site.

**Data**
- [ ] If data changed: `generate_data.ps1` was run and `leads.csv`, `targets.csv` and `data.js` are all committed
- [ ] Headline numbers in the case documents still match the dashboard (baseline 6.8% → pilot 10.7% conversion)

**Dashboard**
- [ ] Loads with no errors in the browser console
- [ ] Month, channel and salesperson filters all update every card, chart and table
- [ ] ⓘ tooltips open on hover and keyboard focus
- [ ] Table columns sort in both directions; Total row stays at the bottom
- [ ] Readable on a phone-width screen (no sideways scrolling outside tables)

**Demand & Mix page**
- [ ] Leads / Sales toggle and Area filter update every card, chart and table
- [ ] Inventory month menu updates the chart, table and note

**Forecast**
- [ ] If data changed: notebook re-run (`py -m jupyter nbconvert --to notebook --execute --inplace 02-demand-forecast/demand_forecast.ipynb`) and `forecast.*`, `backtest.csv`, `inventory_plan.*` committed
- [ ] Forecast page loads with no errors; segment menu updates the chart and note
- [ ] Inventory plan page: table sorts, sliders update the costs and notes, segment menu updates the monthly table

**Form**
- [ ] Submits in demo mode and shows the confirmation with an assigned advisor
- [ ] Validation messages appear for missing fields

**Docs**
- [ ] Links in the READMEs open the right pages
- [ ] Process diagrams render on GitHub

## After merging

- [ ] Wait ~1–2 minutes, then open the live dashboard and form and repeat a quick smoke test

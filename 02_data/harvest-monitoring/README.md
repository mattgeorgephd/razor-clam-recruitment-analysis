# 02_data/harvest-monitoring

Season-level recreational **harvest** estimates with uncertainty, copied on 2026-10-02 from the owner's companion repository `mattgeorgephd/razor-clam-harvest-monitoring` (commit `be3aded`), which reconstructs WDFW's harvest-estimation method and quantifies its uncertainty (`docs/harvest-monitoring-review.md`). These are the only harvest figures with confidence bands; the abundance (stock-assessment) estimates have no published variance (task T10).

| File | Source in that repository | Content | Coverage |
|---|---|---|---|
| `season_estimates.csv` | `02_data/consolidated/season_estimates.csv` | Beach x season effort and harvest (workbook and bias-corrected), 95% bands and CV (harvest before wastage) | Long Beach, Twin Harbors, Copalis, Mocrocks; 2007-08 to 2025-26 (Twin Harbors 2015-16 absent). 2017-18 rows are a mid-season snapshot and 2022-23 the partial season; see the review |
| `variance_decomposition.csv` | `02_data/consolidated/variance_decomposition.csv` | Variance shares by source (correction factor, imputation, CPUE transfer, interviews) per beach-season | same |
| `daily_estimates_season_beach_summary.csv` | `02_data/WDFW_RazorClam_Daily_Estimates.xlsx`, sheet `Season_Beach_Summary` | Operational season rollup: beach-days, days monitored, effort (digger trips), harvest (clams), wastage, share of effort monitored | all five beaches (Kalaloch 5 seasons), 2007-08 to 2025-26 |
| `daily_estimates_coverage_by_season.csv`, `daily_estimates_README.txt` | same workbook | Coverage by season; the workbook's own README | |

**Status in the pipeline.** Not yet used. The recruitment analysis takes `harvest_total` from the WDFW season summary (`02_data/razor-clam-season-summary-1997-2025.xlsx`), which differs from these figures for several beach-seasons (pre-2013 correction values in 2009-10 to 2011-12, mid-season snapshots in 2017-18, a zero for Twin Harbors 2024-25; task T36). Once reconciled, `08_forecast_protocol.R`'s escapement model and task T11 should use the corrected harvest with its CV.

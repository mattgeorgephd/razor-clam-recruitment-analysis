# 03_analyses/robust-reanalysis

Outputs of `./run_pipeline.sh` (`01_code/R/run_all.R`). Do not edit by hand; rerun the pipeline instead. **Start with `report.md`**, which collects the key results, every figure and every table (the `report.html` twin, with images embedded, is regenerated locally and not committed). `run_info.txt` and `sessionInfo.txt` record the last run; `run_log.txt` (not committed) accumulates run history.

## Figures (`figures/`, PNG, 300 dpi)

| File | Script | Shows |
|---|---|---|
| `fig_study_area.png` | 07 | Beaches, open-coast buoys, upwelling latitude bins |
| `fig_abundance_timeseries.png` | 07 | Pre-recruit and recruit abundance by beach, 1997–2024 (log scale) |
| `fig_predictor_timeseries.png` | 07 | The five pre-specified cohort-aligned predictors with linear trends |
| `fig_survey_timing.png` | 02 | Median survey date by beach and year |
| `fig_length_frequency.png` | 02 | Length-frequency by beach and survey timing (settler mode only in late surveys) |
| `fig_cohort_linkage.png` | 02 | log pre-recruits(t) vs log recruits(t+1) |
| `fig_null_audit.png` | 03 | Observed max\|r\| from the original 90-cell screen vs 2,000 phase-randomized surrogates |
| `fig_confirmatory_forest.png` | 04 | Pre-specified predictor effects (pooled LMM; primary, no-Kalaloch, no-trend) |
| `fig_beach_heterogeneity.png` | 04 | Beach-specific GLS-AR(1) effects |
| `fig_window_scan_pre.png`, `fig_window_scan_rec.png` | 05 | Exploratory window scan; outlined cells would pass family-wise control (none do) |
| `fig_forecast_skill.png` | 06 | Out-of-sample skill: leaky vs honest selection, persistence, carry-over |
| `fig_env_coverage.png` | 09 | Month-by-month coverage of every environmental source |
| `fig_legacy_idw_vs_homogenized.png` | 09 | Legacy station-blended beach temperature vs the homogenised regional anomaly |
| `fig_sst_homogenization.png` | 09 | Regional SST anomaly under four constructions, with +/- 2 SE |
| `fig_beuti_homogeneity.png` | 09 | May-Aug BEUTI, CUTI and their ratio at 46N/47N with the 2010/2011 product boundary |

## Tables (`tables/`, CSV)

| File | Script | Content |
|---|---|---|
| `survey_timing_by_beach.csv` | 02 | Median and SD of survey day of year; trend (days per year) |
| `prerecruit_lt30_share_by_timing.csv` | 02 | Share of pre-recruits <20 mm and <30 mm by survey-timing class |
| `cohort_linkage.csv` | 02 | r(pre_t, rec_t+1), r(pre_t, rec_t), r(rec_t, rec_t+1), r(pre_t, pre_t+1) by beach |
| `synchrony_prerecruits.csv`, `synchrony_recruits.csv` | 02 | Cross-beach correlation matrices (log abundance) |
| `abundance_summary.csv` | 02 | Median, range and SD(log) of abundance by beach and size class |
| `synchrony_summary.csv` | 02 | Mean cross-beach correlation, raw and detrended, with and without Kalaloch |
| `trends.csv` | 02 | GLS-AR(1) linear trends of log abundance and of predictors |
| `null_audit_reproduction_check.csv` | 03 | Agreement with the committed legacy correlation matrix |
| `null_audit_global.csv` | 03 | Observed vs surrogate-null count of p<0.05 cells; BH-FDR counts |
| `null_audit_by_series.csv` | 03 | Per beach × response: observed max\|r\|, null quantiles, family-wise p |
| `null_audit_all_cells.csv` | 03 | All 900 cells with r, n, p, BH q |
| `null_audit_selected_predictors.csv` | 03 | The 20 predictors chosen by the legacy models: raw, detrended, effective-n p-values |
| `confirmatory_pooled.csv` | 04 | LMM effects, LRT p, Holm and BH, under three specifications |
| `confirmatory_full_model.csv` | 04 | All five predictors in one model |
| `confirmatory_coastwide_index.csv` | 04 | Coastwide index GLS-AR(1) effects |
| `confirmatory_by_beach.csv` | 04 | Beach-specific GLS-AR(1) effects, BH q |
| `confirmatory_beuti_robustness.csv` | 04 | BEUTI and CUTI under linear/loess detrending, first differences, leave-one-out, without the most influential year, post-2003 |
| `confirmatory_predictor_correlations.csv` | 04 | Correlations among predictors and with year |
| `window_scan_summary.csv`, `window_scan_best_per_variable.csv`, `window_scan_all.csv` | 05 | Scan results with naive p, BH q, family-wise p |
| `forecast_skill_original_framework.csv`, `forecast_skill_original_by_series.csv` | 06 | Skill vs climatology for leaky/honest selection, persistence, carry-over |
| `forecast_skill_cohort_framework.csv` | 06 | Skill of trend, BEUTI and trend+BEUTI models for year-class pre-recruits |
| `forecast_2025_archived.csv` | 08 | **Archived** forecasts for survey 2025, made 2026-10-02 before the 2025 estimates were added. Do not regenerate; score against WDFW estimates (task T15) |
| `forecast_skill_fallback_counts.csv` | 06 | Forecasts that fell back to climatology because a predictor was missing |
| `env_coverage_by_station.csv`, `env_coverage_by_year.csv` | 09 | Station classes, distances, record lengths; months per year per source |
| `env_legacy_idw_station_eras.csv` | 09 | Mean offset of the legacy blended series from the homogenised anomaly by beach and dominant station |
| `env_sst_variants.csv`, `env_sst_variant_effects.csv` | 09 | Agreement among SST constructions and the SST effect under each |
| `env_sst_station_parameters.csv` | 09 | Station gains, error SDs, leave-one-station-out agreement |
| `env_beuti_step_tests.csv`, `env_beuti_latitude_periods.csv`, `env_index_annual_correlations.csv` | 09 | BEUTI/CUTI trend, 2011 step and breakpoint tests; latitude x period means; cross-index correlations |

Seeds are fixed (`SEED` in `01_code/R/00_config.R`), so surrogate-based p-values are reproducible to Monte Carlo precision (2,000 draws; ±0.01 near p = 0.05).

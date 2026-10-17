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
| `fig_growth_curve_check.png` | 02 | Modal length of the year-old cohort by survey date vs the WDFW growth curve with t0 = 0 and with t0 fitted |
| `fig_growth_increments.png` | 02 | Annual growth increments from year-class tracking (10 mm bins across consecutive surveys) vs the WDFW curve and the curve used by the mixture; Kalaloch grows about half as fast |
| `fig_cohort_mixture_examples.png` | 02 | One typical survey per beach: measured lengths, fitted year-class components, cohort boundaries, the 76 mm line |
| `fig_cohort_separation_boundaries.png`, `fig_cohort_separation_shares.png` | 02 | Fitted cohort boundaries by survey date against 76 mm; share of each size class belonging to another year class |
| `fig_cohort_linkage_lengthbased.png` | 02 | log year-old cohort(t) vs log two-year-olds(t+1), length-based |
| `fig_yearclass_abundance.png` | 02 | The 76 mm size classes beside the length-based year classes by beach and survey year |
| `fig_null_audit.png` | 03 | Observed max\|r\| from the original 90-cell screen vs 2,000 phase-randomized surrogates |
| `fig_confirmatory_forest.png` | 04 | Pre-specified predictor effects (pooled LMM; primary, no-Kalaloch, no-trend) |
| `fig_beach_heterogeneity.png` | 04 | Beach-specific GLS-AR(1) effects |
| `fig_confirmatory_lengthbased.png` | 04 | Pre-specified effects with the 76 mm size classes and with the length-based year classes as responses |
| `fig_window_scan_pre.png`, `fig_window_scan_rec.png`, `fig_window_scan_yc1.png`, `fig_window_scan_yc2.png` | 05 | Exploratory window scan over every environmental series for the two size classes and the two length-based year classes; outlined cells would pass family-wise control (none do) |
| `fig_forecast_skill.png` | 06 | Out-of-sample skill (original framework): leaky vs honest selection, persistence, carry-over |
| `fig_forecast_skill_cohort.png`, `fig_forecast_skill_cohort_lengthbased.png` | 06 | Out-of-sample skill (year-class framework): honest vs leaky selection from the full catalogue against trend and a priori models, for pre-recruits and for the length-based year-old cohort |
| `fig_env_coverage.png` | 09 | Month-by-month coverage of every environmental source |
| `fig_legacy_idw_vs_homogenized.png` | 09 | Legacy station-blended beach temperature vs the homogenised regional anomaly |
| `fig_sst_homogenization.png` | 09 | Regional SST anomaly under six constructions (buoys, OISST, MUR), with +/- 2 SE |
| `fig_beuti_homogeneity.png` | 09 | May-Aug BEUTI, CUTI and their ratio at 46N/47N with the 2010/2011 product boundary |
| `fig_index_vintages.png` | 09 | The pre-specified BEUTI, CUTI and PDO windows under the cached snapshots and the current server files |
| `fig_wind_vs_upwelling.png` | 09 | Buoy-measured alongshore wind stress (May-Aug) against CUTI and BEUTI at 47N |

## Tables (`tables/`, CSV)

| File | Script | Content |
|---|---|---|
| `survey_timing_by_beach.csv` | 02 | Median and SD of survey day of year; trend (days per year) |
| `prerecruit_lt30_share_by_timing.csv` | 02 | Share of pre-recruits <20 mm and <30 mm by survey-timing class |
| `cohort_linkage.csv` | 02 | r(pre_t, rec_t+1), r(pre_t, rec_t), r(rec_t, rec_t+1), r(pre_t, pre_t+1) by beach, and the length-based linkage r(year-olds_t, two-year-olds_t+1), r(two-year-olds_t, older_t+1), r(settlers_t, year-olds_t+1) |
| `growth_model_check.csv`, `growth_model_check_by_year.csv` | 02 | The WDFW growth curve placed on the age axis: implied t0 by beach and beach-year, age at 76 mm, expected cohort lengths at surveys Y+1 and Y+2 |
| `cohort_length_transitions.csv`, `cohort_length_transitions_by_beach.csv` | 02 | Correlations of log numbers in five length groups (5–24, 25–75, 76–95, 96–125, 126+ mm) with the same survey and the two previous surveys of the same beach, pooled by survey timing and per beach: the evidence that 76–95 mm clams belong to the year-old cohort at the southern beaches and to the two-year-olds at Kalaloch |
| `cohort_growth_increments.csv`, `cohort_growth_increments_summary.csv` | 02 | Annual growth increments from the same tracking (best-predicted 10 mm bin one survey later) and the growth parameters they imply (K with L∞ fixed at the WDFW value; both free) beside the WDFW values and the constants the mixture uses |
| `cohort_separation_by_year.csv` | 01b | Every beach-year's mixture fit and year-class abundances (same as `02_data/derived/cohort_lengths.csv`) |
| `cohort_separation_summary.csv` | 02 | By beach: growth constants used, fit quality, fitted boundaries, share of the year-old cohort above 76 mm, share of each size class belonging to another year class, and the length-based linkage beside the size-class linkage |
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
| `confirmatory_pooled_lengthbased.csv`, `confirmatory_coastwide_lengthbased.csv` | 04 | The pre-specified tests with the length-based year classes as responses (sensitivity vi), Holm within that set |
| `window_scan_summary.csv`, `window_scan_best_per_variable.csv`, `window_scan_top10.csv`, `window_scan_all.csv` | 05 | Scan results with naive p, BH q, family-wise p; raw r and r with year beside the detrended r |
| `window_scan_trend_attribution.csv` | 05 | Strongest undetrended window per series, split into trend (r with year) and what remains after detrending |
| `forecast_skill_original_framework.csv`, `forecast_skill_original_by_series.csv` | 06 | Skill vs climatology for leaky/honest selection, persistence, carry-over |
| `forecast_skill_cohort_framework.csv`, `forecast_skill_cohort_selections.csv`, `forecast_selection_stability.csv`, `forecast_skill_cohort_fallback_counts.csv` | 06 | Year-class framework: skill of trend, a priori BEUTI, honest and leaky scan selection; which series and window each origin chose; selection stability |
| `*_lengthbased.csv` (the same four) | 06 | The year-class framework with the length-based year-old cohort as the target |
| `forecast_ledger.csv` | 08 | Forecasts issued under `docs/forecast-protocol.md`, one block per target survey year with issue date, commit and data vintage. **Never overwritten**; rerunning after estimates arrive scores them |
| `forecast_scores.csv`, `forecast_scores_summary.csv` | 08 | Scores of ledger rows whose estimates exist (empty until the 2025 estimates are added) |
| `forecast_2025_archived.csv` | archive | Proof-of-concept forecasts for survey 2025 made 2026-10-02 by the earlier script; kept, superseded by the ledger |
| `forecast_skill_fallback_counts.csv` | 06 | Forecasts that fell back to climatology because a predictor was missing |
| `env_coverage_by_station.csv`, `env_coverage_by_year.csv` | 09 | Station classes, distances, record lengths; months per year per source |
| `env_legacy_idw_station_eras.csv` | 09 | Mean offset of the legacy blended series from the homogenised anomaly by beach and dominant station |
| `env_sst_variants.csv`, `env_sst_variant_effects.csv` | 09 | Agreement among SST constructions and the SST effect under each |
| `env_sst_station_parameters.csv` | 09 | Station gains, error SDs, leave-one-station-out agreement |
| `env_beuti_step_tests.csv`, `env_beuti_latitude_periods.csv`, `env_index_annual_correlations.csv` | 09 | BEUTI/CUTI trend, 2011 step and breakpoint tests; latitude x period means; cross-index correlations |
| `env_index_vintages.csv`, `env_index_vintage_effects.csv` | 09 | Cached vs current BEUTI/CUTI/PDO vintages (agreement, trends, step tests) and the pre-specified tests refitted under each |
| `env_satellite_vs_buoy.csv` | 09 | OISST and MUR against the regional and beach-local buoy constructions, by beach; north-south coherence |
| `env_wind_vs_upwelling.csv`, `env_discharge_gauges.csv` | 09 | Buoy wind stress, Ekman transport and winter waves vs CUTI/BEUTI (correlations, trends as share of mean); lower-Columbia gauges vs The Dalles |

Seeds are fixed (`SEED` in `01_code/R/00_config.R`), so surrogate-based p-values are reproducible to Monte Carlo precision (2,000 draws; ±0.01 near p = 0.05).

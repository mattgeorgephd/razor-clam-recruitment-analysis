# 01_code

All analysis code. Run everything from the **repository root** (the folder with `recruitment-analysis.Rproj`).

## `R/`: robust re-analysis pipeline (primary)

`./run_pipeline.sh` (or `Rscript 01_code/R/run_all.R`) runs the scripts in order (~8 min), logs timing to `run_log.txt`, and compiles the report. Outputs go to `02_data/derived/` and `03_analyses/robust-reanalysis/`. Flags: `--fast`, `--steps=..`, `--from=..`, `--out=DIR`, `--vintage=current|cached` (which BEUTI/CUTI/PDO files feed the predictors; current is the default), `--no-report`, `--notebook`, `--install`, `--list`, `--help`.

| Script | Purpose | Main outputs |
|---|---|---|
| `00_config.R` | Paths, constants (beaches, SST buoys, growth curve, seed, surrogate count), plot theme, helpers including `read_lengths()`. Sourced by every script | none |
| `00_correct_inputs.R` | Corrected copies of raw inputs: parses the three date encodings of the shell-length records to one ISO column, sets six groups of year typos to the survey year, flags out-of-range lengths, and writes a changelog with the evidence for every rule. The raw workbooks are never edited | `02_data/corrected/shell_lengths_corrected.csv.gz`, `CHANGELOG.md` |
| `01_build_datasets.R` | Parses abundance, shell lengths (3 date encodings), upwelling, discharge, PDO and a homogeneous regional SST anomaly. Defines the **five pre-specified, cohort-aligned predictors** | `02_data/derived/survey_beach_year.csv`, `env_monthly.csv`, `cohort_table.csv` |
| `lib_cohort_mixture.R` | Growth-curve-informed normal mixture for one survey's lengths (MAP-EM with bounded component means): current-year settlers, the year-old cohort (slow, main and, where the data support it, fast components), two-year-olds, older. Shared helper | none |
| `01b_cohort_separation.R` | Fits the mixture to every beach-year and applies the cohort shares to total abundance: **length-based year classes** beside the 76 mm size classes (`yc1_next`, `yc2_next2`, `yc0_settlers` added to `cohort_table.csv`) | `02_data/derived/cohort_lengths.csv`, `cohort_table.csv`; `cohort_separation_by_year` |
| `02_cohort_diagnostics.R` | Survey timing, length-frequency by survey date, pre-recruit(t) → recruit(t+1) linkage, synchrony, trends; the WDFW growth curve placed on the age axis with the survey length modes; (g) year-class tracking across surveys (why 76 mm is not a cohort boundary; annual growth increments per beach, which corroborate the WDFW curve at Copalis and Long Beach and show Kalaloch growing half as fast), the length-based cohort linkage, fitted boundaries and the contamination of the size classes, example fits | `fig_survey_timing`, `fig_length_frequency`, `fig_cohort_linkage`, `fig_growth_curve_check`, `fig_growth_increments`, `fig_cohort_separation_*`, `fig_cohort_mixture_examples`, `fig_cohort_linkage_lengthbased`, `fig_yearclass_abundance`; `survey_timing_by_beach`, `cohort_linkage`, `trends`, `synchrony_*`, `abundance_summary`, `growth_model_check*`, `cohort_length_transitions*`, `cohort_growth_increments*`, `cohort_separation_summary` |
| `lib_original_grid.R` | Re-implements the legacy notebook's monthly screening grid, including its quirks. Shared helper, not run directly | none |
| `03_null_audit.R` | Checks the grid reproduces the committed notebook output. Calibrates its correlations against 2,000 multivariate phase-randomized surrogates; FDR; detrended and effective-n re-tests of the 20 predictors the notebook selected | `fig_null_audit`; `null_audit_*` |
| `04_confirmatory_models.R` | Pre-specified tests: pooled LMM with random year-class effect, trend, spawners and survey date; Holm correction. Sensitivity: no trend, no Kalaloch, coastwide GLS-AR(1), beach-specific GLS-AR(1), and the length-based year classes as responses | `fig_confirmatory_forest`, `fig_beach_heterogeneity`, `fig_confirmatory_lengthbased`; `confirmatory_*` |
| `05_window_scan.R` | Exploratory climwin-style scan (1–4 month windows, every environmental series: indices, buoy and satellite SST, winds, waves, river gauges) with family-wise error from surrogates; raw vs detrended r for trend attribution; four responses (the two size classes and the two length-based year classes) | `fig_window_scan_pre/rec/yc1/yc2`; `window_scan_*` |
| `06_forecast_skill.R` | Rolling-origin forecasts. Compares climatology, persistence, stock carry-over, leaky vs honest predictor selection (original framework), and in the year-class framework the a priori BEUTI model against honest and leaky selection from the full window catalogue; selection stability; the year-class framework is repeated for the length-based year-old cohort (`_lengthbased`) | `fig_forecast_skill`, `fig_forecast_skill_cohort*`; `forecast_skill_*`, `forecast_selection_stability*` |
| `07_figures_overview.R` | Study-area map, abundance and predictor time series | `fig_study_area`, `fig_abundance_timeseries`, `fig_predictor_timeseries` |
| `lib_window_catalogue.R` | The candidate environmental series (12 when all external products are present) and the catalogue of 1-4 month windows shared by 05, 06 and 08, so the skill test scores the same search the scan runs | none |
| `08_forecast_protocol.R` | Issues forecasts for the next survey year under `docs/forecast-protocol.md` (fixed models for pre-recruits and recruits with prediction intervals) into a ledger that is never overwritten, and scores ledger rows whose estimates have arrived. The 2025 proof-of-concept archive is kept | `forecast_ledger`, `forecast_scores`, `forecast_scores_summary`, `forecast_2025_archived` |
| `lib_env_homogenize.R` | Two-way station model (climatology + regional anomaly + gain, ALS, precision weights) used by `01` and `09`. Shared helper | none |
| `09_env_record_diagnostics.R` | Coverage of every environmental source; legacy IDW blend vs homogenised anomaly (station-era offsets); alternative SST constructions (buoys, OISST, MUR) and their effect on the SST test; station parameters with leave-one-out checks; BEUTI/CUTI trend, 2011 step and breakpoint tests; cross-index correlations; cached vs current index vintages with the pre-specified tests refitted under each; satellite vs buoy agreement by beach; buoy winds and waves vs the upwelling indices; lower-Columbia gauges | `fig_env_coverage`, `fig_legacy_idw_vs_homogenized`, `fig_sst_homogenization`, `fig_beuti_homogeneity`, `fig_index_vintages`, `fig_wind_vs_upwelling`; `env_*` |
| `10_report.R` | Compiles key results, all figures and all tables into `report.md`, and `report.html` when pandoc is available (PATH, or RStudio's copy via rmarkdown) | `report.md`, `report.html` |
| `run_all.R` | Batch runner: argument parsing, dependency check, fresh environment per step, logging (`run_log.txt`, `run_info.txt`, `sessionInfo.txt`), optional legacy-notebook run | none |
| `tests/check_outputs.R` | Regression checks: required derived tables, outputs and figures exist; a curated set of key numbers (`tests/expected_key_numbers.csv`, with a tolerance and a note per number) matches; the forecast ledger has not shrunk. Non-zero exit on failure; run by `.github/workflows/pipeline.yml`. `--write-expected` refreshes the expected values after a deliberate change | none |
| `acquire/` | Fetch scripts for external products (OISST, MUR, NDBC winds/waves, lower-Columbia gauges, current BEUTI/CUTI/PDO vintages); run 2026-10-02, outputs committed; see `acquire/README.md` | `02_data/Environmental Data/external/` |

Figures are in `03_analyses/robust-reanalysis/figures/` (PNG, 300 dpi); tables are in `.../tables/` (CSV).

**Packages:** tidyverse, readxl, lubridate, nlme, lme4, here, maps, mapdata (checked by `run_all.R`; `--install` installs missing ones). Optional: pandoc for `report.html`; knitr, openxlsx, scales, corrplot, patchwork, sf, jsonlite for `--notebook`; rerddap, dataRetrieval, ncdf4 and network access for `acquire/`. The repository root holds `DESCRIPTION` (the same lists as Imports and Suggests) and `renv.lock` (the exact versions behind the committed outputs, R 4.3.3): `renv::restore()` reproduces that library; renv is not activated for the project, so the pipeline runs with whatever library is on the path.

## `razor-clam-recruitment-analysis.Rmd`: legacy exploratory notebook

This is the 26-section notebook (formerly `20260210-...-FIXED (7).Rmd`) that produced `03_analyses/20260322-recruitment-analysis/`. It was bug-fixed on 2026-10-02 (`task.md`, "Fixed"), but its design has the problems described in `docs/methodology-review.md`: lag alignment, multiplicity, trends and selection leakage. Use it for exploration and for reproducing earlier figures, **not** for manuscript inference.

- **Toggles at the top.** `save_*` flags control which figure groups are written; `use_*` flags control which environmental factors enter the predictor catalog.
- **Outputs.** Each run writes to `03_analyses/<today>-recruitment-analysis/` (created with `Sys.Date()`).
- **Section map:**
  - §1–2: setup.
  - §3: data loading, including size-class abundance decomposition and optional downloads.
  - §4: IDW temperature blending at monthly, half-monthly and weekly scales; salinity; discharge.
  - §5–6: climatology plots.
  - §7: seasonal indices.
  - §8–13: lag-correlation screen, heatmaps, scatter, bars, corrplots.
  - §14–17: ACF, spectra, pre-whitening.
  - §18: predictive models.
  - §19–20: synthesis and window plots.
  - §21–26: shell-length / size-class analyses, models and cohort tracking.

## `archive/`

Earlier notebook versions 2–6, kept for history (see `archive/README.md`).

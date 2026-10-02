# 01_code

All analysis code. Run everything from the **repository root** (the folder with `recruitment-analysis.Rproj`).

## `R/`: robust re-analysis pipeline (primary)

`./run_pipeline.sh` (or `Rscript 01_code/R/run_all.R`) runs the scripts in order (~4 min), logs timing to `run_log.txt`, and compiles the report. Outputs go to `02_data/derived/` and `03_analyses/robust-reanalysis/`. Flags: `--fast`, `--steps=..`, `--from=..`, `--out=DIR`, `--no-report`, `--notebook`, `--install`, `--list`, `--help`.

| Script | Purpose | Main outputs |
|---|---|---|
| `00_config.R` | Paths, constants (beaches, SST buoys, seed, surrogate count), plot theme, helpers. Sourced by every script | none |
| `01_build_datasets.R` | Parses abundance, shell lengths (3 date encodings), upwelling, discharge, PDO and a homogeneous regional SST anomaly. Defines the **five pre-specified, cohort-aligned predictors** | `02_data/derived/survey_beach_year.csv`, `env_monthly.csv`, `cohort_table.csv` |
| `02_cohort_diagnostics.R` | Survey timing, length-frequency by survey date, pre-recruit(t) → recruit(t+1) linkage, synchrony, trends | `fig_survey_timing`, `fig_length_frequency`, `fig_cohort_linkage`; `survey_timing_by_beach`, `cohort_linkage`, `trends`, `synchrony_*`, `abundance_summary` |
| `lib_original_grid.R` | Re-implements the legacy notebook's monthly screening grid, including its quirks. Shared helper, not run directly | none |
| `03_null_audit.R` | Checks the grid reproduces the committed notebook output. Calibrates its correlations against 2,000 multivariate phase-randomized surrogates; FDR; detrended and effective-n re-tests of the 20 predictors the notebook selected | `fig_null_audit`; `null_audit_*` |
| `04_confirmatory_models.R` | Pre-specified tests: pooled LMM with random year-class effect, trend, spawners and survey date; Holm correction. Sensitivity: no trend, no Kalaloch, coastwide GLS-AR(1), beach-specific GLS-AR(1) | `fig_confirmatory_forest`, `fig_beach_heterogeneity`; `confirmatory_*` |
| `05_window_scan.R` | Exploratory climwin-style scan (1–4 month windows, 5 variables) with family-wise error from surrogates | `fig_window_scan_pre/rec`; `window_scan_*` |
| `06_forecast_skill.R` | Rolling-origin forecasts. Compares climatology, persistence, stock carry-over, leaky vs honest predictor selection, and the pre-specified BEUTI model | `fig_forecast_skill`; `forecast_skill_*` |
| `07_figures_overview.R` | Study-area map, abundance and predictor time series | `fig_study_area`, `fig_abundance_timeseries`, `fig_predictor_timeseries` |
| `08_forecast_2025.R` | Archives forecasts for the 2025 survey (pre-recruits of year class 2024; carry-over recruits) made before 2025 estimates enter the repo. Never overwrites an existing archive | `forecast_2025_archived` |
| `lib_env_homogenize.R` | Two-way station model (climatology + regional anomaly + gain, ALS, precision weights) used by `01` and `09`. Shared helper | none |
| `09_env_record_diagnostics.R` | Coverage of every environmental source; legacy IDW blend vs homogenised anomaly (station-era offsets); alternative SST constructions and their effect on the SST test; station parameters with leave-one-out checks; BEUTI/CUTI trend, 2011 step and breakpoint tests; cross-index correlations | `fig_env_coverage`, `fig_legacy_idw_vs_homogenized`, `fig_sst_homogenization`, `fig_beuti_homogeneity`; `env_*` |
| `10_report.R` | Compiles key results, all figures and all tables into `report.md`, and `report.html` when pandoc is available (PATH, or RStudio's copy via rmarkdown) | `report.md`, `report.html` |
| `run_all.R` | Batch runner: argument parsing, dependency check, fresh environment per step, logging (`run_log.txt`, `run_info.txt`, `sessionInfo.txt`), optional legacy-notebook run | none |
| `acquire/` | Fetch scripts for external products (OISST, MUR, NDBC winds/waves, lower-Columbia gauges), written without network access and not yet executed; see `acquire/README.md` | `02_data/Environmental Data/external/` |

Figures are in `03_analyses/robust-reanalysis/figures/` (PNG, 300 dpi); tables are in `.../tables/` (CSV).

**Packages:** tidyverse, readxl, lubridate, nlme, lme4, here, maps, mapdata (checked by `run_all.R`; `--install` installs missing ones). Optional: pandoc for `report.html`; knitr, openxlsx, scales, corrplot, patchwork, sf, jsonlite for `--notebook`.

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

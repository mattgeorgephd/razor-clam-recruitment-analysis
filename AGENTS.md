# Notes for AI agents

This repository analyzes Washington coast Pacific razor clam (*Siliqua patula*) recruitment against ocean conditions (1997–2024) and supports a manuscript in preparation. Read this file before changing anything.

## Orientation (read in this order)

1. `README.md`: what is where.
2. `docs/methodology-review.md`: what is wrong with the original analysis and why. Section 1 is a 1-page summary.
3. `task.md`: open issues with priorities. Check it before starting work, and update it when you fix or find something.
3a. `docs/forecast-protocol.md` and `docs/harvest-monitoring-review.md`: the prospective test and what the companion harvest repository does and does not provide.
4. `manuscript/manuscript.md`: current draft. Every number in it must come from `03_analyses/robust-reanalysis/tables/`.

## Two analysis code paths

| Path | Status | Use it for |
|---|---|---|
| `01_code/R/` (`run_all.R` → scripts `01`–`10`) | **Primary.** Reproducible, ~2 min, deterministic (seed in `00_config.R`) | Anything that goes into the manuscript |
| `01_code/R/acquire/` | Fetch scripts for external products (satellite SST, buoy winds/waves, lower-river discharge, current index vintages). Run 2026-10-02; outputs committed in `02_data/Environmental Data/external/` | Refreshing or extending the environmental record (see `docs/environmental-record-options.md`) |
| `01_code/razor-clam-recruitment-analysis.Rmd` | Legacy exploratory notebook (8,400 lines). Bug-fixed 2026-10 but methodologically superseded | Reproducing or explaining earlier figures |
| `01_code/archive/*.Rmd` | Frozen earlier versions (2–6) of the notebook | Nothing; history only |

## Running

- **Full pipeline:** from the repo root, `./run_pipeline.sh` (or `Rscript 01_code/R/run_all.R`; same flags). It rebuilds `02_data/derived/` and `03_analyses/robust-reanalysis/`, appends to `run_log.txt`, and compiles every figure and table into `03_analyses/robust-reanalysis/report.md` (+ `report.html` when pandoc is found). Flags: `--fast` (200 surrogates, ~1 min, writes to the git-ignored `robust-reanalysis-fast/`), `--steps=04,10`, `--from=05`, `--out=DIR`, `--no-report`, `--notebook`, `--install`, `--list`.
- **Single script:** scripts can be run individually (`Rscript 01_code/R/04_confirmatory_models.R`) once `01_build_datasets.R` has run; or `./run_pipeline.sh --steps=04,10` to refresh the report too.
- **Before committing results:** run the full (non-fast) pipeline so the committed tables and figures reflect 2,000 surrogates.
- **Notebook:** knit from RStudio (project root), or `Rscript -e 'knitr::purl("01_code/razor-clam-recruitment-analysis.Rmd")'` and run the resulting `.R` from the repo root. It writes to `03_analyses/<YYYYMMDD>-recruitment-analysis/`. Run it in a scratch copy unless you intend to commit new outputs; one run writes ~150 PNGs, some at 1000 dpi.
- **Requirements:** R ≥ 4.3 with tidyverse, readxl, openxlsx, lubridate, nlme, lme4, here, maps, mapdata; the notebook also needs scales, corrplot, patchwork, sf and jsonlite. On Ubuntu the `r-cran-*` apt packages work. CRAN may be blocked in sandboxed environments.
- **No network needed:** all inputs are cached in `02_data/`. Do not add run-time downloads; cache data with provenance instead. External products go in `02_data/Environmental Data/external/*_monthly.csv` (with `year`, `month` columns); `01_build_datasets.R` joins them automatically, prefixed by file stem. The `acquire/` scripts need network access, `rerddap`, `dataRetrieval` and `ncdf4`; their raw caches (`external/raw/`) are git-ignored.
- **Index vintages:** the pipeline reads the current BEUTI/CUTI/PDO files in `external/` by default (owner decision 2026-10-02, task T35). `./run_pipeline.sh --vintage=cached --out=DIR` runs on the earlier snapshots instead (they differ throughout the record; see the domain facts below). Do not change the default without recording the decision in `task.md` and the manuscript methods.
- **Prospective forecasts:** `08_forecast_protocol.R` appends to `tables/forecast_ledger.csv` and never overwrites it. When new survey estimates are added, add one survey year at a time and rerun the pipeline after each, so each year is scored before the next target is issued (`docs/forecast-protocol.md`).

## Domain facts that are easy to get wrong

- **Survey year.** `survey_year` = first year of the season label (`"2003-04"` → 2003). The stock-assessment survey happens April–August *of that year*, before the fall–spring harvest season.
- **Survey timing differs by beach and over time.** Median dates: Long Beach about 6 Jun, Copalis about 16 Jun (Apr–May in 1997–99), Mocrocks about 18 Jul, Kalaloch about 24 Jul, Twin Harbors about 9 Aug. See `03_analyses/robust-reanalysis/tables/survey_timing_by_beach.csv`.
- **Size classes, not ages.** Pre-recruits are <76 mm, recruits ≥76 mm.
  - At June surveys, pre-recruits are mostly the *previous* year's settlement.
  - Current-year settlers (≤20 mm) appear only in surveys after mid-July.
  - Do not call pre-recruits "young-of-year spawned in the survey year".
- **Year class Y** (spawned summer Y) is counted as pre-recruits at survey Y+1 and mostly as recruits at Y+2. Define predictors relative to Y, not to the survey year.
- **Abundance** = density × `habitat_m2`, and habitat area changes in steps. Density is precomputed in `02_data/derived/survey_beach_year.csv`.
- **Kalaloch** mixes WDFW, Quinault and Olympic National Park survey data and behaves differently from the other beaches. Always show results with and without it.
- **BEUTI** (nitrate flux) trends strongly upward over the record; CUTI (transport) much less. Never interpret undetrended BEUTI correlations. Diagnostics (`09_env_record_diagnostics.R`) find no level shift at the 2010/2011 product boundary and a detrended correlation of −0.48 with independent buoy SST; the trend itself is still to be verified with the index authors (task T6).
- **BEUTI/CUTI and PDO are re-issued.** The server files are regenerated from updated reanalyses; the earlier snapshots (BEUTI/CUTI to 2025-04) and the current vintage (`external/BEUTI_daily_<date>.csv`, the primary) agree only at r about 0.94 for May–Aug means at 47N, and the cached PDO matches neither NCEI nor PSL exactly (r 0.975). The current vintage has a level shift at 2010/2011 at 47N (+1.1 units, p = 0.02) that the snapshot lacks. Report which vintage a number comes from (`index_vintage` column in `env_monthly.csv`; `tables/env_index_vintages.csv`, `env_index_vintage_effects.csv`).
- **Harvest values in the season summary** disagree with WDFW's harvest-monitoring record for several beach-seasons (task T36; corrected values with CVs in `02_data/harvest-monitoring/`). The abundance estimates have no published variance anywhere (T10; `docs/harvest-monitoring-review.md`).
- **Buoy temperature.** Stations within 50 km of the beaches include estuary and harbor gauges (TOKW1, WPTW1, LAPW1, HMDO3). Do not blend raw temperatures across stations: the legacy blend has station-era offsets of up to 0.9 deg C (`tables/env_legacy_idw_station_eras.csv`). Use `sst_anom` in `env_monthly.csv`: a two-way station homogenisation (`lib_env_homogenize.R`) of the six open-coast stations in `SST_OPEN_COAST` (`00_config.R`), with its standard error `sst_anom_se`. Station classes are in `STATION_CLASS`. The previous naive construction is kept as `sst_anom_naive3` for comparison only.
- **Discharge** is USGS 14105700 at The Dalles, about 300 km upstream; it is not a direct plume measure. Lower-river gauges (Beaver 14246900 from 1991-06, Willamette 14211720) are in `external/columbia_lower_monthly.csv`.
- **PDO cache** stores month *names*. Parse with `match(month, month.abb)`.

## Statistical guardrails (non-negotiable for manuscript numbers)

The analysis is **exploratory by design** (owner decision 2026-10-02): its aim is to find the predictors that best explain recruitment, searching every environmental series. That is legitimate only with the calibration below; without it the search returns to the state the review found (a screen indistinguishable from chance).

1. Keep the two arms apart and label them. The a priori hypotheses (`01_build_datasets.R` §4, step 04) are tested with Holm within their family. The exploratory search (step 05 over the whole window catalogue; honest selection in step 06) is calibrated against surrogate data and scored out of sample; its "best predictor" is reported with the family-wise p and the out-of-sample skill, never with the naive p alone. A new a priori hypothesis still needs its rationale recorded before it is tested.
2. Account for trends (trend term, or detrending) and autocorrelation (GLS-AR(1), random year effects).
3. Correct for multiplicity: Holm or BH within a pre-specified family, surrogate or permutation calibration for any search.
4. Any variable or window selection must be repeated inside each cross-validation training fold (`06_forecast_skill.R` does this over the full catalogue; `lib_window_catalogue.R` keeps the catalogue identical between steps 05, 06 and 08). Report skill against both climatology and persistence.
5. The 5 beaches share coastwide predictors. Effective sample size is about the number of year classes (~27), not beach-years (~135).
6. Report negative and null results with the same prominence as positive ones.

## Conventions

- **Do not edit raw inputs** in `02_data/` (except `02_data/derived/`, which is regenerated). Record data-quality problems in `task.md` instead.
- **Outputs:** the new pipeline writes to the fixed folder `03_analyses/robust-reanalysis/`, overwritten on every run. The legacy notebook writes date-stamped folders; do not delete `03_analyses/20260322-recruitment-analysis/` (it backs earlier presentations), but treat its numbers as superseded (task T29).
- **Figures:** 300 dpi PNG via `save_fig()` in `00_config.R`. Use ASCII in plot labels: en dashes, ×, ° and ³ render as ".." with the fonts available in headless environments.
- **Style:** tidyverse; section banners `# ── Title ───`; comments explain *why*.
- **Citations:** mark each reference with its verification status ([V] checked in source, [A] abstract only, [C] to check). Never invent references or page numbers. The growth-parameter source "Cheng & Kuk (2002)" cited in the notebook could not be located; do not propagate it.
- **Prose style** (owner preference): no em dashes in prose; use commas or semicolons.
- **Commits:** small and descriptive. Never commit secrets or large regenerable binaries without need.

## Common tasks

- **Add a predictor:**
  1. Add the monthly series to `env_monthly` (`01_build_datasets.R` §3).
  2. Add a spec to `predictor_specs` (§4).
  3. Add a label in `PREDICTORS` (`04_confirmatory_models.R`).
  4. Run `run_all.R`.
  5. Update the manuscript methods and `task.md`.
- **Add a survey year:**
  1. Append rows to the season summary and shell-length workbooks (same columns).
  2. Run `run_all.R`.
  3. Compare with any pre-registered forecast (task T15) *before* refitting models.
- **Check a number in the manuscript:** search for it in `03_analyses/robust-reanalysis/tables/*.csv`. If it is not there, it should not be in the manuscript.
- **Add an external environmental product:** write a fetch script in `01_code/R/acquire/` that caches `external/<name>_monthly.csv` plus a provenance file; rerun the pipeline; add the new column to the variant list in `09_env_record_diagnostics.R` (C) if it is an SST product and to `EXT_SERIES` (A) for the coverage figure; declare any predictor built from it as a new pre-specified family.
- **Refresh the external products:** on a networked machine, delete the relevant files in `external/raw/` and rerun the `acquire/` script; commit the new monthly CSV and provenance file; rerun `./run_pipeline.sh`.
- **Add a figure or table to the report:** register a caption in `FIG_CAPTIONS` / `TAB_DESCRIPTIONS` in `10_report.R` (unregistered outputs are still included, flagged as uncaptioned).

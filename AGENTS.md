# Notes for AI agents

This repository analyzes Washington coast Pacific razor clam (*Siliqua patula*) recruitment against ocean conditions (1997–2024) and supports a manuscript in preparation. Read this file before changing anything.

## Orientation (read in this order)

1. `README.md`: what is where.
2. `docs/methodology-review.md`: what is wrong with the original analysis and why. Section 1 is a 1-page summary.
3. `task.md`: open issues with priorities. Check it before starting work, and update it when you fix or find something.
4. `manuscript/manuscript.md`: current draft. Every number in it must come from `03_analyses/robust-reanalysis/tables/`.

## Two analysis code paths

| Path | Status | Use it for |
|---|---|---|
| `01_code/R/` (`run_all.R` → scripts `01`–`07`) | **Primary.** Reproducible, ~3 min, deterministic (seed in `00_config.R`) | Anything that goes into the manuscript |
| `01_code/razor-clam-recruitment-analysis.Rmd` | Legacy exploratory notebook (8,400 lines). Bug-fixed 2026-10 but methodologically superseded | Reproducing or explaining earlier figures |
| `01_code/archive/*.Rmd` | Frozen earlier versions (2–6) of the notebook | Nothing; history only |

## Running

- **Full pipeline:** from the repo root, `Rscript 01_code/R/run_all.R`. It rebuilds `02_data/derived/` and `03_analyses/robust-reanalysis/`.
- **Single script:** scripts can be run individually (`Rscript 01_code/R/04_confirmatory_models.R`) once `01_build_datasets.R` has run.
- **Notebook:** knit from RStudio (project root), or `Rscript -e 'knitr::purl("01_code/razor-clam-recruitment-analysis.Rmd")'` and run the resulting `.R` from the repo root. It writes to `03_analyses/<YYYYMMDD>-recruitment-analysis/`. Run it in a scratch copy unless you intend to commit new outputs; one run writes ~150 PNGs, some at 1000 dpi.
- **Requirements:** R ≥ 4.3 with tidyverse, readxl, openxlsx, lubridate, nlme, lme4, here, maps, mapdata; the notebook also needs scales, corrplot, patchwork, sf and jsonlite. On Ubuntu the `r-cran-*` apt packages work. CRAN may be blocked in sandboxed environments.
- **No network needed:** all inputs are cached in `02_data/`. Do not add run-time downloads; cache data with provenance instead.

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
- **BEUTI** (nitrate flux) trends strongly upward over the record; CUTI (transport) much less. Never interpret undetrended BEUTI correlations.
- **Buoy temperature.** Stations within 50 km of the beaches include estuary and harbor gauges (TOKW1, WPTW1, LAPW1, HMDO3). Do not blend raw temperatures across stations. Use the anomaly series `sst_anom` in `env_monthly.csv`, which averages open-coast buoys 46029, 46041 and 46211 after removing each buoy's climatology.
- **Discharge** is USGS 14105700 at The Dalles, about 300 km upstream; it is not a direct plume measure.
- **PDO cache** stores month *names*. Parse with `match(month, month.abb)`.

## Statistical guardrails (non-negotiable for manuscript numbers)

1. Pre-specify predictors and windows before looking at clam correlations. If you add a hypothesis, record the rationale in `01_build_datasets.R` §4 and in the manuscript methods, and keep it separate from exploratory results.
2. Account for trends (trend term, or detrending) and autocorrelation (GLS-AR(1), random year effects).
3. Correct for multiplicity: Holm or BH within a pre-specified family, surrogate or permutation calibration for any search.
4. Any variable or window selection must be repeated inside each cross-validation training fold. Report skill against both climatology and persistence.
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

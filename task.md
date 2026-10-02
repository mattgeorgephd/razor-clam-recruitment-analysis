# Outstanding issues

Tracked issues for the razor clam recruitment analysis. Each item names the file and location, the problem, why it matters, and a suggested fix. Background and evidence are in [`docs/methodology-review.md`](docs/methodology-review.md); section numbers (§) refer to that document. Priority: **P1** blocks a credible manuscript, **P2** should be fixed before submission, **P3** is cleanup.

Last updated: 2026-10-02 (afternoon: runner, homogenised SST, environmental-record options).

---

## P1: Scientific validity

- [ ] **T1. Align lags with year classes and actual survey dates.** Notebook §3 (`age_class_config`), §8, §23–24.
  - **Problem.** "Lag 0" pairs a survey with the same calendar year's May–Oct conditions. Surveys happen from late April to August, so pre-recruits at June surveys were spawned the previous year.
  - **Fix.** Use the year-class framing in `02_data/derived/cohort_table.csv` (review §4.2). For June-surveyed beaches, drop lag-0 windows that end after the survey date.
- [ ] **T2. Stop inferring from screens of hundreds of correlations.**
  - **Problem.** About 7,000 Pearson tests across §8, §16, §23 and §24. The monthly grid is not distinguishable from an autocorrelation-preserving null (global p = 0.07; 4/900 cells pass FDR).
  - **Fix.** Report the pre-specified tests (`01_code/R/04_confirmatory_models.R`). Keep screens as clearly labelled exploration with family-wise calibration (`05_window_scan.R`).
- [ ] **T3. Model or remove trends.**
  - **Problem.** Recruits and BEUTI both trend upward (r(BEUTI, year) = 0.70). Undetrended correlations in §8–§26 are dominated by the shared trend; Copalis recruits × BEUTI-Settle L4 goes from r = 0.59 to 0.02 after detrending.
  - **Fix.** Include a trend term or GLS-AR(1) everywhere.
- [ ] **T4. Report honest validation.**
  - **Problem.** §18 and §25 choose predictors using all years, then cross-validate. Skill falls from +0.31 to −0.20 when selection is repeated inside each training window (`06_forecast_skill.R`).
  - **Fix.** Remove the leaky Q² from any manuscript text; report nested rolling-origin skill against climatology and persistence.
- [ ] **T5. Replace the station-blended temperature.** *Partly done 2026-10-02.*
  - **Problem.** §4a–c average *raw* temperatures across stations that switch on and off, including estuary and harbor gauges (Toke Point, Westport Marina, La Push), so the series contain step changes: era offsets of up to 0.9 deg C (`tables/env_legacy_idw_station_eras.csv`).
  - **Done.** The pipeline's `sst_anom` is now a two-way station homogenisation of six open-coast stations with a standard error (`lib_env_homogenize.R`); four alternative constructions agree at r >= 0.98 and give the same inference (`docs/environmental-record-options.md` §2).
  - **Remaining.** Fetch satellite SST (OISST for 1981–, MUR for nearshore 2002–) with `01_code/R/acquire/fetch_oisst.R` and `fetch_mur.R` on a networked machine, validate against the buoy series, and use beach-adjacent pixels. The legacy notebook still uses the IDW blend.
- [ ] **T6. Verify BEUTI homogeneity before interpreting its trend.** *Diagnosed 2026-10-02.*
  - **Problem.** BEUTI May–Aug at 47°N rises from 0.18 to 2.14 (a near-zero baseline inflates the ratio; the absolute rise is about 2 units, similar to 44–45°N) while CUTI roughly doubles.
  - **Done.** No level shift at the 2010/2011 product boundary (step +0.18, p = 0.65 after trend); best single breakpoint 2006; detrended BEUTI correlates −0.48 with independent buoy SST (`tables/env_beuti_step_tests.csv`, `env_index_annual_correlations.csv`). Key results already use detrended BEUTI and CUTI.
  - **Remaining.** The BEUTI trend is not matched by the buoy SST trend (which warms). Write to the index authors with `fig_beuti_homogeneity.png`; compare with a buoy-wind Bakun index once `fetch_ndbc_met.R` has been run (T32).
- [ ] **T7. Rename "age classes" to size classes, or justify the ages.**
  - **Problem.** Ages come from a von Bertalanffy inverse with t₀ = 0 and parameters attributed to "Cheng & Kuk (2002)", which could not be located. The implied age-1 length (≈90 mm) contradicts the observed June age-1 mode (20–50 mm).
  - **Fix.** Provide the full citation, or call them size classes. Consider date-aware length-mixture models to separate cohorts (review §6, item 9).
- [ ] **T8. Use a real stock-recruitment term.**
  - **Problem.** The "DD" term in §18/§25 is last year's abundance of the same size class. For recruits that is mostly the same animals (persistence), not density dependence.
  - **Fix.** Use spawners (recruits at survey Y) for year class Y, as `04_confirmatory_models.R` does.
- [ ] **T9. Treat beaches as dependent.**
  - **Problem.** Predictors are coastwide or nearly so. Counting "significant cells" across beaches and overlapping windows (§24d-v, §24d-vii) treats dependent tests as replicates.
  - **Fix.** Use a random year-class effect or a coastwide index (implemented).
- [ ] **T10. Obtain and propagate abundance-estimate uncertainty.**
  - **Problem.** `razor-clam-season-summary-1997-2025.xlsx` has point estimates only.
  - **Fix.** Request SE/CV per beach-year from WDFW; use as weights or in a state-space model.

## P2: Data and analysis improvements

- [ ] **T11. Account for harvest** between survey t and t+1 when linking pre-recruits(t) to recruits(t+1). Use the `harvest_total` and `ER` columns already in the season file.
- [ ] **T12. Add mechanistic predictors** (fetch scripts ready in `01_code/R/acquire/`, not yet run: T32):
  - winter wave energy and storm hours (NDBC WVHT via `fetch_ndbc_met.R`);
  - local alongshore wind stress / Ekman transport from measured buoy winds (same script);
  - spring-transition timing and relaxation-event frequency (from the daily wind series once fetched);
  - lower-Columbia discharge (Beaver Army Terminal 14246900 and Willamette 14211720 via `fetch_usgs_lower_columbia.R`; site numbers to verify).
  - Declare these as a **new pre-specified family** before computing any clam correlation (`docs/environmental-record-options.md` §4).
- [ ] **T13. Kalaloch data sources.** Kalaloch combines WDFW, Quinault and Olympic National Park surveys (`note` column), with length heaping at 50 and 58–60 mm, and is asynchronous with other beaches. Model a source covariate, or analyze Kalaloch separately.
- [ ] **T14. Twin Harbors pre-recruits** mix current-year settlers (August survey) with year-old clams. Separate them with a length-mixture or date-adjusted cutoff before modelling.
- [ ] **T15. Score the archived 2025 forecasts, and archive 2026 forecasts.**
  - *2025:* forecasts for survey 2025 were archived on 2026-10-02 (`03_analyses/robust-reanalysis/tables/forecast_2025_archived.csv`, `01_code/R/08_forecast_2025.R`). When the 2025-26 estimates are added, score them before refitting anything.
  - *2026:* survey-2026 forecasts of year class 2025 need BEUTI for May–Aug 2025; the cached BEUTI file ends in April 2025, so update it first.
  - *Blindness:* confirm whether the analyst has already seen the 2025-26 estimates; if so, the test is only partially blind.
- [ ] **T16. Spectral analysis (notebook §15).** Remove it, or test periodogram peaks against an AR(1) null; 28 points cannot resolve 5–8 yr periods.
- [ ] **T17. Pre-whitening (§16–17).** Uses a post hoc best month × lag (72 combinations); circular. Remove, or use a pre-specified predictor.
- [ ] **T18. Half-monthly and weekly "timescales" (§4b–c, §7).** They use the same month-defined windows; only the temperature max/min statistic differs, and upwelling and discharge are identical monthly values. Either define genuinely finer windows (e.g. 2-week windows anchored to spawning dates) or drop them and stop presenting them as independent confirmation.
- [ ] **T32. Run the external-data fetch scripts on a networked machine.** `01_code/R/acquire/{fetch_oisst,fetch_mur,fetch_ndbc_met,fetch_usgs_lower_columbia}.R` were written in a sandbox with no access to NOAA/USGS servers. Confirm dataset ids (`rerddap::ed_search`) and USGS site numbers, run them, keep the provenance files, validate OISST/MUR against `sst_anom` (expect monthly r > 0.9), then rerun `./run_pipeline.sh`. Add new SST products to the variant list in `09_env_record_diagnostics.R`.
- [ ] **T33. Beach-specific temperature.** North–south buoy anomalies correlate at only r = 0.85; a beach-local construction (V3 in `env_sst_variants.csv`) exists in the diagnostics but relies on harbor gauges. Satellite pixels (T32) are the clean route; then decide whether a beach-level SST predictor replaces the regional one (declare before testing).
- [ ] **T34. Optional: state-space fusion of buoys, satellite and model SST** (KFAS/MARSS) with errors-in-variables in the recruitment models. Only worthwhile if temperature becomes a central predictor (`docs/environmental-record-options.md` option G).
- [ ] **T19. Model density instead of abundance**, or include log habitat area: `habitat_m2` changes in steps of up to 15%. Density is precomputed in `02_data/derived/survey_beach_year.csv`.

## P2: Data-quality fixes in source spreadsheets

- [ ] **T20. Shell-length date typos.** One Long Beach 2022 record dated 2028-06-28. Cross-year dates in Kalaloch 2016, Mocrocks 2015 and 2018, and Long Beach 2015 and 2021 (`02_data/derived/survey_beach_year.csv`: `survey_date_first`/`survey_date_last`).
- [ ] **T21. Mixed date encodings** in `All_Clams_Raw$date`: ISO text, Excel serials, and `11-Aug-2011` (Twin Harbors 2011). 910 Kalaloch 2001 records have no date. Standardize to ISO in the source workbook.
- [ ] **T22. Copalis 2003** has abundance estimates but no shell-length records.
- [ ] **T23. Document provenance.** Record the origin of `razor-clam-season-summary-1997-2025.xlsx` (WDFW contact, date received) and of the per-beach shell-length workbooks (153 source files listed in `source_file`).
- [ ] **T24. Unused data files.** `channel-measurements.csv`, `field-measurements.csv`, `MonthlyWtmp.RData` and `MonthlySalinity.RData` are not read by any code. Document or remove them.

## P3: Code and repository hygiene

- [ ] **T25. Insecure downloads.** SATURN-02 fallbacks in the notebook (§3) use `curl -k` and `download.file(..., extra = "-k")`, which disable TLS verification. Download once, manually, and cache with provenance.
- [ ] **T26. Weekly aggregation (§4c)** keys weeks by ISO year but joins to survey year; minor misalignment at year boundaries.
- [ ] **T27. Pin package versions** with `renv`. The notebook installs missing packages at run time, which needs a CRAN mirror and fails non-interactively.
- [ ] **T28. Reduce repository size (322 MB including history).**
  - Figures are saved at 1000 dpi; for example `lag0_concurrent_conditions_by_group.png` is 12,000 × 12,000 px.
  - The 44 MB WDF PDF is committed.
  - Use 300 dpi, Git LFS for binaries, or keep regenerable outputs out of git.
- [ ] **T29. Committed outputs predate the bug fixes.** `03_analyses/20260322-recruitment-analysis/` was produced before the fixes below. Re-knit, or label the folder as superseded, before citing any number from it.
- [ ] **T30. Add tests and assertions** to `01_code/R/01_build_datasets.R` (row counts, date ranges, no duplicated beach-years), plus a CI job that runs `run_all.R`.
- [ ] **T31. Notebook size.** 8,400 lines in one Rmd. Split it into sourced scripts like `01_code/R/` if exploration continues.

---

## Fixed (2026-10-02)

Fixed in `01_code/razor-clam-recruitment-analysis.Rmd`; details in review §3.

- [x] **B1 PDO parsing.** The cached `pdo_index.csv` stores month names; `as.numeric()` produced NA for every month. Now parsed with `match(month, month.abb)`.
- [x] **B2 AICc comparability.** Candidate models in §18 and §25b were fitted to different rows. Now all candidates use common complete cases; diagnostics, time-series plots and prediction tables use the same rows.
- [x] **B3 Silent loss of BEUTI and discharge.** `merge_all_predictors()` left-joined non-temperature predictors onto the temperature table. They are now rebuilt from a complete beach × year × month grid. *Results change; re-knit before citing.*
- [x] **B4 SATURN-02 download.** Now attempted only when `use_salinity = TRUE`.
- [x] **B5 Misleading titles and subtitles.** §19d/e/h, §20c, §24c and §26d now describe what the code does (post hoc selection), not a causal conclusion.
- [x] **B6 Name collision.** `pred_labels` was overwritten in §26d; renamed `pred_labels_ac`.
- [x] **B7 Dependencies.** Removed unused packages (dbplyr, janitor, officer, flextable); dataRetrieval is now optional.
- [x] **B8 Knit directory.** Paths now resolve from the project root (`here::here()`).
- [x] **Versions 2–6** of the notebook moved to `01_code/archive/`; version 7 renamed to `01_code/razor-clam-recruitment-analysis.Rmd`.
- [x] **Batch runner and report** (2026-10-02). `./run_pipeline.sh` / `01_code/R/run_all.R` with `--fast`, `--steps`, `--from`, `--out`, `--notebook`, `--install`, `--list`; logging to `run_log.txt` / `run_info.txt`; `10_report.R` compiles every figure and table into `report.md` / `report.html`.
- [x] **Homogenised SST series** (2026-10-02). `sst_anom` is now the regional term of a two-way station model with a standard error; naive construction kept as `sst_anom_naive3`; diagnostics in `09_env_record_diagnostics.R` (see T5, T6).

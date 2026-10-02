# Outstanding issues

Tracked issues for the razor clam recruitment analysis. Each item names the file and location, the problem, why it matters, and a suggested fix. Background and evidence are in [`docs/methodology-review.md`](docs/methodology-review.md); section numbers (§) refer to that document. Priority: **P1** blocks a credible manuscript, **P2** should be fixed before submission, **P3** is cleanup.

Last updated: 2026-10-02.

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
- [ ] **T5. Replace the station-blended temperature.**
  - **Problem.** §4a–c average *raw* temperatures across stations that switch on and off, including estuary and harbor gauges (Toke Point, Westport Marina, La Push), so the series contain step changes (review §2.4).
  - **Fix.** Use satellite SST (OISST/MUR) at beach-adjacent pixels, or at minimum the buoy-anomaly series in `env_monthly.csv`.
- [ ] **T6. Verify BEUTI homogeneity before interpreting its trend.**
  - **Problem.** BEUTI May–Aug at 47°N rises tenfold (0.18 → 2.14) while CUTI changes far less.
  - **Fix.** Check the product documentation or contact the index authors about splices or reanalysis changes. Repeat key results with CUTI and detrended BEUTI.
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
- [ ] **T12. Add mechanistic predictors:**
  - winter significant wave height (NDBC 46029/46041 WVHT, or a hindcast);
  - spring-transition timing;
  - relaxation-event frequency;
  - lower-Columbia discharge (e.g. Beaver Army Terminal, USGS 14246900, to be verified) instead of The Dalles.
- [ ] **T13. Kalaloch data sources.** Kalaloch combines WDFW, Quinault and Olympic National Park surveys (`note` column), with length heaping at 50 and 58–60 mm, and is asynchronous with other beaches. Model a source covariate, or analyze Kalaloch separately.
- [ ] **T14. Twin Harbors pre-recruits** mix current-year settlers (August survey) with year-old clams. Separate them with a length-mixture or date-adjusted cutoff before modelling.
- [ ] **T15. Score the archived 2025 forecasts, and archive 2026 forecasts.**
  - *2025:* forecasts for survey 2025 were archived on 2026-10-02 (`03_analyses/robust-reanalysis/tables/forecast_2025_archived.csv`, `01_code/R/08_forecast_2025.R`). When the 2025-26 estimates are added, score them before refitting anything.
  - *2026:* survey-2026 forecasts of year class 2025 need BEUTI for May–Aug 2025; the cached BEUTI file ends in April 2025, so update it first.
  - *Blindness:* confirm whether the analyst has already seen the 2025-26 estimates; if so, the test is only partially blind.
- [ ] **T16. Spectral analysis (notebook §15).** Remove it, or test periodogram peaks against an AR(1) null; 28 points cannot resolve 5–8 yr periods.
- [ ] **T17. Pre-whitening (§16–17).** Uses a post hoc best month × lag (72 combinations); circular. Remove, or use a pre-specified predictor.
- [ ] **T18. Half-monthly and weekly "timescales" (§4b–c, §7).** They use the same month-defined windows; only the temperature max/min statistic differs, and upwelling and discharge are identical monthly values. Either define genuinely finer windows (e.g. 2-week windows anchored to spawning dates) or drop them and stop presenting them as independent confirmation.
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

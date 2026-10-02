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
  - **Done (2026-10-02, with network access).** OISST (0.25 deg, 1981–) and MUR (1 km, 2002–) pixels off each beach are in `02_data/Environmental Data/external/` and enter the diagnostics as constructions V4 and V5. Agreement with the homogenised buoy anomaly: monthly r 0.88 (OISST) and 0.94 (MUR), weakest in Jul–Sep (r 0.78–0.81) when cross-shore gradients are strongest, and in 1990–2003 when only 1–2 buoys report (r 0.83). The SST test is null under all seven constructions, including beach-specific OISST and MUR (`tables/env_sst_variant_effects.csv`, `env_satellite_vs_buoy.csv`).
  - **Remaining.** Decide (and declare) whether a beach-level satellite SST predictor replaces the regional buoy one (T33). The legacy notebook still uses the IDW blend. OISST on the CoastWatch ERDDAP holds only 139–239 days per year for 1992–1998; monthly means there rest on 10–15 days.
- [ ] **T6. Verify BEUTI homogeneity before interpreting its trend.** *Diagnosed 2026-10-02.*
  - **Problem.** BEUTI May–Aug at 47°N rises from 0.18 to 2.14 (a near-zero baseline inflates the ratio; the absolute rise is about 2 units, similar to 44–45°N) while CUTI roughly doubles.
  - **Done.** No level shift at the 2010/2011 product boundary (step +0.18, p = 0.65 after trend); best single breakpoint 2006; detrended BEUTI correlates −0.48 with independent buoy SST (`tables/env_beuti_step_tests.csv`, `env_index_annual_correlations.csv`). Key results already use detrended BEUTI and CUTI.
  - **Done (2026-10-02, with network access).** (a) *Measured winds.* Alongshore wind stress from the open-coast buoys (`external/ndbc_met_monthly.csv`) reproduces CUTI's May–Aug interannual variation (r = 0.72, detrended 0.63) and its trend (+24% of the mean per decade for the winds, +18% for CUTI, both p < 0.01), but only a third of BEUTI's detrended variance (r = 0.31), and BEUTI's trend is +58% of its mean per decade. So the transport part of the trend is real; the nitrate part is not independently corroborated (`tables/env_wind_vs_upwelling.csv`, `fig_wind_vs_upwelling.png`). (b) *Vintage.* The index authors re-issued the whole record (files created 2026-09-28): daily r with the cached snapshot 0.94 at 46–47N, May–Aug 47N r 0.94, the trend is steeper (+1.07 vs +0.76 per decade) and, unlike the cached vintage, the current one shows a level shift at 2010/2011 at 47N (+1.07, p = 0.02, best break 2010) (`tables/env_index_vintages.csv`, `fig_index_vintages.png`).
  - **Remaining.** Write to the index authors with the two figures and ask what changed between vintages, and whether the 2010/2011 reanalysis boundary now carries a step. Decide which vintage the manuscript uses (T35).
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
- [ ] **T12. Add mechanistic predictors.** The series now exist in `02_data/Environmental Data/external/` (fetched 2026-10-02) and are joined into `env_monthly.csv`; none has been tested against clam data yet:
  - winter wave energy (Hs²) and storm hours (Hs > 4 m), homogenised across six buoys (`ndbc_met_hs2_anom`, `ndbc_met_storm_anom`); they correlate −0.47 to −0.48 with winter CUTI (storms with downwelling), as expected;
  - local alongshore wind stress / Ekman transport from measured buoy winds (`ndbc_met_tau_along_anom`, `ndbc_met_ekman_anom`);
  - lower-Columbia discharge: Beaver (from 1991-06) correlates 0.97 with The Dalles for Apr–Jun and the Willamette adds an independent 12% of flow (`columbia_lower_q_*`);
  - beach-level satellite SST (`oisst_anom_<beach>`, `mur_anom_<beach>`);
  - still to derive: spring-transition timing and relaxation-event frequency from the hourly winds in `external/raw/` (git-ignored; rerun `fetch_ndbc_met.R` to regenerate).
  - Declare these as a **new pre-specified family** (windows and signs) in `01_build_datasets.R` §4 and the manuscript methods *before* computing any clam correlation (`docs/environmental-record-options.md` §4). Holm within the family.
- [ ] **T13. Kalaloch data sources.** Kalaloch combines WDFW, Quinault and Olympic National Park surveys (`note` column), with length heaping at 50 and 58–60 mm, and is asynchronous with other beaches. Model a source covariate, or analyze Kalaloch separately.
- [ ] **T14. Twin Harbors pre-recruits** mix current-year settlers (August survey) with year-old clams. Separate them with a length-mixture or date-adjusted cutoff before modelling.
- [ ] **T15. Score the archived 2025 forecasts, and archive 2026 forecasts.**
  - *2025:* forecasts for survey 2025 were archived on 2026-10-02 (`03_analyses/robust-reanalysis/tables/forecast_2025_archived.csv`, `01_code/R/08_forecast_2025.R`). When the 2025-26 estimates are added, score them before refitting anything.
  - *2026:* survey-2026 forecasts of year class 2025 need BEUTI for May–Aug 2025; the current vintage in `external/BEUTI_daily_2026-09-28.csv` covers it (`--vintage=current`), but the model would then be fitted on a different vintage than the archived 2025 forecasts (T35).
  - *Blindness:* confirm whether the analyst has already seen the 2025-26 estimates; if so, the test is only partially blind.
- [ ] **T16. Spectral analysis (notebook §15).** Remove it, or test periodogram peaks against an AR(1) null; 28 points cannot resolve 5–8 yr periods.
- [ ] **T17. Pre-whitening (§16–17).** Uses a post hoc best month × lag (72 combinations); circular. Remove, or use a pre-specified predictor.
- [ ] **T18. Half-monthly and weekly "timescales" (§4b–c, §7).** They use the same month-defined windows; only the temperature max/min statistic differs, and upwelling and discharge are identical monthly values. Either define genuinely finer windows (e.g. 2-week windows anchored to spawning dates) or drop them and stop presenting them as independent confirmation.
- [x] **T32. Run the external-data fetch scripts** (done 2026-10-02; see "Fixed"). Rerun them when the products need refreshing.
- [ ] **T33. Beach-specific temperature.** Satellite pixels are now available per beach. North–south coherence (Long Beach vs Kalaloch, monthly anomalies) is 0.73 in OISST, 0.81 in MUR and 0.88 in the beach-local buoy construction, so the satellites see *more* alongshore structure than the buoys (which share stations). Long Beach is the odd beach in every product (OISST vs MUR r = 0.79 there vs 0.84–0.92 elsewhere; plume influence). Beach-specific OISST and MUR SST effects on year-class strength are +0.04 (p = 0.70) and +0.10 (p = 0.52). Decide whether the regional predictor is replaced (declare before testing); the evidence so far says it makes no difference to the SST conclusion.
- [ ] **T35. Decide which index vintage the manuscript uses.** The cached BEUTI/CUTI/PDO snapshots and the current server files differ throughout the record (T6). The pre-specified tests give the same qualitative answer under both (`tables/env_index_vintage_effects.csv`); a full pipeline run under the current vintage (`./run_pipeline.sh --vintage=current --out=DIR`) is summarised in `docs/environmental-record-options.md` §6. Options: (a) keep the cached snapshot (reproduces the archived 2025 forecasts; the vintage is frozen in the repository), (b) switch to the current vintage (matches what readers can download; needs the archived forecasts to be re-stated). Either way, state the vintage (file creation date) in the methods.
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
- [x] **External environmental products fetched** (2026-10-02, task T32). With network access, `01_code/R/acquire/` was run against the live servers after fixing the dataset time bounds, OISST's depth axis, the upper-case NDBC field names and the USGS API migration; outputs and provenance are in `02_data/Environmental Data/external/`. New `fetch_climate_indices.R` caches the current BEUTI/CUTI/PDO vintages; `--vintage=current` runs the pipeline on them. Step 09 gained sections F (vintages), G (satellite vs buoys) and H (winds, waves, gauges). Note: the Dalles discharge cache matches a fresh download exactly except for provisional revisions after 2023-10.
- [x] **Homogenised SST series** (2026-10-02). `sst_anom` is now the regional term of a two-way station model with a standard error; naive construction kept as `sst_anom_naive3`; diagnostics in `09_env_record_diagnostics.R` (see T5, T6).

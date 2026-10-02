# Methodology and results review

*Review date: 2 October 2026. Scope: every file in the repository at commit `1324017`, with emphasis on the analysis notebook (`01_code/razor-clam-recruitment-analysis.Rmd`, formerly `...FIXED (7).Rmd`), its inputs in `02_data/`, and its outputs in `03_analyses/20260322-recruitment-analysis/`.*

This document is written for the analyst and for co-authors deciding what a manuscript can claim. Section 1 is the short version. Every quantitative statement points to a script or table that reproduces it; tables live in `03_analyses/robust-reanalysis/tables/` and figures in `03_analyses/robust-reanalysis/figures/`.

---

## 0. How the review was done

1. **Read the entire notebook (8,364 lines, 26 sections).** Diffed the six notebook versions. Version 7 contains everything in versions 2–6 apart from older toggle settings and figure sizes, so 2–6 were moved to `01_code/archive/`.
2. **Re-ran the original notebook end to end in a clean R 4.3.3 environment.** The only edit was removing two unused packages. The rerun reproduced the committed correlation workbook exactly: maximum |Δr| = 0 over 1,350 rows.
3. **Independently re-implemented the monthly screening grid** (`01_code/R/lib_original_grid.R`). It reproduces the committed `correlation_matrix_monthly.xlsx` to |Δr| < 0.001 over 900 cells (`tables/null_audit_reproduction_check.csv`). That re-implementation exposed bug B3 below.
4. **Inspected the raw data directly.** This covered 218,101 shell lengths with survey dates, 140 beach-year abundance estimates, 17 temperature stations, and the upwelling, discharge and PDO series.
5. **Built a confirmatory re-analysis** (`01_code/R/`, run with `Rscript 01_code/R/run_all.R`, about 3 minutes). It tests the original findings against explicit null models and fits a small set of pre-specified, cohort-aligned hypotheses.

Literature citations are given with a verification status, because this environment could not reach publisher pages. **[V]** means verified against the document itself, for example the 1988 WDF report in this repository with page numbers. **[A]** means verified from an abstract or index record only. **[C]** means cited from domain knowledge and still to be checked before submission.

---

## 1. Executive summary

The repository contains a large, carefully plotted exploratory analysis. Its headline narrative is that upwelling (BEUTI) during the larval and settlement season predicts harvestable razor clam abundance two to five years later, with geographically structured lags. **That narrative is not supported once the analysis accounts for multiplicity, shared trends, survey timing and honest validation.** In order of consequence:

| # | Finding | Evidence | Consequence |
|---|---------|----------|-------------|
| 1 | **The lag structure ignores survey timing.** Surveys run from late April to late August. The median date differs by about two months among beaches (Long Beach about 6 June, Twin Harbors about 9 August) and drifts by about 1 day per year at three beaches. At June surveys, pre-recruits are survivors of the *previous* summer's settlement, yet the notebook labels them "young-of-year spawned in the survey year (lag 0)". | `tables/survey_timing_by_beach.csv`, `figures/fig_length_frequency.png`, `fig_survey_timing.png` | Lag-0 "Settle" (Jul–Aug) and "Growth" (Sep–Oct) windows *post-date* most surveys, so they cannot be causes. Every age-class → lag mapping is off by about one year at early-survey beaches. |
| 2 | **The screen is not distinguishable from chance.** The notebook computes about 7,000 correlations (2,700 in Section 8 alone). In the monthly grid, 83 of 900 cells have p < 0.05. Response surrogates that preserve autocorrelation and cross-beach dependence give a null median of 60 (95th percentile 85), so the global p = 0.07. Only 4 of 900 cells pass Benjamini–Hochberg FDR at q < 0.05. | `tables/null_audit_global.csv`, `null_audit_by_series.csv`, `fig_null_audit.png` | The heatmaps, "sweet spot" bubbles, best-lag tiles and lag profiles visualize mostly noise. |
| 3 | **Shared trends drive the strongest correlations.** Log recruits rise 2.4–4.5% per year at four beaches (GLS-AR(1) p ≤ 0.008 at three of them). May–Aug BEUTI at 47°N rises tenfold, from about 0.2 (1990s) to about 2 (2010s); its correlation with year is 0.70. The four FDR survivors are all *Mocrocks recruits × BEUTI*, at lags 1, 2, 3, 4 and 5 alike (r = 0.64–0.74). A cohort mechanism cannot produce the same correlation at five different lags; a common trend can. | `tables/trends.csv`, `null_audit_all_cells.csv` | After linear detrending, Copalis recruits × BEUTI-Settle lag 4 drops from r = 0.59 to 0.02, and Mocrocks recruits × BEUTI-Larval lag 5 from 0.74 to 0.44 (`null_audit_selected_predictors.csv`). |
| 4 | **The reported cross-validated skill is inflated by selection leakage.** Predictors were chosen with all 28 years, then "validated" with LOOCV and rolling-origin CV. Repeating the selection *inside* each training window turns skill negative. | `tables/forecast_skill_original_framework.csv`, `fig_forecast_skill.png` | Skill vs climatology, pre-recruits: +0.31 (leaky) vs −0.20 (honest). Recruits: +0.30 vs −0.20. The environmental models forecast worse than the long-term mean. |
| 5 | **The water-temperature predictor is inhomogeneous.** Each beach's "IDW blend" is in practice one or two stations whose identity changes over time: offshore buoys in the 1990s, then estuarine or harbor gauges such as Toke Point inside Willapa Bay, Westport Marina inside Grays Harbor and La Push. Raw temperatures, not anomalies, are averaged. Long Beach switches from buoy 46029 (≤2004) to Toke Point (2005–08) to Clatsop Spit at the Columbia mouth (2009+). | `tables/` (station audit in §2.4) | Step changes in the predictor coincide with the clam trends, and "max temperature" at harbor gauges is not surf-zone temperature. |
| 6 | **Several code bugs alter results** (§3): BEUTI and discharge dropped wherever temperature was missing (B3); PDO all-NA (B1); AICc compared across models fitted to different data (B2); and others. | `task.md` | Fixed in the notebook; outputs in `03_analyses/20260322-*` predate the fixes. |

**What survives.** These results come from the pre-specified, cohort-aligned analysis, which tests 5 predictors × 2 responses, includes trend, spawner and survey-date terms, and handles autocorrelation:

- **BEUTI: a modest negative association, opposite in sign to the notebook's narrative.** Higher detrended upwelling (BEUTI, May–Aug of spawning year Y) is associated with *fewer* pre-recruits of that year class at survey Y+1.
  - Coastwide index (GLS-AR(1)): −0.58 SD per SD, Holm-adjusted p = 0.013.
  - Pooled mixed model excluding Kalaloch: −0.49 log units per SD, Holm p = 0.031.
  - Pooled mixed model with all five beaches: −0.34, nominal p = 0.052, Holm p = 0.47.
  - Holds under loess detrending (r = −0.44, p = 0.02) and first differencing (slope −0.58, p < 0.001). Plain linear detrending with OLS gives a weaker −0.37 (p = 0.03), so the association is mainly year-to-year rather than decadal.
  - Every leave-one-year-out estimate is negative (−0.26 to −0.43), but 2008 (record BEUTI, weak year class) is influential: without it, −0.25 (p = 0.20) (`tables/confirmatory_beuti_robustness.csv`).
  - Rolling-origin skill is essentially nil (−0.03 coastwide), and a family-wise-calibrated scan of 570 windows would not have found it.
- **Spring discharge and recruits: suggestive only.** Columbia freshet discharge (Apr–Jun Y) is positively associated with recruits of year class Y at survey Y+2 (+0.18 log units per SD, p = 0.011, Holm p = 0.11).
- **Stock carry-over is the real forecasting signal.** Pre-recruits at survey t predict recruits at t+1 (r = 0.50–0.58, p < 0.01) at four of five beaches. A model with no environmental data, recruits(t) ~ pre-recruits(t−1) + recruits(t−1), has out-of-sample skill of +0.24 overall (+0.52 Copalis, +0.45 Mocrocks, +0.35 Long Beach).

The defensible manuscript is therefore a careful **negative-and-cautionary** paper with one pre-specified, moderately supported, mechanistically interpretable result: the BEUTI association. It is not a "BEUTI drives recruitment" paper. A draft is in `manuscript/manuscript.md`.

---

## 2. Data review

### 2.1 Abundance estimates (`02_data/razor-clam-season-summary-1997-2025.xlsx`)

- **Coverage:** 5 beaches × 28 seasons (1997-98 to 2024-25), with no gaps and no zeros. `survey_year` is taken from the first year of the season label. The `year` column (1..28) is an index, not a calendar year, and the notebook drops it.
- **Units:** pre-recruit (<76 mm) and recruit (≥76 mm) abundance are beach-wide expansions, density × `habitat_m2`.
  - Habitat area changes in steps of up to 15% (Twin Harbors: 2.35 M m² in 2002–05, 1.82 M m² from 2011).
  - Modelling density, or including log area as an offset, would remove that artifact. The new pipeline writes `pre_density`/`rec_density` to `02_data/derived/survey_beach_year.csv` for this purpose.
- **Missing uncertainty:** no measurement uncertainty is provided. WDFW estimates come with variances from the pumped-area design (Berry-Powell et al. 2023 **[A]**). These should be obtained and used, either as weights or in a state-space model; without them, observation error and process variation cannot be separated.
- **Fishery variables not used:** target exploitation rates (`ER`, mean 33%; realized `ER_actual` mean 20%), TACs and harvest are in the file but unused. Harvest removes recruits between survey t and t+1, so any model of recruits(t+1) from pre-recruits(t) should account for it.

### 2.2 Shell lengths (`02_data/shell_length_data-summary/`)

- **Survey timing.** Median survey day of year by beach (`tables/survey_timing_by_beach.csv`):

  | Beach | Median day of year | SD (days) | Trend (days/yr) | Trend p |
  |---|---|---|---|---|
  | Kalaloch | 205 | 14 | −1.3 | <0.001 |
  | Mocrocks | 199 | 5 | −0.2 | 0.10 |
  | Copalis | 168 | 17 | +1.4 | <0.001 |
  | Twin Harbors | 221 | 9 | −0.8 | <0.001 |
  | Long Beach | 157 | 12 | −0.3 | 0.26 |

  Copalis was surveyed in late April–May in 1997–99 and in June afterwards.
- **Cohort structure.** Length-frequency modes (`fig_length_frequency.png`) show a distinct ≤20 mm current-year settler mode only in surveys after mid-July (Twin Harbors, Kalaloch). At June surveys (Long Beach, Copalis), the smallest mode is 20–50 mm, and these clams must have settled the previous summer.
  - The 1988 WDF hatchery report in this repository supports this timing. Natural spawning occurred in "April, May and June and July" (Creekman et al. 1988, p. 21 **[V]**), and larval plus metamorphosis phases took "about 1 month" under hatchery conditions (p. 157 **[V]**). Wild juveniles collected in October–December were 5–26 mm (p. 93 **[V]**).
- **Cohort linkage.** Log pre-recruits at t correlate with log recruits at t+1 (r = 0.50–0.58, p ≤ 0.009) at Kalaloch, Mocrocks, Copalis and Long Beach, but not at Twin Harbors (r = −0.16). Same-year correlations are weak (`tables/cohort_linkage.csv`). Pre-recruits at survey t are therefore mostly next year's recruits; recruits at t are *not* this year's pre-recruits.
  - Twin Harbors' different behavior is consistent with its August survey. Its "pre-recruits" mix current-year settlers, which suffer high early mortality, with year-old clams straddling 76 mm.
- **The 76 mm boundary is not an age boundary.** At late surveys the age-1 mode (about 70–90 mm) straddles it, so faster growth moves clams from "pre-recruit" to "recruit". An environmental effect on growth can masquerade as an effect on abundance.
- **Data-quality issues**, all listed in `task.md`:
  - Date typos: one Long Beach 2022 record dated 2028; cross-year dates in 6 beach-years.
  - Three date encodings mixed in one column.
  - 910 Kalaloch 2001 records with no date, and 919 Twin Harbors 2011 records in a third date format (`11-Aug-2011`).
  - Copalis 2003 has abundance estimates but no length data.
  - Length heaping at Kalaloch (spikes at 50 and 58–60 mm), consistent with rounding in one data source.
  - Kalaloch combines WDFW, Quinault and Olympic National Park survey sources, whose mix changes over time (`note` column).

### 2.3 Upwelling indices (BEUTI, CUTI)

- **Source and resolution.** Jacox et al. (2018) daily indices at 1° latitude **[A]**. The notebook uses the 46°N bin for Long Beach and 47°N for the other beaches. Kalaloch (47.6°N) lies north of the northernmost bin.
- **BEUTI trend.** BEUTI May–Aug at 47°N rises from 0.18 ± 0.21 (1988–1998) to 2.14 ± 0.63 (2011–2024) mmol m⁻¹ s⁻¹ (mean ± SD of annual values). CUTI, the physical vertical transport, rises much less relative to its interannual variability: 0.15 ± 0.06 → 0.28 ± 0.08.
  - The increase is therefore in nitrate concentration of source waters, not in upwelling strength.
  - **Before interpreting it as climate signal, confirm that the product is homogeneous.** Check whether the historical and near-real-time segments of the underlying ocean reanalysis are spliced, and whether assimilated data streams changed. This is **[C]**: I could not reach the product documentation from this environment.

### 2.4 Water temperature (`02_data/Environmental Data/*wtmp*`, `Wtmp_salt.R`)

`Wtmp_salt.R` pulls all NDBC `cwwcNDBCMet` records in a 46–48.5°N box. The notebook blends stations within 50 km of each beach by inverse-distance weighting (power 3) of **raw monthly mean/min/max**. Station availability by beach:

| Beach | Stations ≤50 km with data | Years with data | Main contributor by period |
|---|---|---|---|
| Long Beach | 46029, TOKW1, 46243, 46096, HMDO3, 46127 | 1991–2025 (gaps) | 46029 offshore buoy (≤2004) → TOKW1 Toke Point, inside Willapa Bay (2005–08) → 46243 Clatsop Spit, Columbia mouth (2009+) |
| Twin Harbors | 46211, WPTW1, TOKW1, 46099 | 2004–2025 | 46211 (2004–07) → WPTW1 Westport Marina, inside Grays Harbor (2008+) |
| Copalis | 46041, 46211, WPTW1, 46099 | 1990–2025 | 46041 Cape Elizabeth (≤2003) → 46211 → WPTW1 |
| Mocrocks | 46041, 46211, WPTW1, 46099 | 1990–2025 | 46041 → mix |
| Kalaloch | 46041, LAPW1 | 1990–2025 | 46041 → 46041 + LAPW1 La Push harbor (2006+) |

Three problems follow:

1. **Inhomogeneity.** Averaging raw temperatures from stations with different climatologies creates steps whenever the mix changes. The fix is to average *anomalies* relative to each station's own climatology, which `01_build_datasets.R` does for three open-coast buoys.
2. **Representativeness.** Estuary and marina gauges measure bay water, not the surf zone where razor clams live and settle.
3. **Extremes.** "Min" and "max" are monthly extremes of hourly data, which are dominated by tides and single events.

Satellite SST (OISST or MUR) at beach-adjacent pixels would be more representative and homogeneous for 1997–2024; downloading it was not possible here.

### 2.5 Other predictors

- **Columbia River discharge.** USGS 14105700 at The Dalles, about 300 km upstream, regulated by dams and excluding lower-basin tributaries such as the Willamette. A gauge nearer the mouth (Beaver Army Terminal, 14246900) **[C]**, or a plume metric, would be more relevant to the coast. The cached series runs 1990-01 to 2026-03.
- **PDO.** NCEI ERSST v5, 1950–2026 (Mantua et al. 1997 **[A]**). The cache stores month names, which caused bug B1.
- **Salinity.** Three Westport shelf moorings from 2014–15 only (10–11 years), and nothing within 40 km of Long Beach or Kalaloch unless SATURN-02 is downloaded. Too short for 28-year inference; correctly switched off.
- **Unused files.** `channel-measurements.csv` and `field-measurements.csv` are USGS field-visit records, unused by any code. `MonthlyWtmp.RData` and `MonthlySalinity.RData` are R workspace objects, also unused.

---

## 3. Code review: bugs and their status

| ID | Location (current notebook) | Problem | Status |
|---|---|---|---|
| B1 | §3, PDO cache | `pdo_index.csv` stores month as "Jan"…; `as.numeric()` gives NA, so PDO predictors were all NA whenever `use_pdo = TRUE` | **Fixed** (month names parsed) |
| B2 | §18, §25b | AICc compared across candidate models fitted to *different rows* (each formula dropped its own NAs; lag-1 terms drop a year), so ΔAICc was not meaningful | **Fixed** (common complete cases) |
| B3 | §7 `merge_all_predictors()` | BEUTI, CUTI, discharge and PDO were *left-joined onto the temperature table*, so they vanished for every beach-month without buoy temperature. Window means then used a subset of months (BEUTI n = 25 instead of 28 at Copalis) | **Fixed** (non-temperature indices rebuilt from a full beach × year × month grid) |
| B4 | §3, SATURN-02 | Network download attempted on every run even with salinity off, and with TLS verification disabled (`curl -k`) | **Fixed** (gated behind `use_salinity`); `-k` remains, flagged in `task.md` |
| B5 | §19d, §19e, §19h, §20c, §24c, §26d | Titles and subtitles hard-code causal claims ("BEUTI predicts…", "link is confirmed") or contradict the code ("Lags 3–5" while plotting lags 2–5; "uses a fixed Jun–Aug window" while selecting the best window post hoc) | **Fixed** (text now describes what the code does) |
| B6 | §26d | `pred_labels` (global label lookup from §11) overwritten with a per-age-class table | **Fixed** (renamed) |
| B7 | §1 | Loads unused packages (dbplyr, janitor, officer, flextable); hard dependency on dataRetrieval only needed if the cache is missing | **Fixed** |
| B8 | setup | Paths are relative to the repo root, but knitting from `01_code/` sets the working directory to `01_code/` | **Fixed** (`knitr::opts_knit$set(root.dir = here::here())`) |
| B9 | §4c weekly | Weeks keyed by ISO year but joined to survey year; `month` is the "dominant month" of the week | Open (minor) |
| B10 | §7 | "Half-monthly" and "weekly" timescales use the *same month-defined windows*; only the temperature max/min statistic changes, and upwelling and discharge are identical monthly values. The three timescales are near-replicates, not independent confirmation | Open (design; documented) |
| B11 | §16, §17 | Pre-whitening uses one best month × lag chosen post hoc from 72 combinations; the "R²" summary is in-sample after selection | Open (design) |
| B12 | §15 | Spectral "dominant periods" (2–7.5 yr) from 28 points with no significance test; with lag-1 autocorrelation about 0.5 these are compatible with red noise | Open (design) |

The committed outputs in `03_analyses/20260322-recruitment-analysis/` were produced **before** these fixes. Because of B3, BEUTI and discharge correlations will change slightly on re-knitting.

---

## 4. Methodological review

### 4.1 Response variables and the age-class decomposition

- **YOY is not a new response.** "YOY" abundance equals `pre_recruits` by construction, so Sections 23–26 duplicate the pre-recruit analysis under a new name.
- **Juvenile, Sub-adult and Adult are length-defined fractions of recruits** (76–100, 101–120, >120 mm). Their labels come from inverting a von Bertalanffy curve with **t₀ = 0** and parameters attributed to "Cheng & Kuk (2002)". I could not locate that source; it needs a full citation or replacement.
  - Mark-recapture (Fabens-type) fits estimate L∞ and K but not t₀, so absolute age from length is not identifiable without it.
  - The observed modes contradict the implied ages. A June age-1 mode at 20–50 mm is far below the 91 mm that the curve predicts at age 1.
  - These are size classes and should be called size classes.
- **"Density dependence" is not density dependence.** The DD term is the same size class's abundance in the previous year, `log_resp_lag1`. For recruits it largely measures *the same individuals surviving another year*, i.e. persistence. For pre-recruits it is the previous year class.
  - A stock-recruitment term should use spawners at the time of spawning: recruits (adults) at survey Y for year class Y, in a Ricker or Beverton–Holt form.

### 4.2 Lag alignment

Treat each **year class** (spawned and settled in summer Y) as the unit of analysis:

- **At June–July surveys**, year class Y appears as pre-recruits at survey Y+1 and mostly as recruits at Y+2.
- **At August surveys**, it is also visible as tiny settlers at survey Y.

Predictors should be defined relative to Y, for example spawning season (Apr–Jun Y), larval and settlement season (May–Sep Y) and first winter (Nov Y–Feb Y+1). They should not be defined relative to the survey year. The notebook's "lag 0 Settle/Growth" windows fall after most surveys and cannot be causal for the abundances measured at those surveys.

### 4.3 Multiplicity and the "best" correlation

The notebook selects maxima of |r| at many levels: lag, window, timescale, metric, "peak window" and "best month". Under the null, the maximum |r| over 90 cells with n ≈ 27 and autocorrelated series is about 0.47–0.64 (median across series; `null_audit_by_series.csv`). Most "best" correlations reported in the outputs (0.50–0.74) are in that range.

Remedies:

1. Pre-specify a small number of hypotheses tied to life history.
2. Calibrate any search with surrogates or permutations that preserve autocorrelation, as in `05_window_scan.R`, or use climwin's randomization approach (van de Pol et al. 2016; Bailey & van de Pol 2016 **[A]**).
3. Report FDR or family-wise adjusted values (Benjamini & Hochberg 1995 **[A]**).

Myers (1998) **[A]** showed that most published environment–recruitment correlations fail when re-tested with new data; this analysis is exposed to the same risk.

### 4.4 Trends and autocorrelation

Raw Pearson correlations between trending series are not evidence of association. Options:

- Include a trend term, or detrend both series.
- Model AR(1) errors with GLS.
- Use an effective sample size for correlation tests (Pyper & Peterman 1998 **[A]**).
- Analyze first differences.

The new pipeline does all of these; the main BEUTI result holds under each.

### 4.5 Pseudo-replication across beaches

The environmental predictors are coastwide, or nearly so (two latitude bins). Five beaches responding to one year-level predictor give about 27 independent year-level observations, not 135 (Hurlbert 1984 **[A]**). The notebook's "net significant cells" counts and SE ribbons across beaches and windows treat dependent tests as independent replicates; overlapping windows such as Spawn (May–Jun) and Larval (Jun–Jul) also share months. The new pipeline uses a random year-class effect, or aggregates to a coastwide index, so effects are judged against year-to-year variation.

### 4.6 Validation

- **Selection inside the CV loop.** Variable selection must be repeated inside every training fold (Ambroise & McLachlan 2002; Varma & Simon 2006 **[A]**). `06_forecast_skill.R` shows the difference is large here, from +0.31 to −0.20.
- **Baselines.** Report skill against climatology *and* persistence.
- **Inappropriate validation.** LOOCV on autocorrelated series is optimistic. The rolling-origin CV is appropriate but was applied after selection.
- **A genuine out-of-sample test.** The 2025 shell-length survey is already in the repository, and the 2025-26 abundance estimate will follow. Pre-register a prediction for year class 2024 before it arrives.

### 4.7 Spectral analysis and pre-whitening

- **Spectra.** Smoothed periodograms of 28-point series cannot resolve periods of 5–8 years, since only 3–5 cycles are observed, and no null spectrum was tested. Drop them, or test against an AR(1) null spectrum.
- **Pre-whitening.** Pre-whitening against a post hoc best month and lag removes the predictor that maximizes in-sample fit and then interprets the residual ACF; this is circular.

---

## 5. The robust re-analysis (what was implemented)

All code is in `01_code/R/` (see `01_code/README.md`). Outputs are in `03_analyses/robust-reanalysis/`.

### 5.1 Data products (`01_build_datasets.R` → `02_data/derived/`)

- `survey_beach_year.csv`: abundance, density, survey dates (three date encodings parsed), length composition.
- `env_monthly.csv`:
  - BEUTI and CUTI at 46°N and 47°N, as monthly means from daily values (≥20 days).
  - Columbia discharge.
  - PDO, with month names parsed.
  - A **homogeneous regional SST anomaly**: the mean of station anomalies from open-coast buoys 46029, 46041 and 46211, each relative to its own 1991–2024 monthly climatology; months need ≥240 hourly observations.
- `cohort_table.csv`: one row per beach × year class Y, holding pre-recruits at Y+1, recruits at Y+2, spawners (recruits at Y), survey dates and five pre-specified predictors.

### 5.2 Pre-specified hypotheses

These were fixed in code (`01_build_datasets.R` §4) before any clam–environment correlations were computed in the new framework.

| Predictor | Window (Y = spawning year) | Mechanism |
|---|---|---|
| `beuti_larval` | BEUTI May–Aug Y | Nutrient supply and productivity during the larval period (+), or offshore Ekman transport of larvae (−). Two-sided test |
| `sst_larval` | SST anomaly May–Sep Y | Thermal conditions for spawning and larvae; failed spawning in marine heatwaves (Shanks et al. 2020 **[A]**; not razor-clam-specific) |
| `pdo_larval` | PDO May–Sep Y | Basin-scale regime |
| `q_freshet` | Columbia discharge Apr–Jun Y | Plume extent and larval retention |
| `cuti_winter` | CUTI Nov Y–Feb Y+1 | Winter downwelling and storminess. Small clams are "washed out by the surf and redistributed" (Creekman et al. 1988, p. 131 **[V]**) |

### 5.3 Models

- **Pooled mixed model.** `lmer(log abundance ~ beach + trend + log spawners + survey day + predictor + (1 | year class))` with ML likelihood-ratio tests, Holm-adjusted across 5 predictors × 2 responses.
- **Sensitivity analyses:**
  - no trend term;
  - excluding Kalaloch (different data sources, asynchronous);
  - a coastwide index with GLS-AR(1);
  - beach-specific GLS-AR(1).
- **Full model** with all five predictors.
- **Robustness of the BEUTI result:** loess detrending, first differences, leave-one-year-out, CUTI as a transport-only analogue.

### 5.4 Results

**Pre-recruits of year class Y at survey Y+1** (`confirmatory_pooled.csv`, `confirmatory_coastwide_index.csv`):

| Predictor | Pooled LMM, all beaches | Pooled LMM, no Kalaloch | Coastwide GLS-AR(1) |
|---|---|---|---|
| BEUTI May–Aug | −0.34 (−0.66, −0.01), p = 0.052, Holm 0.47 | −0.49 (−0.79, −0.18), p = 0.003, **Holm 0.031** | −0.58 ± 0.16 SD, p = 0.001, **Holm 0.013** |
| SST anomaly May–Sep | +0.05, p = 0.69 | +0.09, p = 0.48 | +0.07, p = 0.59 |
| PDO May–Sep | −0.03, p = 0.83 | −0.11, p = 0.45 | −0.08, p = 0.58 |
| Discharge Apr–Jun | −0.05, p = 0.71 | −0.10, p = 0.46 | −0.06, p = 0.65 |
| CUTI Nov–Feb | +0.10, p = 0.47 | −0.02, p = 0.86 | +0.12, p = 0.51 |

- Effects are in log units per SD of the predictor; the coastwide column is in index SD per SD.
- Beach-specific BEUTI estimates are negative at all five beaches: Mocrocks −0.59 (p = 0.001), Copalis −0.56 (p = 0.007), Long Beach −1.22 (p = 0.044), Twin Harbors −0.12, Kalaloch −0.23.
- **Recruits at Y+2:** only discharge Apr–Jun is nominally associated, +0.18 (0.05, 0.32), p = 0.011, Holm 0.11. Coastwide: +0.30 ± 0.12, p = 0.015, Holm 0.13.
- **Exploratory window scan.** 570 windows were tested for pre-recruits and 810 for recruits; none passes family-wise control. The 95th percentile of the null max|r| is 0.64 and 0.70 respectively (`window_scan_summary.csv`).
- **Forecast skill vs climatology:**
  - Honest environmental selection: −0.20 (pre-recruits), −0.20 (recruits).
  - Pre-specified BEUTI model: −0.03.
  - Stock carry-over model for recruits: +0.24.

### 5.5 Interpretation

The negative BEUTI association is consistent with two hypotheses:

- **Offshore transport.** Strong upwelling-favorable conditions move larvae away from shore and reduce settlement, as reported for rocky intertidal invertebrates on this coast (e.g. Roughgarden et al. 1988; Connolly et al. 2001 **[C]**). Shanks & Shearman (2009) **[C]** report that some intertidal larvae stay nearshore regardless.
- **Food-web or predator effects** associated with high-nutrient years.

The same-sign but weaker CUTI result (first differences p = 0.03, levels p = 0.31) gives partial support to the transport explanation. This remains a correlation in 27 year classes with an influential year (2008), and it should be presented as hypothesis-generating, ideally tested on the 2025–2027 surveys.

---

## 6. Recommended improvements (prioritized)

**Must do before submission**

1. **Re-frame the response around year classes and actual survey dates.** Use `cohort_table.csv` or an extension of it. Drop the lag-0 summer windows for June-surveyed beaches.
2. **Replace screening with pre-specified hypotheses** (done in `04_confirmatory_models.R`). Report any exploratory search with family-wise calibration (done in `05_window_scan.R`).
3. **Detrend or model trends explicitly, and handle autocorrelation** (GLS-AR(1), random year effects).
4. **Report honest out-of-sample skill** (`06_forecast_skill.R`), with climatology and persistence baselines.
5. **Replace the station-blended temperature** with a homogeneous product: satellite SST at beach-adjacent pixels, or at minimum buoy anomalies (done).
6. **Verify BEUTI homogeneity.** Contact the index authors or check documentation for splices or reanalysis changes. Repeat key results with CUTI and with detrended BEUTI.
7. **Resolve the growth-model citation (Cheng & Kuk 2002) or drop age labels.** Call the classes size classes.
8. **Obtain the variance of each WDFW abundance estimate** and propagate it, either as weights or in a state-space model.

**Should do**

9. **Separate cohorts objectively.** Fit length-frequency mixture models with survey date (e.g. finite normal mixtures by beach-year), and derive an age-1 index independent of the 76 mm boundary. This removes the growth-versus-abundance confound.
10. **Add winter storminess and transport predictors:**
    - significant wave height from NDBC 46029/46041, or a wave hindcast;
    - spring-transition timing from CUTI;
    - a nearshore relaxation index;
    - a lower-river discharge gauge.
11. **Account for harvest when linking pre-recruits(t) to recruits(t+1).** Use survival = R_{t+1} / (P_t + R_t − H_t). Include known closures (domoic acid; McCabe et al. 2016 **[A]**) as covariates or exclusions.
12. **Use a hierarchical (multi-beach) model** with partial pooling of beach-specific effects, instead of 5 separate fits plus averaging. Treat Kalaloch separately or with a data-source covariate.
13. **Pre-register predictions for the 2025 and 2026 surveys.**

**Engineering**

14. **One pipeline, one entry point** (done: `run_all.R`). Pin packages with `renv`. Avoid network access at run time, by caching every download with provenance (URL, date, checksum).
15. **Fix outstanding data-quality issues** (date typos, Kalaloch heaping, Copalis 2003 lengths). Add assertions in `01_build_datasets.R`.
16. **Large binary outputs.**
    - The committed 1000-dpi PNGs (e.g. 12,000 × 12,000 px) and the 44 MB PDF bloat the repository (322 MB including history).
    - Use 300 dpi, and consider Git LFS or excluding regenerable outputs from version control.

---

## 7. What the manuscript can and cannot claim

**Can claim**, with the analyses provided:

- the survey-timing and cohort structure of the WDFW pre-recruit/recruit data;
- that broad environmental screening of 28-year series produces many nominally significant but chance-compatible correlations, and that selection leakage inflates apparent predictive skill (a methods contribution);
- a modest negative association between larval-season upwelling (BEUTI) anomalies and year-class strength, with the stated caveats;
- that stock carry-over (pre-recruit surveys) provides forecast skill that environmental indices do not.

**Cannot claim** without new evidence:

- that BEUTI (or any single factor) "predicts" or "drives" harvestable abundance;
- specific lag structures by beach or size class;
- multi-year periodicities;
- size-class "ages".

---

## References

Verification status: **[V]** verified in source; **[A]** verified from abstract or index record only; **[C]** to be checked.

- Ambroise C, McLachlan GJ (2002) Selection bias in gene extraction on the basis of microarray gene-expression data. *PNAS* 99:6562–6566. doi:10.1073/pnas.102102699 **[A]**
- Bailey LD, van de Pol M (2016) climwin: an R toolbox for climate window analysis. *PLoS ONE* 11:e0167980. doi:10.1371/journal.pone.0167980 **[A]**
- Benjamini Y, Hochberg Y (1995) Controlling the false discovery rate. *J R Stat Soc B* 57:289–300. doi:10.1111/j.2517-6161.1995.tb02031.x **[A]**
- Berry-Powell CA, Forster Z, Ayres D, Parson C, Losee JP (2023) Using the pumped area method for the assessment of recreational razor clam, *Siliqua patula*, populations in Washington State. *J Shellfish Res* 42:91–98. doi:10.2983/035.042.0109 **[A]**
- Connolly SR, Menge BA, Roughgarden J (2001) A latitudinal gradient in recruitment of intertidal invertebrates in the northeast Pacific Ocean. *Ecology* 82:1799–1813 **[C]**
- Creekman LL, Huff J, Andrews G (1988) *The Razor Clam Hatchery 1980–1987*. Washington Department of Fisheries Technical Report No. 1 (file `WDF Razor Clam Hatchery.1988.pdf` in this repository) **[V]**
- Hurlbert SH (1984) Pseudoreplication and the design of ecological field experiments. *Ecol Monogr* 54:187–211. doi:10.2307/1942661 **[A]**
- Jacox MG, Edwards CA, Hazen EL, Bograd SJ (2018) Coastal upwelling revisited: Ekman, Bakun, and improved upwelling indices for the U.S. West Coast. *J Geophys Res Oceans* 123:7332–7350. doi:10.1029/2018JC014187 **[A]**
- Mantua NJ, Hare SR, Zhang Y, Wallace JM, Francis RC (1997) A Pacific interdecadal climate oscillation with impacts on salmon production. *Bull Am Meteorol Soc* 78:1069–1079 **[A]**
- McCabe RM, Hickey BM, Kudela RM, et al. (2016) An unprecedented coastwide toxic algal bloom linked to anomalous ocean conditions. *Geophys Res Lett* 43:10366–10376. doi:10.1002/2016GL070023 **[A]**
- Myers RA (1998) When do environment–recruitment correlations work? *Rev Fish Biol Fish* 8:285–305. doi:10.1023/A:1008828730759 **[A]**
- Prichard D, Theiler J (1994) Generating surrogate data for time series with several simultaneously measured variables. *Phys Rev Lett* 73:951–954 **[C]**
- Pyper BJ, Peterman RM (1998) Comparison of methods to account for autocorrelation in correlation analyses of fish data. *Can J Fish Aquat Sci* 55:2127–2140. doi:10.1139/f98-104 **[A]**
- Roughgarden J, Gaines S, Possingham H (1988) Recruitment dynamics in complex life cycles. *Science* 241:1460–1466 **[C]**
- Shanks AL, Shearman RK (2009) Paradigm lost? Cross-shelf distributions of intertidal invertebrate larvae are unaffected by upwelling or downwelling. *Mar Ecol Prog Ser* 385:189–204 **[C]**
- Shanks AL, et al. (2020) Marine heat waves, climate change, and failed spawning by coastal invertebrates. *Limnol Oceanogr* 65:627–636. doi:10.1002/lno.11331 **[A]** (author list to complete)
- van de Pol M, Bailey LD, McLean N, Rijsdijk L, Lawson CR, Brouwer L (2016) Identifying the best climatic predictors in ecology and evolution. *Methods Ecol Evol* 7:1246–1257. doi:10.1111/2041-210X.12590 **[A]**
- Varma S, Simon R (2006) Bias in error estimation when using cross-validation for model selection. *BMC Bioinformatics* 7:91 **[A]**

# Which ocean conditions explain Pacific razor clam (*Siliqua patula*) recruitment on the Washington coast? A cohort-aligned, calibrated search of 28 years of survey data, 1997–2024

**Draft v0.2, 2 October 2026. Not for circulation.**

Matthew George¹ [co-authors to be added]

¹ [Affiliation to be added]

Corresponding author: [to be added]

> **Status notes for co-authors.**
> - All numbers come from `03_analyses/robust-reanalysis/tables/`, produced by `Rscript 01_code/R/run_all.R`. Table or figure sources are given in square brackets.
> - References carry a verification flag: **[V]** checked in the source, **[A]** abstract or index record only, **[C]** to check. All [A] and [C] items must be confirmed before submission.
> - Sections marked **TODO** need input that the data in this repository cannot supply.

---

## Abstract

Environmental indices are routinely screened for associations with recruitment, but short, autocorrelated, trending time series and flexible choices of lag and seasonal window make spurious associations likely. We set out to identify the ocean conditions that best explain year-class strength of Pacific razor clams (*Siliqua patula*) at five Washington management beaches, using 28 years (1997–2024) of stock-assessment abundance estimates, 218,101 shell-length measurements, and twelve environmental series: upwelling indices (BEUTI, CUTI), buoy and satellite sea-surface temperature, the Pacific Decadal Oscillation, buoy-measured wind stress, wave energy and storm hours, and Columbia River discharge at three gauges. The search was designed so that its answer could be trusted: predictors were aligned to year classes rather than survey years, an a priori set of hypotheses was tested with multiplicity control, the exploratory search over every series and window was calibrated against surrogate data, and the candidate it chose was scored out of sample with selection repeated inside every training window.

- **Survey timing.** Survey dates differed by about two months among beaches (median 6 June to 9 August) and drifted by up to 1.4 days per year. At June surveys, pre-recruits (<76 mm) were survivors of the previous summer's settlement, so environmental windows must be aligned to year classes rather than to survey years.
- **Exhaustive screening.** An exhaustive screen of 900 correlations (3 predictors × 5 seasonal windows × 6 lags × 5 beaches × 2 size classes) produced 83 nominally significant results. That count was not distinguishable from autocorrelation-preserving surrogates (null median 60, 95th percentile 85; p = 0.07), and only 4 survived false-discovery-rate control, all consistent with a shared upward trend rather than a cohort effect.
- **Selection leakage.** Choosing predictors on the full record and then cross-validating gave apparent out-of-sample skill of +0.31 relative to climatology. Repeating the selection inside each training window gave −0.20.
- **A priori hypotheses.** Of five cohort-aligned predictors, only larval-season upwelling (BEUTI, May–Aug of the spawning year) was associated with year-class strength, and negatively: −0.62 SD per SD in a coastwide index (p = 0.005; Holm-adjusted p = 0.052). It was concentrated at interannual frequencies, held under first differencing (p < 0.001), was sensitive to one year, and had no forecast skill.
- **Exploratory search.** Across 12 series and 3,312 windows, no window passed family-wise control (95th percentile of the null maximum |r| = 0.67 for pre-recruits, 0.72 for recruits). The strongest in-sample candidates were upwelling indices in the spring *before* spawning (BEUTI Apr–Jul Y−1, r = +0.55, family-wise p = 0.58) and buoy wave energy or storm hours for recruits (r = −0.60, family-wise p = 0.63). Choosing the best candidate honestly inside each training window gave forecasts worse than climatology (skill −0.77), and the chosen series changed from one origin to the next.
- **Forecasting.** Last year's pre-recruit and recruit abundance forecast recruits better than any environmental model (skill +0.24 overall, up to +0.52 by beach).

We recommend cohort-aligned, pre-specified hypotheses, explicit trend and autocorrelation models, family-wise calibration of any window search, and nested validation for environment–recruitment studies of nearshore invertebrates.

**Keywords:** recruitment; razor clam; upwelling; BEUTI; climate window; multiple testing; cross-validation; selection bias; prospective forecasting; stock assessment; Washington

---

## 1. Introduction

Recruitment variability dominates the dynamics of many exploited marine populations, and links between recruitment and ocean conditions are sought both to understand population regulation and to improve forecasts used in management. A long record of re-evaluation shows that many published environment–recruitment correlations fail when tested with new data (Myers 1998 **[A]**). Three features of typical analyses make spurious associations likely:

- the time series are short and autocorrelated, which inflates the apparent significance of correlations (Pyper & Peterman 1998 **[A]**);
- many candidate predictors, seasonal windows and lags are screened, so the largest correlation is biased upward (van de Pol et al. 2016 **[A]**);
- predictors selected on the full record are then "validated" on the same data, which leaks information and inflates apparent skill (Ambroise & McLachlan 2002; Varma & Simon 2006 **[A]**).

Recent reviews conclude that environmentally informed recruitment forecasts rarely add skill, except where a clear life-history bottleneck can be identified a priori (Haltuch et al. 2019 **[A]**).

The Pacific razor clam (*Siliqua patula*) supports a popular recreational and tribal fishery on the Washington coast. Annual harvest is set from spring–summer stock assessments that estimate the abundance of pre-recruits (<76 mm) and recruits (≥76 mm) on each management beach with a pumped-area survey design (Berry-Powell et al. 2023 **[A]**). Razor clams spawn in spring and summer: natural spawning on Washington beaches occurred from April to July (Creekman et al. 1988, p. 21 **[V]**). Their planktonic larvae spend weeks in the water column before settling; under hatchery conditions the larval and metamorphosis phases took about one month (Creekman et al. 1988, p. 157 **[V]**). Newly settled clams are small and mobile, lack a byssus (p. 98 **[V]**), and are easily "washed out by the surf and redistributed" (p. 131 **[V]**). Recruitment could therefore respond to several processes:

- conditions affecting spawning;
- larval supply, food and transport in the coastal upwelling system;
- survival of small juveniles through their first winter.

Coastal upwelling on this coast is now described by daily indices of vertical transport (CUTI) and nitrate flux (BEUTI) at 1° latitude (Jacox et al. 2018 **[A]**). Over the same period, the region has experienced marine heatwaves, coastwide harmful algal blooms that closed the fishery (McCabe et al. 2016 **[A]**), and shifts in the Pacific Decadal Oscillation (Mantua et al. 1997 **[A]**). We found no peer-reviewed study that relates razor clam recruitment in Washington or Oregon directly to these indices. **TODO:** confirm with a literature search, including WDFW and tribal reports.

An initial exploratory analysis of these data suggested that upwelling during the larval and settlement season predicts harvestable abundance two to five years later, with lags that differ among beaches. Here we re-examine that inference and widen the search. The aim is explicitly exploratory, to identify the environmental series and seasonal windows that best explain year-class strength and its trend, but with the safeguards that make an exploratory answer interpretable. We ask four questions:

1. What do the survey data represent in terms of year classes, given when the surveys are conducted?
2. Are the associations found by exhaustive screening distinguishable from those expected by chance in autocorrelated, trending series?
3. Which a priori, mechanistically motivated predictors are associated with year-class strength?
4. Searching every available environmental series and window with the search itself calibrated, which predictor explains the most, and does it forecast year-class strength out of sample?

## 2. Methods

### 2.1 Study area and survey data

- **Beaches.** We used Washington Department of Fish and Wildlife (WDFW) stock-assessment estimates for five management beaches, from north to south Kalaloch, Mocrocks, Copalis, Twin Harbors and Long Beach (Fig. 1) [`fig_study_area.png`].
- **Abundance estimates.** For each beach and survey year (1997–2024), we used estimated beach-wide abundance of pre-recruits (<76 mm) and recruits (≥76 mm), obtained by expanding surveyed density to habitat area. Seasons are labelled by harvest season (e.g. "2003-04"); the stock-assessment survey occurs in spring or summer of the first year, which we call the survey year.
- **Shell lengths.** We also used 218,101 individual shell-length measurements from the same surveys, 1997–2025, with survey dates. Kalaloch data combine WDFW, Quinault Indian Nation and Olympic National Park surveys.
- **Fishery variables.** Fishery statistics (target exploitation rate 16–40%, harvest) were available; harvest between surveys enters only the prospective forecast protocol (Section 2.5e). Several harvest values in the season summary disagree with WDFW's harvest-monitoring record and are under reconciliation (**TODO**; `docs/harvest-monitoring-review.md`).

### 2.2 Survey timing and year-class alignment

- **Survey timing.** We computed the median date of measured clams for each beach-year. Two beach-years without usable dates (Kalaloch 2001; Copalis 2003, which has no length records) were assigned the beach median. Trends in survey day of year were estimated by least squares.
- **Length composition.** We examined length-frequency distributions grouped by survey timing (before 15 June, 15 June–15 July, after 15 July).
- **Cohort linkage.** We tested whether pre-recruits counted in year t predict recruits counted in year t+1.
- **Year class Y.** On this basis we defined year class Y as the cohort spawned and settling in summer Y, counted as pre-recruits at survey Y+1 and largely as recruits at survey Y+2. All environmental windows were defined relative to Y.

### 2.3 Environmental data

| Variable | Source and processing |
|---|---|
| Upwelling (BEUTI, CUTI) | Daily indices at 46°N (Long Beach) and 47°N (other beaches); monthly means of daily values, ≥20 days required (Jacox et al. 2018 **[A]**). Vintage: the files served by the index authors with creation date 28 September 2026. The authors regenerate the whole record when the underlying reanalysis is updated; the earlier vintage (downloaded before April 2025) differs throughout (daily r = 0.94), and results under it are reported as a sensitivity in Section 3.4 |
| Columbia River discharge | Daily mean discharge at The Dalles, USGS 14105700 (a priori predictor), and at the lowest main-stem gauge, Port Westward near Beaver Army Terminal (14246900, from June 1991) and the Willamette at Portland (14211720), from the USGS Water Data API (exploratory search) |
| PDO | Monthly index, NCEI ERSST v5 as served in October 2026 (the earlier cached copy and NOAA PSL's version differ from it by up to 1 unit in single months, r = 0.98, with no effect on the results, Section 3.4) |
| Satellite SST | NOAA OISST v2.1 (0.25°, daily, 1981–; regional mean over 45.9–48.1°N) and JPL MUR (1 km, monthly, 2002–; mean of 0.1° boxes off the five beaches), via the CoastWatch ERDDAP; anomalies relative to 1991–2020 and 2003–2020 (exploratory search; checks of the buoy series) |
| Buoy winds and waves | Hourly NDBC records from the same six open-coast stations: alongshore wind stress (Large and Pond drag, coastline 10° east of north; positive equatorward, upwelling-favourable), significant wave height squared (wave energy) and the share of hours with Hs > 4 m (storm hours), each homogenised across stations as for temperature (exploratory search) |
| Sea-surface temperature | Hourly NDBC data from six open-coast stations: 46029 Columbia River Bar, 46041 Cape Elizabeth, 46211 Grays Harbor, 46248 Astoria Canyon, and the OOI Westport shelf and offshore moorings 46099 and 46100 |

- **Why a new SST series.** The original exploratory analysis blended raw temperatures from all stations within 50 km of each beach. Station availability changed over time, and several stations were inside estuaries or harbors (e.g. Toke Point in Willapa Bay, Westport Marina in Grays Harbor), so that series contained artificial steps.
- **How it was built.** Monthly means (months with ≥240 hourly observations) were modelled as a station-specific monthly climatology plus a common regional anomaly, with station error variances as precision weights, estimated jointly by alternating least squares (a two-way additive model of the kind used for climate-station homogenisation). Joint estimation avoids the bias that arises when a station with a short record is referenced to its own climatology. The regional anomaly carries a standard error (0.15–0.40 °C depending on the number of reporting stations). Four alternative buoy constructions, including naive buoy anomalies and a beach-local version that admits estuary gauges, agree with it at r ≥ 0.98; two satellite products, NOAA OISST v2.1 (0.25°, 1981–) and JPL MUR (1 km, 2002–), extracted at pixels off each beach, agree with it at monthly r = 0.88 and 0.94; all give the same inference (Supplement S6).
- **Independent checks of the upwelling indices.** The buoy wind stress also serves as a measured counterpart to the model-derived CUTI and BEUTI, and the wave series as a direct measure of the first-winter storminess that CUTI proxies (Supplement S6).

### 2.4 Two arms: a priori hypotheses and a calibrated search

The analysis has an a priori arm and an exploratory arm, kept apart and reported with the same prominence.

- **A priori arm.** Before examining any association with clam abundance in the year-class framework, we defined five predictors, each a window mean relative to year class Y (Table 1). Windows required ≥75% of months to be present. BEUTI and CUTI are reported in their native units; all predictors were standardised (z-scores) for modelling. These are tested with multiplicity control within the family (Section 2.5b).
- **Exploratory arm.** Every environmental series in the record (12 when all products are present: BEUTI and CUTI at 47°N, buoy SST, OISST, MUR, PDO, discharge at The Dalles, Beaver and the Willamette, wind stress, wave energy, storm hours) is searched over every window of 1–4 consecutive months from January of the year before spawning to June of the response survey year. The search is calibrated against surrogate data (Section 2.5c), and the candidate it selects is scored out of sample with the selection repeated inside every training window (Section 2.5d). Its purpose is to find the predictor that best explains year-class strength; the calibration and the out-of-sample score say whether that "best" is better than chance.

**Table 1.** A priori cohort-aligned predictors.

| Predictor | Window (Y = spawning year) | Hypothesised mechanism |
|---|---|---|
| BEUTI | May–Aug Y | Nutrient supply and larval food (+), or offshore larval transport during strong upwelling (−); tested two-sided |
| SST anomaly | May–Sep Y | Thermal conditions for spawning and larval development; reduced spawning during marine heatwaves (Shanks et al. 2020 **[A]**) |
| PDO | May–Sep Y | Basin-scale regime affecting productivity |
| Columbia River discharge | Apr–Jun Y | Freshet plume extent; nearshore retention and stratification |
| CUTI | Nov Y – Feb Y+1 | Winter downwelling and storminess (negative CUTI) during the first winter, when small clams are displaced by surf (Creekman et al. 1988, p. 131 **[V]**) |

### 2.5 Statistical analyses

All analyses used log abundance. Pre-recruit and recruit abundance were never zero.

**(a) Audit of exhaustive screening.**

- *Re-implementation.* We re-implemented the monthly-resolution screen of the original exploratory analysis and confirmed that it reproduces the original correlations (maximum |Δr| < 0.001 across 900 cells). The screen covers 900 Pearson correlations: maximum temperature (station-blended), BEUTI and discharge, five overlapping seasonal windows (Mar–May, May–Jun, Jun–Jul, Jul–Aug, Sep–Oct), lags of 0–5 years before the survey, five beaches, and two size classes.
- *Null distribution.* We generated 2,000 surrogate sets of the ten response series by multivariate Fourier phase randomisation, applying the same random phases to all series (Prichard & Theiler 1994 **[C]**), followed by amplitude adjustment to restore each series' empirical distribution. Each surrogate preserves every series' autocorrelation, trend content and cross-beach correlation, but is independent of the environment by construction.
- *Statistics compared with the null.* We compared the observed number of cells with p < 0.05 and, for each beach × size class, the largest |r| across 90 cells. We also applied Benjamini–Hochberg false-discovery-rate control (Benjamini & Hochberg 1995 **[A]**).
- *Re-testing the selected predictors.* For the 20 predictors selected by the original analysis for its predictive models, we recomputed correlations after linear detrending of both series and with an effective sample size for autocorrelated series (Pyper & Peterman 1998 **[A]**).

**(b) Confirmatory models.**

- *Model.* For each response (pre-recruits of year class Y at survey Y+1; recruits at Y+2) and each predictor, we fitted a linear mixed model by maximum likelihood with lme4 (Bates et al. 2015 **[C]**):

  log abundance ~ beach + linear trend in Y + log spawners + survey day of year + predictor + (1 | year class).

- *Covariates.* Spawners were recruits counted at survey Y (adults present during spawning). Spawners and survey day were centred within beach. The random year-class intercept absorbs coastwide year effects, so a predictor's effect is judged against year-to-year variation, about 27 year classes, rather than 135 beach-years.
- *Inference.* Each predictor was tested with a likelihood-ratio test against the model without it, with Holm adjustment across the 10 tests (5 predictors × 2 responses).
- *Sensitivity analyses:*
  1. no trend term;
  2. excluding Kalaloch;
  3. a coastwide index, the mean across beaches of within-beach standardised residuals of log abundance on spawners and survey day, regressed on trend and predictor with AR(1) errors by generalised least squares;
  4. beach-specific GLS-AR(1) models;
  5. all five predictors in one model.
- *BEUTI robustness.* For BEUTI we additionally used loess detrending, first differences, leave-one-year-out refits, removal of the most influential year, and CUTI over the same window as a transport-only analogue.

**(c) Calibrated exploratory window scan.**

- *Scan.* We scanned all windows of 1–4 consecutive months from January of Y−1 to June of the response survey year for every environmental series: 1,368 windows for pre-recruits and 1,944 for recruits across 12 series (windows with fewer than 15 year classes were excluded). Each window was correlated with the detrended coastwide index; the undetrended correlation and the window's own correlation with year were recorded beside it, so that explaining the trend can be told apart from explaining year-to-year variation.
- *Calibration.* Family-wise significance was obtained by comparing each |r| with the distribution of the maximum |r| over the whole scan across 2,000 phase-randomised surrogates of the index, in the spirit of climate-window analysis (van de Pol et al. 2016; Bailey & van de Pol 2016 **[A]**).

**(d) Forecast skill.**

- *Design.* We evaluated one-step-ahead rolling-origin forecasts for survey years 2011–2024, with a minimum training period of 14 years.
- *Skill score.* SS = 1 − MSE_model / MSE_climatology, where climatology is the training-period mean.
- *Models compared, original framework* (response = log abundance at survey t):
  1. persistence;
  2. "leaky" selection: the best one or two predictors from the 90-cell grid chosen once using all years, then refitted on each training window, as in the original analysis;
  3. "honest" selection: the same selection repeated within each training window;
  4. for recruits, a stock carry-over model, log recruits(t) ~ log pre-recruits(t−1) + log recruits(t−1), with no environmental data.
- *Models compared, year-class framework* (response = log pre-recruits of year class Y at survey Y+1, per beach): persistence; trend; trend + spawners + survey date; BEUTI alone; trend + BEUTI (a priori); and the exploratory candidate: the (series, window) with the strongest detrended correlation with the coastwide index over the training year classes, re-selected from the full catalogue of Section 2.5c inside every training window ("honest") or selected once on all years ("leaky"), then used in the beach model with trend, spawners and survey date. The frequency with which each series was selected across training origins measures the stability of the exploratory choice.

**(e) Prospective forecast protocol.**

- A fixed protocol (`docs/forecast-protocol.md`) issues forecasts for the next survey year with prediction intervals, from models fixed in advance (for pre-recruits: climatology, trend, the a priori BEUTI model, and the exploratory candidate selected on the data available at issue; for recruits: climatology, persistence, the carry-over model, and the carry-over model with the harvest taken between the surveys removed), records them in a ledger with the issue date, code version and data vintage, and scores them on the log scale (error, 95% interval coverage, CRPS, skill versus climatology) when the estimates arrive. Rows are never overwritten.

**Software.** Analyses used R 4.3.3 (R Core Team 2024 **[C]**) with tidyverse, nlme (Pinheiro & Bates **[C]**) and lme4. Code and derived data are in the accompanying repository (`01_code/R/`, `02_data/derived/`); the full pipeline runs in about 2 minutes, and random seeds are fixed.

## 3. Results

### 3.1 Abundance, trends and synchrony

- **Variability.** Abundance varied widely among years (Fig. 2) [`abundance_summary.csv`]. Pre-recruits were more variable than recruits at every beach: SD of log abundance 0.67–1.75 vs 0.39–0.95. Kalaloch was the most variable, with pre-recruits ranging 1,349-fold between minimum and maximum.
- **Trends** [`trends.csv`]:
  - Log recruits increased at Mocrocks (4.0% per year, GLS-AR(1) p = 0.001), Copalis (4.6%, p = 0.002) and Twin Harbors (2.4%, p = 0.008), and possibly Long Beach (4.0%, p = 0.06).
  - Pre-recruits showed no trend except a decline at Twin Harbors (−3.9% per year, p = 0.006).
  - Among predictors, BEUTI (May–Aug) increased strongly (correlation with year 0.81) [`confirmatory_predictor_correlations.csv`]. At 47°N the May–Aug mean rose from 0.25 ± 0.24 in 1988–1998 to 2.97 ± 0.98 in 2011–2024 (mean ± SD of annual values), whereas CUTI doubled (0.19 ± 0.05 to 0.38 ± 0.12) [`env_beuti_latitude_periods.csv`].
- **Synchrony** [`synchrony_summary.csv`]:
  - Recruits were synchronous among the four southern beaches: mean pairwise r = 0.67, or 0.51 after detrending.
  - Pre-recruits were only weakly synchronous: 0.30, or 0.35 detrended.
  - Kalaloch was weakly correlated with the other beaches for both size classes.

### 3.2 Survey timing and what pre-recruits represent

- **Timing differed among beaches and over time** (Fig. 3) [`survey_timing_by_beach.csv`]:

  | Beach | Median survey date | Trend |
  |---|---|---|
  | Long Beach | 6 June | none significant |
  | Copalis | 16 June | +1.4 d/yr, p < 0.001 (late April–May in 1997–1999) |
  | Mocrocks | 18 July | none significant |
  | Kalaloch | 24 July | −1.3 d/yr, p < 0.001 |
  | Twin Harbors | 9 August | −0.8 d/yr, p < 0.001 |

- **Length-frequency** (Fig. 4) [`fig_length_frequency.png`]. Distributions from surveys after mid-July (Twin Harbors, Kalaloch) contained a distinct mode of clams ≤20 mm, consistent with the current year's settlement. Surveys before mid-June contained no such mode; their smallest clams formed a broad 15–50 mm group that must have settled the previous summer, given April–July spawning and roughly one month of larval development.
- **Cohort linkage** (Fig. 5) [`cohort_linkage.csv`]:
  - Log pre-recruits at survey t were correlated with log recruits at survey t+1 at Kalaloch (r = 0.51, p = 0.006), Mocrocks (0.50, p = 0.008), Copalis (0.58, p = 0.002) and Long Beach (0.50, p = 0.009).
  - There was no such link at Twin Harbors (−0.16, p = 0.43), where August pre-recruit counts mix new settlers with year-old clams.
  - Same-year correlations between pre-recruits and recruits were weak (−0.24 to 0.40).

### 3.3 Exhaustive screening is compatible with chance

- **Global count.** Of 900 correlations in the original monthly screen, 83 had p < 0.05, nearly twice the 45 expected for independent tests. Autocorrelation-preserving surrogates produced a median of 60 such cells (95th percentile 85), so the excess was not significant (p = 0.07) [`null_audit_global.csv`].
- **Per series** (Fig. 6) [`null_audit_by_series.csv`]. Within each beach × size class, the largest |r| over 90 cells was 0.49–0.74, against surrogate medians of 0.48–0.64. Only one series, Mocrocks recruits, exceeded its family-wise 95% threshold (p = 0.023; 0.23 after Bonferroni across the 10 series).
- **FDR survivors.** Four cells survived FDR control (q < 0.05). All four were Mocrocks recruits × BEUTI, at lags 1, 2, 3 and 5 with r between 0.66 and 0.74; lag 4 just missed the threshold (r = 0.64, q = 0.054). The near-identical correlation across lags points to a common trend rather than a cohort-specific effect.
- **Selected predictors after detrending** [`null_audit_selected_predictors.csv`]:
  - Copalis recruits × BEUTI (Jul–Aug, lag 4): r = 0.59 → 0.02.
  - Mocrocks recruits × BEUTI (Jun–Jul, lag 5): r = 0.74 → 0.44.
  - Long Beach recruits × BEUTI (Jun–Jul, lag 5): r = 0.57 → 0.33.
  - Nine of the ten predictors selected for pre-recruits had lags of 2–5 years, implausible for clams that are about one year old.

### 3.4 A priori, cohort-aligned predictors

**Pre-recruits (year class Y at survey Y+1)** (Table 2; Fig. 7) [`confirmatory_pooled.csv`, `confirmatory_coastwide_index.csv`]:

- **BEUTI was the only predictor associated with year-class strength, and the association was negative.** Higher May–Aug BEUTI in the spawning year was followed by fewer pre-recruits.
  - All five beaches: −0.31 log units per SD (95% CI −0.67 to +0.06; LRT p = 0.11; Holm p = 1.0).
  - Excluding Kalaloch: −0.45 (−0.79 to −0.10; p = 0.014; Holm p = 0.14).
  - Coastwide index (GLS-AR(1)): −0.62 ± 0.20 SD per SD (p = 0.005; Holm p = 0.052).
- **Beach-specific estimates** were negative at all five beaches (Fig. 8) [`confirmatory_by_beach.csv`]: Mocrocks −0.71 (p = 0.001), Long Beach −1.24 (p = 0.073), Copalis −0.45 (p = 0.076), Kalaloch −0.72 (p = 0.15), Twin Harbors −0.11 (p = 0.57).
- **No other predictor approached significance:** SST anomaly, PDO, freshet discharge and winter CUTI all had p ≥ 0.50 in the primary model.

**Robustness of the BEUTI association** [`confirmatory_beuti_robustness.csv`]:

- *Detrending method.* It held under loess detrending (r = −0.43, p = 0.026) and first differences (slope −0.70, p < 0.001), and was weaker when only a linear trend was removed by ordinary least squares (−0.36, p = 0.098). The association is therefore expressed at interannual rather than decadal frequencies.
- *Influential year.* All leave-one-year-out estimates were negative (−0.25 to −0.43). Removing the most influential year (2020) reduced the estimate to −0.26 (p = 0.25).
- *Without the trend term.* The pooled estimate was −0.11 (p = 0.41), because BEUTI and year are strongly correlated (r = 0.81).
- *Post-2003 only.* −0.50 (p = 0.025), the period with four or more open-coast buoys and the full set of beaches.
- *CUTI analogue.* CUTI over the same window showed the same sign but a weaker association (linear −0.08, p = 0.63; first differences −0.37, p = 0.083).
- *Index vintage.* Under the earlier vintage of the index (downloaded before April 2025; daily r with the current files 0.94) the same tests gave a more precise estimate: coastwide −0.58 ± 0.16 (p = 0.001, Holm 0.013); pooled −0.34 (p = 0.052); without Kalaloch −0.49 (Holm 0.031); first differences −0.57 (p < 0.001) [`env_index_vintage_effects.csv`; `docs/environmental-record-options.md` §6.1]. The sign and size of the association do not depend on the vintage; whether it clears a Holm-corrected threshold of 0.05 does. The null results for CUTI (winter) and the PDO held under both vintages and under both current PDO sources.

**Recruits (year class Y at survey Y+2):**

- Only freshet discharge (Apr–Jun Y) was nominally associated: +0.18 log units per SD (0.05–0.32; p = 0.011; Holm p = 0.11), coastwide +0.30 ± 0.12 (p = 0.015; Holm p = 0.13).
- The association weakened when Kalaloch was excluded (+0.10, p = 0.12).
- In the full model with all five predictors, the estimates were similar: BEUTI −0.47 (t = −1.90) for pre-recruits and discharge +0.21 (t = 2.82) for recruits [`confirmatory_full_model.csv`].

**Table 2.** A priori predictors of pre-recruit abundance of year class Y at survey Y+1. Effects per 1 SD of predictor (95% CI); pooled models in log units, coastwide index in index SD. Holm adjustment across 5 predictors × 2 responses. Current index vintage.

| Predictor | Pooled LMM, all beaches | Pooled LMM, excl. Kalaloch | Coastwide GLS-AR(1) |
|---|---|---|---|
| BEUTI May–Aug | −0.31 (−0.67, +0.06); p = 0.11; Holm 1.0 | −0.45 (−0.79, −0.10); p = 0.014; Holm 0.14 | −0.62 ± 0.20; p = 0.005; Holm 0.052 |
| SST anomaly May–Sep | +0.05 (−0.21, 0.30); p = 0.71 | +0.08 (−0.17, 0.33); p = 0.55 | +0.07 ± 0.14; p = 0.63 |
| PDO May–Sep | +0.02 (−0.25, 0.29); p = 0.89 | −0.05 (−0.32, 0.21); p = 0.69 | −0.03 ± 0.14; p = 0.82 |
| Discharge Apr–Jun | −0.05 (−0.30, 0.20); p = 0.71 | −0.10 (−0.35, 0.16); p = 0.46 | −0.06 ± 0.13; p = 0.65 |
| CUTI Nov–Feb | +0.09 (−0.17, 0.35); p = 0.50 | +0.04 (−0.21, 0.29); p = 0.76 | +0.15 ± 0.17; p = 0.39 |

### 3.5 Calibrated search over all series and windows

No window passed family-wise control for either response (Fig. 9) [`window_scan_summary.csv`, `window_scan_top10.csv`, `window_scan_best_per_variable.csv`]:

| Response | Series × windows tested | Nominal p < 0.05 | 95th percentile of null max\|r\| | Strongest window (detrended r; family-wise p) |
|---|---|---|---|---|
| Pre-recruits | 12 × 1,368 | 58 | 0.67 | BEUTI Apr–Jul Y−1 (+0.55; 0.58) |
| Recruits | 12 × 1,944 | 211 | 0.72 | Wave energy Jul–Aug Y (−0.60; 0.63) |

- **Pre-recruits.** The ten strongest windows were all between r = 0.47 and 0.55 and none approached the null threshold: upwelling (BEUTI or CUTI) in March–July of the year *before* spawning, positive, in seven of them; Willamette discharge in November of the spawning year (−0.49); storm hours in January of Y−1 (+0.47). Each series' best window had |r| between 0.34 (The Dalles) and 0.55 [`window_scan_best_per_variable.csv`]. The a priori BEUTI window (May–Aug Y) had detrended r = −0.33 in this scan; the strongest BEUTI windows are in the preceding spring with the opposite sign, and detrended BEUTI is weakly negatively autocorrelated, so the two cannot be separated with 27 year classes.
- **Recruits.** The strongest windows were buoy wave energy in July–August of the spawning year (−0.60), storm hours in October–November of Y+1 (−0.59), wind stress in March–April of the survey year (+0.59) and discharge at The Dalles in March of the survey year (−0.56, the "spring discharge, lag 0" predictor the original analysis selected at two beaches). Family-wise p ranged from 0.63 to 0.84.
- **Trend attribution** [`window_scan_trend_attribution.csv`]. The pre-recruit index has no trend (r with year 0.06), so nothing can explain its trend. The recruit index does (r = 0.35), and the windows that correlate most with it before detrending are those that trend themselves: CUTI and BEUTI in February–April of the survey year (raw r = 0.62 and 0.59, of which r with year 0.55 and 0.52). The wave, storm, wind and discharge windows above have no trend (|r with year| ≤ 0.30), so their correlations are interannual. With 28 years, any trending series "explains" a trending response; only the detrended association is testable.

### 3.6 Forecast skill

(Fig. 10; Table 3) [`forecast_skill_original_framework.csv`, `forecast_skill_original_by_series.csv`, `forecast_skill_cohort_framework.csv`]

- **Leaky vs honest selection.** Predictor selection on the full record produced apparent skill of +0.31 (pre-recruits) and +0.30 (recruits). When selection was repeated within each training window, skill was negative: −0.20 for both, i.e. worse than climatology.
- **Persistence** performed poorly for pre-recruits (−1.08), consistent with their lack of autocorrelation.
- **Stock carry-over** (recruits from the previous year's pre-recruits and recruits) had positive skill overall (+0.24), and at Copalis (+0.52), Mocrocks (+0.45) and Long Beach (+0.35).
- **Year-class pre-recruits** (Fig. 11) [`forecast_skill_cohort_framework.csv`, `forecast_selection_stability.csv`]. No model beat climatology overall. The trend alone scored −0.09, the a priori trend + BEUTI model −0.12 (BEUTI alone −0.15), and adding spawners and survey date to the trend −0.25. The exploratory candidate chosen honestly inside each training window scored −0.77, worse than every other model, while the same candidate chosen once on all years scored −0.21: the gap between the two is the selection bias of the search. Trend + BEUTI was positive at Mocrocks (+0.19) and Twin Harbors (+0.08), about zero at Long Beach, and negative at Copalis (−0.11) and Kalaloch (−0.27). The honest search chose buoy SST in July of Y−1 at 6 of 13 training origins, BEUTI at 3, CUTI at 3 and storm hours at 1, and chose BEUTI (Apr–Jul Y−1) on the full record; the candidate it would issue today is therefore not the one it would have issued in most earlier years.

**Table 3.** Rolling-origin forecast skill relative to climatology (survey years 2011–2024; 70 forecasts per row in the original framework, 65 in the year-class framework).

| Response | Model | Skill |
|---|---|---|
| Pre-recruits (original framework) | Persistence | −1.08 |
| | Leaky selection, 1 / 2 predictors | +0.31 / +0.35 |
| | Honest selection, 1 / 2 predictors | −0.20 / −0.17 |
| Recruits (original framework) | Persistence | −0.34 |
| | Stock carry-over (no environment) | **+0.24** |
| | Leaky selection, 1 / 2 predictors | +0.30 / +0.30 |
| | Honest selection, 1 / 2 predictors | −0.20 / −0.11 |
| Year-class pre-recruits | Trend | −0.09 |
| | Trend + BEUTI (a priori) | −0.12 |
| | Exploratory candidate, selected on all years (leaky) | −0.21 |
| | Exploratory candidate, re-selected inside each training window (honest) | −0.77 |

## 4. Discussion

### 4.1 Principal findings

Four conclusions follow.

1. **What the survey measures.** The survey's pre-recruit and recruit categories correspond to year classes only after accounting for when each beach is surveyed. At June surveys, pre-recruits are about one year old, so environmental windows in the summer of the survey year cannot have caused their abundance. Several "lag-0" associations from the original analysis involved such windows.
2. **Why the screen misled.** Exhaustive screening of seasonal windows and lags in 28-year series produced a set of strong-looking correlations, but its overall yield was compatible with chance once autocorrelation and cross-beach dependence were respected. The few robust-looking signals reflected shared trends. Validation that did not repeat predictor selection inflated forecast skill from negative to substantially positive values. These are general hazards (Myers 1998; Haltuch et al. 2019 **[A]**), and they were large here.
3. **What survives.** The a priori, cohort-aligned analysis found one moderately supported association, between larval-season upwelling (BEUTI) and year-class strength. It was **negative**, the opposite of the positive association implied by the original screen, and it is borderline after multiplicity correction on the current vintage of the index. The positive screen results were artefacts of a shared trend, since both BEUTI and recruit abundance increased over the period.
4. **What the wider search found.** Searching twelve series and 3,312 windows, calibrated against the same search in surrogate data, found nothing that passed family-wise control, and the candidate it selected forecast worse than climatology once selection was done honestly. The strongest in-sample candidates (upwelling in the spring before spawning, wave energy and storm hours for recruits) are the hypotheses worth carrying into the prospective test, not findings. The answer to "which predictor best explains recruitment" is therefore: none better than chance on this record, with BEUTI in the larval season the only a priori candidate with retrospective support.

### 4.2 Why might strong upwelling summers produce weaker year classes?

Several mechanisms could produce a negative association:

- **Offshore transport of larvae.** Upwelling-favourable winds drive offshore Ekman transport of surface waters. Recruitment of several intertidal invertebrates on this coast has been linked to transport and relaxation dynamics (Roughgarden et al. 1988; Connolly et al. 2001 **[C]**), although cross-shelf larval distributions of some taxa appear insensitive to upwelling (Shanks & Shearman 2009 **[C]**). The same-sign but weaker CUTI association is partly consistent with a transport mechanism.
- **Water-mass or food-web effects.** BEUTI's nitrate component dominates its trend and interannual variability here, which points instead to effects associated with the source and nutrient content of upwelled water, such as cold, low-oxygen or low-pH water reaching the nearshore, or altered predator fields.
- **Settlement-habitat disturbance.** Physical disturbance of settlement habitat could also contribute.

The data cannot distinguish these mechanisms. The association is concentrated at interannual frequencies, depends substantially on one year, and adds no forecast skill. We therefore regard it as a hypothesis to be tested with independent data, not as an established driver. Survey years 2025–2027 provide the first such test under the prospective protocol (Section 4.5).

### 4.3 The BEUTI trend and the index vintage

May–Aug BEUTI at 47°N increased about twelvefold over the record, far more than CUTI relative to its variability, implying a large increase in the nitrate concentration of upwelled water. Measured buoy winds reproduce CUTI's interannual variation (r = 0.66–0.72) and its upward trend (about a fifth to a quarter of the mean per decade in both), so the transport component of the increase is real; they explain only a tenth of BEUTI's detrended variance, and BEUTI's trend is three times larger relative to its mean, so the nitrate component is not independently corroborated [`env_wind_vs_upwelling.csv`]. The vintage of the index used here carries a level shift at 47°N at the 2010/2011 boundary of the underlying reanalysis (+1.2 units after trend, p = 0.03; none at 46°N), which the earlier vintage did not [`env_beuti_step_tests.csv`, `env_index_vintages.csv`]. Before the trend is interpreted ecologically, the homogeneity of the index and the reason for the revision should be confirmed with its developers. **TODO:** contact the index authors. Our main inferences rely on detrended or differenced BEUTI, and the first-difference estimate is the strongest of all (−0.70, p < 0.001), so a level shift does not create the association; the vintage sensitivity (Section 3.4) shows that the association keeps its sign and size under either vintage.

### 4.4 Implications for forecasting and management

The pre-recruit survey already carries the forecasting signal. Recruits in year t+1 are predicted by pre-recruits in year t at four of five beaches, and a simple carry-over model forecast recruits better than any environmental model we tested. For pre-recruit abundance one year earlier, no environmental model, a priori or searched, beat the beach mean out of sample. The practical message is that an environmental forecast of a razor clam year class is not available from this record, and that a candidate selected by searching will look better in hindsight than it performs.

Recruit abundance was more synchronous among beaches than pre-recruit abundance (detrended mean r 0.51 vs 0.35). This is consistent with recruits integrating several year classes, which averages out local settlement noise. It may also reflect coastwide influences on growth or survival in the second year, or shared management. Kalaloch, whose data combine three survey programmes, behaved differently from the other beaches in almost every analysis.

### 4.5 Limitations and next steps

- **Size classes are not ages.** The 76 mm boundary splits the age-1 cohort at late surveys, so environmental effects on growth can appear as effects on abundance. Date-aware length-mixture models could separate cohorts objectively.
- **Observation error.** The abundance estimates have no published sampling variance; WDFW's harvest-monitoring work quantifies the uncertainty of the harvest estimates but holds no stock-assessment variance [`docs/harvest-monitoring-review.md`]. A two-stage (transects within beach, plots within transect) variance from the raw pumped-area counts is the direct route; process and observation error can then be separated in a state-space model. **TODO.**
- **Harvest.** Harvest between surveys (exploitation targets 16–40%) affects recruit abundance and the carry-over relationship. The protocol's escapement model removes it; several harvest values in the season summary are under reconciliation with the harvest-monitoring record. **TODO.**
- **Environmental coverage.** Satellite SST, buoy winds and waves and lower-river gauges are now in the record and in the search. Still missing are plume salinity at Long Beach, nearshore temperature in the surf zone, and a transport index for larvae.
- **Short record.** With about 27 independent year classes, power to detect moderate effects after multiplicity correction is limited; non-significant a priori predictors are not evidence of no effect, and a search of this size cannot resolve effects below about |r| = 0.65.
- **Prospective test.** Forecasts are now issued under a fixed protocol with a ledger that is scored when each year's estimates arrive (Section 2.5e; `docs/forecast-protocol.md`). The ledger holds survey 2025 (year class 2024), issued on 2 October 2026 from data through survey 2024 [`forecast_ledger.csv`]: pre-recruits by climatology, trend, the a priori BEUTI model and the exploratory candidate (BEUTI Apr–Jul of Y−1 on the full record); recruits by climatology, persistence, carry-over and carry-over with escapement. The carry-over intervals are the narrowest, for example Copalis 5.4 million (2.5–11.9) and Mocrocks 6.9 million (3.4–13.7); the pre-recruit intervals span one to three orders of magnitude. Because the 2025 and 2026 surveys have already happened and WDFW holds their estimates, these forecasts are pseudo-prospective (the estimates have not entered the analysis, but the analysts are not blind to them); the first fully prospective target is survey 2027, to be issued in spring 2027 before the survey. Earlier proof-of-concept forecasts for 2025 made the same day are kept and will be scored alongside.

## 5. Conclusions

For Washington razor clams, broad environmental screening of survey data produced appealing but largely chance-compatible associations, and its apparent predictive skill disappeared under honest validation. Repeating the search over twelve environmental series with the search itself calibrated, and scoring its choice with selection repeated inside every training window, gave the same answer: no environmental predictor explains year-class strength better than chance on this record, and the one a priori association with retrospective support, larval-season upwelling, is negative, borderline after multiplicity correction and without forecast skill. Aligning analyses to year classes and actual survey dates, keeping a priori and exploratory arms apart, modelling trends and autocorrelation, calibrating the search, validating out of sample and committing to a scored prospective test changed both the strength and the direction of the conclusions. We recommend these practices for environment–recruitment analyses of short, autocorrelated monitoring series, and we regard the prospective ledger, not this retrospective record, as the test that will decide.

---

## Data and code availability

- **Code:** all code, derived data and outputs are in the project repository (`01_code/R/`, `02_data/derived/`, `03_analyses/robust-reanalysis/`).
- **Raw survey data:** provided by WDFW (**TODO:** data-sharing statement and permissions, including tribal and NPS data for Kalaloch).
- **Public environmental data:** BEUTI/CUTI (Jacox et al. 2018; vintage created 2026-09-28, and the earlier vintage to 2025-04 used for the sensitivity analysis), NDBC buoys (temperature, winds, waves), USGS 14105700, 14246900 and 14211720, NCEI and PSL PDO, NOAA OISST v2.1 and JPL MUR via the CoastWatch ERDDAP. The fetch scripts and provenance files are in the repository (`01_code/R/acquire/`, `02_data/Environmental Data/external/`).

## Acknowledgements

**TODO.** WDFW razor clam program staff; Quinault Indian Nation; Olympic National Park; funding.

---

## Figures

Figures are generated by `01_code/R/run_all.R` into `03_analyses/robust-reanalysis/figures/`.

![**Fig. 1.** Study area: management beaches (red), open-coast buoys used for the regional SST anomaly (triangles), and the 46°N and 47°N upwelling-index latitude bins.](../03_analyses/robust-reanalysis/figures/fig_study_area.png)

![**Fig. 2.** Estimated abundance of pre-recruits (<76 mm) and recruits (≥76 mm) by beach and survey year (log scale).](../03_analyses/robust-reanalysis/figures/fig_abundance_timeseries.png)

![**Fig. 3.** Median survey date by beach and year. Crosses mark beach-years with imputed dates.](../03_analyses/robust-reanalysis/figures/fig_survey_timing.png)

![**Fig. 4.** Length-frequency distributions by beach and survey timing. The dashed line marks 76 mm. A ≤20 mm current-year settler mode is present only in surveys after mid-July.](../03_analyses/robust-reanalysis/figures/fig_length_frequency.png)

![**Fig. 5.** Log pre-recruits at survey t vs log recruits at survey t+1, with least-squares lines.](../03_analyses/robust-reanalysis/figures/fig_cohort_linkage.png)

![**Fig. 6.** Largest |r| in the 90-cell screening grid for each beach and size class (red) against 2,000 phase-randomised surrogates (grey).](../03_analyses/robust-reanalysis/figures/fig_null_audit.png)

![**Fig. 7.** Effects of pre-specified cohort-aligned predictors (per SD, 95% CI) on pre-recruits of year class Y at survey Y+1 and recruits at survey Y+2. Primary model, model excluding Kalaloch, and model without a trend term.](../03_analyses/robust-reanalysis/figures/fig_confirmatory_forest.png)

![**Fig. 8.** Beach-specific GLS-AR(1) estimates for the same predictors.](../03_analyses/robust-reanalysis/figures/fig_beach_heterogeneity.png)

![**Fig. 9.** Calibrated window scan for pre-recruits: detrended correlation of every 1–4 month window of twelve environmental series with the coastwide year-class index. No cell passes family-wise control.](../03_analyses/robust-reanalysis/figures/fig_window_scan_pre.png)

![**Fig. 10.** Rolling-origin forecast skill relative to climatology in the original framework for leaky vs honest predictor selection, persistence, and stock carry-over.](../03_analyses/robust-reanalysis/figures/fig_forecast_skill.png)

![**Fig. 11.** Rolling-origin forecast skill for year-class pre-recruits: the exploratory candidate selected honestly inside each training window versus selected once on all years, against trend and a priori models.](../03_analyses/robust-reanalysis/figures/fig_forecast_skill_cohort.png)

## Supplementary material (to assemble)

- **S1.** Station audit of the original temperature series (`docs/methodology-review.md` §2.4).
- **S2.** Full null-audit tables (`null_audit_by_series.csv`, `null_audit_selected_predictors.csv`, `null_audit_all_cells.csv`).
- **S3.** Full model and beach-specific results (`confirmatory_full_model.csv`, `confirmatory_by_beach.csv`).
- **S4.** Window-scan results for recruits and the selection record of the honest search (`fig_window_scan_rec.png`, `window_scan_all.csv`, `window_scan_trend_attribution.csv`, `forecast_skill_cohort_selections.csv`).
- **S7.** Forecast protocol and ledger (`docs/forecast-protocol.md`, `forecast_ledger.csv`, `forecast_scores.csv`).
- **S5.** Data-quality notes (`task.md` T20–T24).
- **S6.** Environmental-record diagnostics: coverage, legacy station-blend offsets, alternative SST constructions including satellite products, BEUTI/CUTI homogeneity, index vintages, buoy winds and waves against the indices, lower-river gauges (`docs/environmental-record-options.md`; `fig_env_coverage.png`, `fig_legacy_idw_vs_homogenized.png`, `fig_sst_homogenization.png`, `fig_beuti_homogeneity.png`, `fig_index_vintages.png`, `fig_wind_vs_upwelling.png`; `env_*.csv`).

---

## References

- Ambroise C, McLachlan GJ (2002) Selection bias in gene extraction on the basis of microarray gene-expression data. *Proceedings of the National Academy of Sciences USA* 99:6562–6566. https://doi.org/10.1073/pnas.102102699 **[A]**
- Bailey LD, van de Pol M (2016) climwin: an R toolbox for climate window analysis. *PLoS ONE* 11:e0167980. https://doi.org/10.1371/journal.pone.0167980 **[A]**
- Bates D, Mächler M, Bolker B, Walker S (2015) Fitting linear mixed-effects models using lme4. *Journal of Statistical Software* 67(1):1–48 **[C]**
- Benjamini Y, Hochberg Y (1995) Controlling the false discovery rate: a practical and powerful approach to multiple testing. *Journal of the Royal Statistical Society B* 57:289–300 **[A]**
- Berry-Powell CA, Forster Z, Ayres D, Parson C, Losee JP (2023) Using the pumped area method for the assessment of recreational razor clam, *Siliqua patula*, populations in Washington State. *Journal of Shellfish Research* 42:91–98. https://doi.org/10.2983/035.042.0109 **[A]**
- Connolly SR, Menge BA, Roughgarden J (2001) A latitudinal gradient in recruitment of intertidal invertebrates in the northeast Pacific Ocean. *Ecology* 82:1799–1813 **[C]**
- Creekman LL, Huff J, Andrews G (1988) *The Razor Clam Hatchery 1980–1987*. Technical Report No. 1, Washington Department of Fisheries, Olympia **[V]**
- Haltuch MA, Brooks EN, Brodziak J, et al. (2019) Unraveling the recruitment problem: a review of environmentally-informed forecasting and management strategy evaluation. *Fisheries Research* 217:198–216. https://doi.org/10.1016/j.fishres.2018.12.016 **[A]**
- Jacox MG, Edwards CA, Hazen EL, Bograd SJ (2018) Coastal upwelling revisited: Ekman, Bakun, and improved upwelling indices for the U.S. West Coast. *Journal of Geophysical Research: Oceans* 123:7332–7350. https://doi.org/10.1029/2018JC014187 **[A]**
- Mantua NJ, Hare SR, Zhang Y, Wallace JM, Francis RC (1997) A Pacific interdecadal climate oscillation with impacts on salmon production. *Bulletin of the American Meteorological Society* 78:1069–1079 **[A]**
- McCabe RM, Hickey BM, Kudela RM, et al. (2016) An unprecedented coastwide toxic algal bloom linked to anomalous ocean conditions. *Geophysical Research Letters* 43:10366–10376. https://doi.org/10.1002/2016GL070023 **[A]**
- Myers RA (1998) When do environment–recruitment correlations work? *Reviews in Fish Biology and Fisheries* 8:285–305. https://doi.org/10.1023/A:1008828730759 **[A]**
- Pinheiro J, Bates D, R Core Team. nlme: Linear and nonlinear mixed effects models. R package **[C]**
- Prichard D, Theiler J (1994) Generating surrogate data for time series with several simultaneously measured variables. *Physical Review Letters* 73:951–954 **[C]**
- Pyper BJ, Peterman RM (1998) Comparison of methods to account for autocorrelation in correlation analyses of fish data. *Canadian Journal of Fisheries and Aquatic Sciences* 55:2127–2140. https://doi.org/10.1139/f98-104 **[A]**
- R Core Team (2024) R: A language and environment for statistical computing. R Foundation for Statistical Computing, Vienna **[C]**
- Roughgarden J, Gaines S, Possingham H (1988) Recruitment dynamics in complex life cycles. *Science* 241:1460–1466 **[C]**
- Shanks AL, Shearman RK (2009) Paradigm lost? Cross-shelf distributions of intertidal invertebrate larvae are unaffected by upwelling or downwelling. *Marine Ecology Progress Series* 385:189–204 **[C]**
- Shanks AL, et al. (2020) Marine heat waves, climate change, and failed spawning by coastal invertebrates. *Limnology and Oceanography* 65:627–636. https://doi.org/10.1002/lno.11331 **[A]** (author list to complete)
- van de Pol M, Bailey LD, McLean N, Rijsdijk L, Lawson CR, Brouwer L (2016) Identifying the best climatic predictors in ecology and evolution. *Methods in Ecology and Evolution* 7:1246–1257. https://doi.org/10.1111/2041-210X.12590 **[A]**
- Varma S, Simon R (2006) Bias in error estimation when using cross-validation for model selection. *BMC Bioinformatics* 7:91 **[A]**

# Building a homogeneous environmental record: diagnosis and options

*2 October 2026. Companion to `01_code/R/09_env_record_diagnostics.R`, whose outputs (`03_analyses/robust-reanalysis/figures/fig_env_*.png`, `fig_legacy_idw_vs_homogenized.png`, `fig_sst_homogenization.png`, `fig_beuti_homogeneity.png`, `fig_index_vintages.png`, `fig_wind_vs_upwelling.png`, and `tables/env_*.csv`) are cited throughout. Numbers are from the 2026-10-02 run. Sections 1–5 were written before network access was available; §6 reports what the external products showed once they had been fetched.*

The environmental side of this analysis was assembled from whatever was available near each beach: a dozen buoys and shore gauges with different start dates, three OOI moorings for salinity from 2014, two upwelling indices derived from an ocean model, a river gauge 300 km upstream, and a basin-scale climate index. This document (1) quantifies how much that patchwork matters, (2) describes the fix already implemented for temperature, and (3) evaluates the options for a more homogeneous and more mechanistic record, with a recommended sequence.

---

## 1. Diagnosis

### 1.1 Coverage

`fig_env_coverage.png` shows every source by month. The salient facts (`env_coverage_by_station.csv`, `env_coverage_by_year.csv`):

| Source | Record | Coverage of the 336 survey-period months (1997–2024) | Comment |
|---|---|---|---|
| BEUTI / CUTI, 46N and 47N | 1988-01 to 2025-04 (cached); current vintage to 2026-09 | 100% | Model-derived; see §1.3 and §6.1 |
| PDO | 1950 to 2026 | 100% | Basin scale |
| Columbia discharge, The Dalles | 1990 to 2026 | 100% | 300 km upstream of the mouth |
| 46041 Cape Elizabeth (open coast) | 1990–2024 | 79% full months | The only long northern buoy; gaps in 1997–99, 2006–07, 2022, 2024 |
| 46029 Columbia River Bar (open coast) | 1991–2025 | 77% | Missing 2005–2007 |
| 46211 Grays Harbor (open coast) | 2004–2025 | 71% | |
| 46248 Astoria Canyon; 46099, 46100 OOI Westport (open coast) | 2011 / 2016 onward | 25–46% | |
| TOKW1 Toke Point, WPTW1 Westport Marina, LAPW1 La Push, NEAW1 Neah Bay (estuary/harbor) | 2005–2008 onward | 59–64% | Inside bays or harbors |
| 46243 Clatsop Spit, 46096 SATURN-02, 46127 South Jetty (river mouth) | 2009 / 2011 / 2016 | 54% / 5% / 1% | Plume-influenced |
| OOI Westport salinity moorings (3) | 2014/15–2025 | 31–35% | Too short for the 28-year analysis |

For 1997–2003 the whole coast is represented by at most two open-coast buoys, and in 1998 and 2007 only 8 and 10 months have any open-coast temperature. Nothing in the record measures waves, nearshore winds, chlorophyll, plume salinity at Long Beach, or sand-bar dynamics.

### 1.2 Temperature: the legacy blend has station-switch artifacts

The legacy notebook estimated each beach's water temperature by inverse-distance weighting of *raw* monthly values from every station within 50 km. Because the station set changes over time, each beach series is a concatenation of different instruments in different water bodies. `fig_legacy_idw_vs_homogenized.png` shows the legacy series (points, coloured by the dominant station) against the homogenised regional anomaly described in §2 (line). The era-mean offsets (`env_legacy_idw_station_eras.csv`) are:

| Beach | Dominant station (era) | Months | Mean offset of legacy series, deg C | SD of monthly difference |
|---|---|---|---|---|
| Long Beach | 46029 Columbia River Bar (1991–2004) | 130 | +0.15 | 0.37 |
| Long Beach | TOKW1 Toke Point, Willapa Bay (2005–2011) | 46 | **+0.54** | 1.18 |
| Long Beach | 46243 Clatsop Spit, river mouth (2009–2025) | 191 | **−0.26** | 0.36 |
| Kalaloch | 46041 Cape Elizabeth (1990–2024) | 349 | +0.11 | 0.70 |
| Kalaloch | LAPW1 La Push harbor (2006–2025, when it dominates) | 44 | **−0.92** | 1.30 |
| Twin Harbors | WPTW1 Westport Marina (2008–2025) | 207 | −0.17 | 0.38 |
| Copalis, Mocrocks | 46041 (to 2004/2008) then WPTW1 (2008–2025) | 148–207 | +0.06 to +0.10, then −0.05 to −0.07 | 0.25–0.37 |

Two things follow. First, the Long Beach series has a 0.8 deg C step between its Toke Point era and its Clatsop Spit era, and a month-to-month scatter three times larger in the estuary era; any "max temperature" predictor built from it for 2005–2011 is largely estuary noise. Second, even where offsets are small (Copalis, Mocrocks), the sign flips at the station switch in 2008, which is exactly the kind of structure a lag-correlation screen will pick up.

Across stations, monthly anomalies at the northern and southern long buoys (46041, 46029) correlate at r = 0.85; harbor gauges correlate with buoys at 0.76–0.86. So a single regional index captures most of the common variability, but not all of it, and harbor gauges carry additional local variance.

### 1.3 Upwelling indices: a large trend, but no detectable splice

BEUTI and CUTI (Jacox et al. 2018) are computed from an ocean model that assimilates observations, with a historical reanalysis through 2010 and a near-real-time system afterwards; a product boundary at 2010/2011 is therefore a candidate for an artificial step (**to confirm with the index authors**). `fig_beuti_homogeneity.png` and `env_beuti_step_tests.csv`:

| Series (47N, May–Aug mean) | Trend per decade (p) | Level shift at 2011 after trend (p) | Best single break year (F) |
|---|---|---|---|
| BEUTI | +0.69 (0.001) | +0.18 (0.65) | 2006 (5.2) |
| CUTI | +0.084 (<0.001) | −0.09 (0.05) | 1998 (6.4) |
| BEUTI / CUTI (nitrate proxy) | +1.65 (0.013) | +1.98 (0.16) | 2007 (11.1) |

- There is **no level shift at the product boundary** once the trend is allowed for. The rise in BEUTI is gradual, with the steepest change around 2006–2008, well inside the reanalysis period.
- The "tenfold" increase at 47N (0.18 in 1988–98 to 2.14 in 2011–24) is inflated by a near-zero baseline. In absolute terms BEUTI at 47N rose by about 2 mmol m⁻¹ s⁻¹, comparable to 44–45N and much less than 39–42N (+8 to +9); the ratio of last to first period is 12 at 47N, 7 at 46N, 3.5 at 45N, 1.5–2.2 from 36N to 43N, and 3–7.5 again at 31–33N (`env_beuti_latitude_periods.csv`). CUTI rose by a factor of 1.9 at 47N and 1.0–1.5 elsewhere.
- **Cross-check with an independent record.** After detrending, May–Aug BEUTI correlates at r = −0.48 with the May–Sep buoy SST anomaly and CUTI at −0.30 (`env_index_annual_correlations.csv`): stronger upwelling, cooler summers, as physics requires. The interannual signal in BEUTI is therefore real. The *trends* oppose each other (BEUTI up, buoy SST up by about 0.3 deg C per decade), which is not what a doubling of physical upwelling would produce on its own; it is consistent either with warming of the upwelled source water and higher nitrate per unit transport, or with partly artificial trend in the modelled nitrate field. This is the specific question to put to the authors.

For inference, the pipeline already uses BEUTI only after removing a trend (trend term, loess, or first differences), so a smooth artefact would not change the main result; a step would, and none is detectable in the cached vintage. (§6.1: the current vintage of the index does show one at 47N.)

### 1.4 Other sources

- **Discharge.** The Dalles integrates the regulated upper basin and excludes the Willamette and the lower tributaries, which contribute a large share of winter and spring flow at the mouth. For the freshet window (Apr–Jun) the two are highly correlated in most years, but the omission matters for plume volume in wet winters.
- **Salinity.** Eleven years at three shelf moorings off Westport, none within 40 km of Long Beach or Kalaloch; usable only for validation.
- **PDO.** Homogeneous, but basin-scale; it explained nothing here (p ≥ 0.45).

---

## 2. What has been implemented: homogenised buoy anomalies

`01_build_datasets.R` now builds the regional SST anomaly with the two-way station model in `lib_env_homogenize.R`:

T[s, y, m] = C[s, m] + g[s] · R[y, m] + e,

with a 12-month climatology C per station, a common regional anomaly R per year-month, an optional station gain g, and station error variance σ²[s]. The parameters are estimated jointly by alternating least squares, with σ estimated once from leave-one-out-corrected residuals of an unweighted pass and then held fixed in a precision-weighted pass (re-estimating σ inside the weighted loop is degenerate: the best-weighted station absorbs R and its weight diverges). Only open-coast stations with at least 24 months enter the pipeline series (46029, 46041, 46211, 46099, 46100, 46248); estuary, harbor and river-mouth stations are excluded. The series carries a standard error per month.

Why this is better than averaging naive anomalies (the previous construction, kept as `sst_anom_naive3`):

- **Short-record stations no longer bias the mean.** A naive climatology for a buoy deployed in 2016 is computed from warm years only; its anomalies are biased cold. The naive-minus-model climatology differences are +0.14 (46211), +0.17 (46099), +0.22 (46100) and +0.26 deg C (46248).
- **Coverage and precision.** All six open-coast stations contribute without steps; the monthly standard error falls from 0.33–0.40 deg C in 1996–2007 (one or two buoys) to 0.15–0.21 from 2011 (four to six stations).
- **Station parameters are informative** (`env_sst_station_parameters.csv`, all-station fit with gains). Leave-one-station-out agreement with the regional series: Westport Marina 0.92, Clatsop Spit 0.91, Grays Harbor 0.90, Columbia River Bar 0.89, Cape Elizabeth 0.86, Astoria Canyon 0.86, OOI shelf 0.83, Neah Bay buoy 0.81, OOI offshore 0.79, Neah Bay harbor 0.78, Toke Point 0.77, La Push 0.67. Error SDs run from 0.28 deg C (Clatsop Spit, Westport Marina) to 0.75 (La Push). Gains are 0.71 (Neah Bay harbor) to 1.13 (OOI shelf). Not all shore gauges are poor: Westport Marina, at the harbor entrance, tracks the coast as well as any buoy; La Push and Neah Bay do not.

What it does **not** change (`env_sst_variants.csv`, `env_sst_variant_effects.csv`):

| Construction | Monthly r with pipeline series | RMSE (deg C) | Effect of May–Sep SST on the pre-recruit year-class index (SD per SD, p) |
|---|---|---|---|
| V0 naive, 3 buoys (previous) | 0.989 | 0.14 | +0.08 (0.59) |
| V1 homogenised, open coast (pipeline) | 1 | 0 | +0.07 (0.63) |
| V1u same, unweighted | 0.999 | 0.03 | +0.07 (0.63) |
| V2 homogenised, all 12 stations with gains | 0.987 | 0.14 | +0.05 (0.74) |
| V3 beach-local IDW of homogenised station anomalies | 0.977 | 0.19 | +0.06 (0.68); beach-specific in the pooled LMM: +0.18 (0.17) |

The SST result (no association with year-class strength) is insensitive to construction, and the BEUTI result does not involve the temperature record at all. The homogenisation matters for *honesty* (correct uncertainty, no artificial steps) and for any future analysis that uses temperature at finer resolution, not for the present conclusions.

Limits of the implemented series:

1. It is **regional**. North–south differences (r = 0.85 between the two long buoys) are averaged away; a beach-specific version (V3) is available in the diagnostics but relies on harbor gauges nearshore.
2. **1997–2007 rests on one or two buoys**, with 8–11 months in 1997, 1998 and 2007.
3. Buoys measure **offshore surface water**, 10–50 km from the beaches; the surf zone can differ by several degrees during upwelling and in estuary plumes.

---

## 3. Options

Each option is scored on coverage of 1997–2024, mechanistic relevance to razor clam early life stages, effort, and what it would unlock. Access routes are the public ERDDAP and USGS services; dataset identifiers are the expected ones and must be verified (the fetch scripts in `01_code/R/acquire/` check and report).

### A. Keep the homogenised buoy anomaly (status quo)

Adequate for the regional SST predictor as used. No further effort. Does not address nearshore representativeness, 1990s sparsity, or the missing variables.

### B. Satellite SST (recommended first step)

- **Products.** NOAA OISST v2.1 (daily, 0.25 deg, 1981-09 to present; blended AVHRR plus in situ, gap-free), NOAA CoralTemp (daily, 5 km, 1985 to present), JPL MUR (daily and monthly, 1 km, 2002-06 to present). All on the CoastWatch ERDDAP (`coastwatch.pfeg.noaa.gov/erddap`), readable with `rerddap`/`rerddapXtracto`, which the repository already uses.
- **Pros.** One homogeneous product for the whole record; per-pixel anomalies at each beach; no station switches; daily resolution allows event-based predictors (days above a threshold, timing of the spring transition). MUR resolves the nearshore band.
- **Cons.** OISST pixels are about 20 km and the nearest ocean pixel may sit 10–30 km offshore; coastal pixels can be land-contaminated; infrared products are cloud-limited (OISST interpolates). MUR starts in 2002, so it validates rather than replaces for the 1990s. Satellite "skin" temperature differs from the 1–2 m buoy measurement by a few tenths of a degree, which matters only for absolute values, not anomalies.
- **Effort.** Low: `fetch_oisst.R` and `fetch_mur.R` are written (untested here); a few hours on a networked machine including validation. **Done 2026-10-02 (§6.2).**
- **Unlocks.** Beach-specific SST predictors with uniform quality; validation of the buoy series; daily thermal-event metrics.

### C. Buoy winds and waves from the same NDBC stations (recommended second step)

- **Product.** `cwwcNDBCMet` (the dataset `Wtmp_salt.R` already queries) carries wind speed and direction, significant wave height, dominant period and pressure for 46029, 46041, 46211, 46099, 46100, 46248.
- **Derived predictors.** (i) Alongshore wind stress and offshore Ekman transport, i.e. a Bakun-type upwelling index at 46–47N computed from *measured* winds, independent of the ROMS product; (ii) winter wave energy (mean Hs², storm hours with Hs > 4 m) for the first-winter washout hypothesis, which the 1988 WDF report describes qualitatively (small clams "washed out by the surf"). Both homogenised across stations with `lib_env_homogenize.R`.
- **Pros.** Directly mechanistic; same homogenisation framework; tests whether the BEUTI trend is matched by measured winds.
- **Cons.** Same coverage gaps as the temperature record (1997–2003 relies on two buoys); wave records are shorter (46211 waverider from 2004).
- **Effort.** Low to moderate: `fetch_ndbc_met.R` is written (untested here). The coastline angle used for the alongshore rotation should be checked. **Done 2026-10-02 (§6.3).**
- **Unlocks.** Two new pre-specified hypotheses (local upwelling during the larval season; storminess in the first winter). They form a *new* family and must be declared as such; the pipeline's Holm correction applies within the family.

### D. Lower-river discharge (recommended, trivial)

- **Product.** USGS 14246900, Columbia River at Beaver Army Terminal near Quincy, OR (lowest long-term main-stem gauge), and 14211720, Willamette at Portland; via `dataRetrieval`.
- **Effort.** Minutes: `fetch_usgs_lower_columbia.R` is written (site numbers to confirm). **Done 2026-10-02 (§6.4).**
- **Unlocks.** A freshet predictor that includes the Willamette; a winter-flow predictor for plume extent at Long Beach.

### E. Ocean reanalysis or regional model output

- **Products.** Copernicus GLORYS12 (1/12 deg, 1993 to present; temperature, salinity, currents at depth); the UCSC CCS ROMS reanalysis that underlies BEUTI (1980–2010 historical, near-real-time after); LiveOcean (UW, 2017 to present, 1–3 km, includes biogeochemistry).
- **Pros.** Three-dimensional fields: bottom temperature where settlers live, plume salinity at Long Beach, cross-shelf velocities for a larval-transport index, nitrate and oxygen. Covers the gaps in the in situ record without station artefacts.
- **Cons.** Access and volume (tens of GB for daily fields); nearshore skill of 1/12-degree models is limited within 10 km of the coast; the same product-splice question as BEUTI; GLORYS starts in 1993, LiveOcean in 2017.
- **Effort.** High (days), plus validation against buoys and the OOI moorings.
- **Unlocks.** Mechanistic transport and plume predictors that no in situ series provides.

### F. Verification of BEUTI/CUTI with the index authors

- **Action.** Ask whether the 2010/2011 transition, assimilated-data changes, or model-version changes could impart trends to the nitrate field at 46–47N; request the model's nitrate time series at the base of the mixed layer; compare the BEUTI trend with the buoy-wind Bakun index from option C.
- **Effort.** An email; a day of comparison once option C exists. **Comparison done 2026-10-02 (§6.1, §6.3); the email is still to send.**
- **Unlocks.** Confidence in the sign and size of the one surviving association.

### G. Formal data fusion (state-space model)

- **What.** Extend the two-way station model to a dynamic linear model (KFAS or MARSS in R) in which buoys, satellite pixels and model output are noisy observations of latent monthly states per beach, with autoregressive state dynamics. Produces gap-free estimates with proper uncertainty, which can then enter the recruitment models as errors-in-variables.
- **Pros.** The principled solution; honest uncertainty propagates to the clam models.
- **Cons.** Effort and reviewer burden; with a null SST result the gain is mostly in uncertainty accounting.
- **Effort.** High. Do only if temperature becomes a central predictor.

### H. Nearshore in situ records

- Backyard Buoys (Quinault and Quileute, 2023 onward; the raw objects are in `MonthlyWtmp.RData`), OOI Endurance moorings (2015 onward), intertidal loggers if WDFW or the tribes maintain any.
- Too short for the 28-year analysis; valuable for validating how well buoys and satellites represent the surf zone (option B's main uncertainty) and for the prospective test in 2025–2027.

### Comparison

| Option | Period covered | Nearshore relevance | Effort | Changes current inference? | Recommendation |
|---|---|---|---|---|---|
| A buoy anomaly (done) | 1990– (sparse to 2003) | low–medium | none | no | keep as baseline |
| B satellite SST | 1981– (OISST), 2002– (MUR) | medium (OISST) to high (MUR) | low | unlikely (SST is null) but makes it beach-specific and gap-free | **do first** |
| C buoy winds, waves | 1990– (sparse to 2003) | high (mechanistic) | low–moderate | adds two new hypotheses; tests BEUTI trend | **do second** |
| D lower-river discharge | 1968– | medium (plume) | trivial | refines a near-null predictor | **do with C** |
| E ocean model fields | 1993– | medium | high | possibly (transport, plume) | later |
| F verify BEUTI | n/a | n/a | low | confirms or undermines the main result | **do now** |
| G state-space fusion | n/a | n/a | high | uncertainty only | optional |
| H nearshore in situ | 2015–/2023– | high | low | validation only | use for validation |

---

## 4. Recommended sequence

1. **Now, no network needed (done).** Homogenised buoy anomaly as the pipeline series; diagnostics in step 09; this document.
2. **With network access (done 2026-10-02).** The four fetch scripts plus `fetch_climate_indices.R` were run; their products are committed with provenance and joined into `env_monthly.csv`; step 09 compares them with the cached record (§6).
3. **Pre-register the new predictor family before computing any clam correlation:** local upwelling index (alongshore stress, May–Aug Y), winter wave energy (Nov Y–Feb Y+1), lower-river freshet (Apr–Jun Y), beach-specific OISST anomaly (May–Sep Y). Add them to `predictor_specs` in `01_build_datasets.R` and to `PREDICTORS` in `04_confirmatory_models.R`; Holm within the family; report alongside, not instead of, the original family.
4. **Write to the BEUTI/CUTI authors** (option F) with `fig_beuti_homogeneity.png`, `fig_index_vintages.png`, `fig_wind_vs_upwelling.png` and the numbers in §1.3 and §6.1–6.3; and decide which vintage the manuscript uses (task T35).
5. **Only if transport becomes the working hypothesis:** GLORYS or LiveOcean cross-shelf transport and plume salinity (option E), and the fusion model (option G).

## 5. Implications for the manuscript

- Methods should describe the regional SST anomaly as a two-way station homogenisation of six open-coast buoys (as now written), and report its standard error.
- The legacy notebook's temperature-based results (max temperature "predictors") rest on series with 0.3–0.9 deg C station-era offsets and should not be cited.
- The BEUTI discussion can state that the index shows no step at the product boundary and that its detrended interannual signal is corroborated by independent buoy SST, while noting that its trend is not corroborated by the SST trend and remains to be verified with the authors.
- Once options B–D are in, the manuscript gains a second, declared predictor family; the first family's results stand as reported.
- The methods must state the vintage (file creation date) of BEUTI/CUTI and the source and download date of the PDO, and the results should carry the vintage sensitivity (§6.1) as a robustness item: the BEUTI association keeps its sign and size under the current vintage, but its Holm-corrected p moves from 0.013 to 0.052.

---

## 6. What the external products showed (2026-10-02)

All five `acquire/` scripts were run against the live servers; the products are in `02_data/Environmental Data/external/` with provenance files, and step 09 sections F–H compare them with the cached record. The fixes needed to make the scripts run (ERDDAP time bounds, OISST's depth axis, upper-case NDBC field names, the USGS Water Data API) are recorded in `01_code/R/acquire/README.md`.

### 6.1 The upwelling indices and the PDO have been re-issued

The cached `BEUTI_daily.csv` and `CUTI_daily.csv` end in April 2025. The files on the authors' site (NetCDF creation date 28 September 2026) extend to September 2026 and **differ throughout the record**: 91–93% of the daily BEUTI values at 46–47N changed, the daily correlation between vintages is 0.94, and for the May–Aug window at 47N the annual means correlate at 0.94 (0.84 after detrending) with a largest single-year difference of 1.4 units (2020) (`env_index_vintages.csv`, `fig_index_vintages.png`). The whole series was evidently regenerated from an updated reanalysis rather than extended.

| 47N, May–Aug mean | Cached vintage (to 2025-04) | Current vintage (2026-09-28) |
|---|---|---|
| Mean 1988–2024 | 1.25 | 1.55 |
| Trend per decade | +0.76 | +1.07 |
| Level shift at 2010/2011 after trend (p) | +0.18 (0.65) | **+1.07 (0.022)** |
| Best single break year | 2006 | 2013 |
| Winter CUTI (Nov–Feb) mean | −0.34 | about 0.1 higher throughout, same shape |

The level shift at the reanalysis boundary that was absent in the cached vintage is present in the current one at 47N (not at 46N: +0.06, p = 0.86). This strengthens the case for asking the authors directly (option F) and is the main open question about the index.

The PDO cache matches neither NCEI's current ERSST v5 file nor NOAA PSL's: monthly r = 0.98 with both, with a systematic offset of about −0.3 (NCEI is lower) and single-month differences up to 1 unit; the May–Sep window correlates at 0.99 between versions. The cache was probably downloaded from NCEI before a revision of ERSST; the PSL version uses a different EOF base period.

**Effect on the pre-specified tests** (`env_index_vintage_effects.csv`, same 27 year classes, estimators identical to `04_confirmatory_models.R`; and a full pipeline run with `./run_pipeline.sh --vintage=current --out=03_analyses/robust-reanalysis-vintage-current`, git-ignored):

| Test (pre-recruits of year class Y) | Cached vintage | Current vintage |
|---|---|---|
| BEUTI, pooled LMM, SD per SD (LRT p; Holm) | −0.34 (0.052; 0.47) | −0.31 (0.11; 1.0) |
| BEUTI, pooled LMM without Kalaloch (p; Holm) | −0.49 (0.003; 0.031) | −0.45 (0.014; 0.14) |
| BEUTI, coastwide GLS-AR(1) (p; Holm) | −0.58 (0.0013; 0.013) | −0.62 (0.005; 0.052) |
| BEUTI, linear detrending / loess / first differences (p) | −0.37 (0.03) / r −0.44 (0.02) / −0.57 (0.0002) | −0.36 (0.10) / r −0.43 (0.03) / −0.70 (0.0007) |
| BEUTI, without most influential year (year; p) | −0.25 (2008; 0.20) | −0.26 (2020; 0.24) |
| BEUTI, 2003 onward (p) | −0.44 (0.011) | −0.50 (0.025) |
| Trend + BEUTI forecast skill vs climatology | −0.03 | −0.12 |
| CUTI Nov–Feb, PDO May–Sep (NCEI or PSL) | all p ≥ 0.35 | all p ≥ 0.34 |
| Window scan: windows passing family-wise control | 0 of 1,380 | 0 of 1,380 |

The association keeps its sign and size under the current vintage; its precision falls (the current series is more variable in 2014–2024), so the Holm-corrected coastwide p moves from 0.013 to 0.052 and the primary pooled test from 0.052 to 0.11. Honest reporting therefore has to carry both: "modest, negative, borderline after multiplicity correction, and dependent on which vintage of the index is used". The null results for CUTI-winter and PDO do not depend on the vintage or the PDO source.

**Decision (owner, 2026-10-02, task T35): the current vintage is the primary.** `INDEX_VINTAGE` defaults to `current`; the pipeline's main outputs and the manuscript now carry the current-vintage numbers, with the cached-vintage numbers as the sensitivity (`./run_pipeline.sh --vintage=cached --out=DIR`). The 2010/2011 level shift at 47N in the current vintage (+1.07, p = 0.022) is therefore a property of the primary series and is stated as such; the trend-robust tests (detrending, first differences) are the ones to lean on.

### 6.2 Satellite SST agrees with the buoys, least in summer

| Construction | Months 1990–2025 | Monthly r with pipeline series V1 | May–Sep annual r | SST effect on the pre-recruit index (SD per SD, p) |
|---|---|---|---|---|
| V4 OISST regional (0.25 deg, 45.9–48.1N) | 424 | 0.88 | 0.79 | +0.08 (0.57) |
| V5 MUR 1 km, mean of five beach boxes (2002–) | 281 | 0.94 | 0.87 | +0.30 (0.09; 22 year classes) |
| OISST beach pixels, beach-specific in the pooled LMM | | | | +0.04 (0.70) |
| MUR beach boxes, beach-specific in the pooled LMM | | | | +0.10 (0.52) |

(`env_sst_variants.csv`, `env_sst_variant_effects.csv`, `env_satellite_vs_buoy.csv`.) Agreement is 0.95–0.97 in winter and 0.78–0.81 in July–September, when upwelling sets up cross-shore gradients that a buoy 10–50 km offshore and a 20 km pixel sample differently; and it rises from 0.83 in 1990–2003 (one or two buoys) to 0.94 in 2014–2025 (five). MUR's five beach boxes correlate 0.92–0.93 with V1 except Long Beach (0.83), where the plume dominates. North–south coherence (Long Beach vs Kalaloch, monthly) is 0.73 in OISST and 0.81 in MUR against 0.88 in the beach-local buoy construction, so the buoy-based beach series overstate alongshore coherence. None of this changes the SST inference, which is null under every construction; it does mean that a beach-level SST predictor should come from MUR or OISST, not from interpolated stations. Caveat: the CoastWatch OISST aggregation holds only 139–239 days per year for 1992–1998, so those monthly means rest on 10–15 days.

### 6.3 Measured winds corroborate CUTI, including its trend, but not the size of BEUTI's

From the hourly winds of the six open-coast buoys, homogenised across stations as for temperature (`external/ndbc_met_monthly.csv`; alongshore stress positive equatorward, Large and Pond drag, coastline angle 10 deg):

| May–Aug, 1991–2024 | r with buoy wind stress | detrended r | trend, share of mean per decade (p) |
|---|---|---|---|
| Buoy alongshore wind stress | 1 | 1 | +24% (0.006) |
| CUTI 47N, cached / current | 0.72 / 0.66 | 0.63 / 0.53 | +18% (0.002) / +26% (<0.001) |
| BEUTI 47N, cached / current | 0.53 / 0.53 | 0.31 / 0.30 | +58% (<0.001) / +70% (<0.001) |

(`env_wind_vs_upwelling.csv`, `fig_wind_vs_upwelling.png`.) Independent, measured winds explain 40% of CUTI's detrended variance and show the same upward trend of about a fifth to a quarter of the mean per decade, so the transport component of the upwelling increase is real. They explain only 10% of BEUTI's detrended variance, and BEUTI's trend is three times larger relative to its mean; the extra variance and trend sit in the modelled nitrate concentration. In the winter window, buoy wave energy and storm hours correlate −0.46 to −0.48 (detrended −0.55 to −0.57) with winter CUTI (storms with downwelling), which validates the pre-specified CUTI-winter predictor as a storminess proxy and supplies a direct one.

### 6.4 Lower-river gauges

The lowest main-stem gauge (Port Westward / Beaver Army Terminal, 14246900, from June 1991) correlates 0.97 with The Dalles for the Apr–Jun freshet and carries 1.22 times its flow; adding the Willamette (12% of Dalles flow, r = 0.45 with it) raises the correlation to 0.985 (`env_discharge_gauges.csv`). The cached Dalles series matches a fresh download exactly except for provisional-to-approved revisions after October 2023. The freshet predictor is therefore unaffected; the lower gauges matter only for winter plume volume.

### 6.5 What is still to do

1. Email the index authors (§6.1, §6.3). 2. Decide the manuscript vintage (task T35). 3. Declare the new predictor family (wind-driven upwelling, winter wave energy, lower-river freshet, beach-level satellite SST) before testing it (task T12). 4. Derive spring-transition timing and relaxation frequency from the hourly winds (`external/raw/`, regenerable).

# 02_data/Environmental Data

Environmental time series and station metadata. Most files were produced by `Wtmp_salt.R`, which pulls data from NOAA and OOI ERDDAP servers with `rerddap`. Others were downloaded directly or cached by the notebook. All paths assume the repository root as working directory.

| File | Content | Coverage | Produced by / source | Used by |
|---|---|---|---|---|
| `BEUTI_daily.csv` | Biologically Effective Upwelling Transport Index (vertical nitrate flux, mmol m⁻¹ s⁻¹); columns `year, month, day, 31N … 47N` (1° latitude bins) | 1988-01-01 → 2025-04 | Jacox et al. (2018) indices (mjacox.com/upwelling-indices); downloaded manually | notebook §3; `R/01`, `R/lib_original_grid.R` |
| `CUTI_daily.csv` | Coastal Upwelling Transport Index (vertical transport, m² s⁻¹), same layout | 1988 → 2025-04 | as above | notebook §3; `R/01` |
| `CUTI_monthly.csv` | Monthly CUTI, same latitude bins | 1988 → 2025 | as above | **unused** |
| `columbia_discharge.csv` | Daily mean discharge, Columbia River at The Dalles (USGS 14105700); `discharge_cfs`, `discharge_cms` | 1990-01-01 → 2026-03-01 | Cached by the notebook (USGS Water Data API) | notebook §3; `R/01`, `R/lib_original_grid.R` |
| `pdo_index.csv` | Monthly PDO index (NCEI ERSST v5). **`month` is stored as a name (`Jan` …)** | 1950 → 2026 | Cached by the notebook (`rsoi::download_pdo()` or NCEI) | notebook §3 (when `use_pdo`); `R/01` |
| `daily_wtmp_summary.xlsx` | Daily water temperature per NDBC station: `wtmp_max/mean/sd/min`, `n_obs` (hourly obs) | 1990 → 2025, station-dependent | `Wtmp_salt.R` (ERDDAP `cwwcNDBCMet`, box 46–48.5°N, 125–123.8°W) | notebook §4c |
| `half_monthly_wtmp_summary.xlsx` | Same, per half-month (`half` = H1 days 1–15, H2 days 16–end) | as above | `Wtmp_salt.R` | notebook §4b |
| `monthly_wtmp_summary.xlsx` | Same, per month. `wtmp_min`/`wtmp_max` are extremes of *all hourly values* in the month | as above | `Wtmp_salt.R` | notebook §4a; `R/01` (buoys 46029, 46041, 46211 only) |
| `Station Names.xlsx` | Station ID, name, latitude, longitude, notes (22 stations; 3 lack coordinates) | none | hand-compiled | notebook §3; `R/03`, `R/07` |
| `DailySalt.xlsx` | Daily salinity and temperature at three OOI Endurance Array moorings off Westport (`WsptInnerShelf`, `WsptShelf`, `WsptOuterShelf`) | 2014/15 → 2025 | `Wtmp_salt.R` (OOI ERDDAP; seafloor CTDs, depth to confirm) | notebook §3–4d (only if `use_salinity`) |
| `MonthlyWtmp.RData`, `MonthlySalinity.RData` | R objects from `Wtmp_salt.R`; include "Backyard Buoys" (Quinault, Quileute) nearshore temperatures not present in the xlsx summaries | none | `Wtmp_salt.R` | **unused** |
| `channel-measurements.csv`, `field-measurements.csv` | USGS field-visit discharge measurements at 14105700 | 1971 → 2025 | USGS Water Data API | **unused** |
| `Wtmp_salt.R` | Download and aggregation script for the buoy temperature and OOI salinity files above | none | none | run manually; needs network |

## Station notes (temperature)

Within 50 km of the beaches, the long open-coast buoys are:

- **46029** Columbia River Bar (1991–2025, gaps).
- **46041** Cape Elizabeth (1990–2024).
- **46211** Grays Harbor waverider (2004–2025).

Several other stations are **inside estuaries or harbors** and do not represent surf-zone conditions:

- TOKW1 Toke Point (Willapa Bay)
- WPTW1 Westport Marina (Grays Harbor)
- LAPW1 La Push
- HMDO3 Hammond (Columbia estuary)
- DMNO3 Desdemona Sands

The legacy notebook blends raw temperatures from whichever stations report, so its beach temperature series contain station-switch artifacts of up to 0.9 °C (`docs/environmental-record-options.md` §1.2). The pipeline instead fits a two-way station model to the open-coast stations and uses its regional anomaly (`02_data/derived/env_monthly.csv`, columns `sst_anom`, `sst_anom_se`). Station classes are defined in `01_code/R/00_config.R` (`STATION_CLASS`).

## `external/` (fetched 2026-10-02)

Monthly tables from external products fetched by `01_code/R/acquire/` (see its README for the scripts and server details). Any `external/*_monthly.csv` with `year` and `month` columns is joined into `02_data/derived/env_monthly.csv` automatically, with its columns prefixed by the file stem. `external/raw/` holds the download caches and is git-ignored.

| File | Content | Coverage | Columns in `env_monthly.csv` |
|---|---|---|---|
| `oisst_monthly.csv`, `oisst_pixels.csv` | NOAA OISST v2.1 0.25 deg SST: regional mean over 45.9–48.1N, 125.4–123.6W and the 3 nearest ocean pixels within 40 km of each beach; anomalies per pixel vs 1991–2020 | 1981-09 → 2026-09 | `oisst_anom_regional`, `oisst_sst_regional`, `oisst_n_pixels_regional`, `oisst_anom_<beach>` |
| `mur_monthly.csv` | JPL MUR 1 km SST, monthly composites, 0.1 × 0.13 deg box off each beach (150 pixels); anomalies vs 2003–2020 | 2002-06 → 2026-07 | `mur_anom_<beach>`, `mur_sst_<beach>` |
| `ndbc_met_monthly.csv`, `ndbc_met_stations.csv` | Buoy winds and waves from 46029, 46041, 46211, 46099, 46100, 46248, homogenised across stations as for temperature: alongshore wind-stress and Ekman-transport anomalies (positive = upwelling-favourable), significant wave height, Hs², share of hours with Hs > 4 m | 1990 → 2026 | `ndbc_met_tau_along_anom`, `ndbc_met_ekman_anom`, `ndbc_met_hs_anom`, `ndbc_met_hs2_anom`, `ndbc_met_storm_anom`, `ndbc_met_n_*` |
| `columbia_lower_monthly.csv` | USGS daily mean discharge (m³ s⁻¹): Columbia at Port Westward / Beaver Army Terminal (14246900), Willamette at Portland (14211720), The Dalles (14105700) | 1990 (Beaver 1991-06) → 2026-09 | `columbia_lower_q_beaver_cms`, `columbia_lower_q_willamette_cms`, `columbia_lower_q_dalles_cms` |
| `BEUTI_daily_<date>.csv`, `CUTI_daily_<date>.csv`, `upwelling_monthly.csv` | Current vintage of the upwelling indices (creation date in the file name); monthly means at 45–47N | 1988 → 2026-09 | `upwelling_beuti_45N..47N`, `upwelling_cuti_45N..47N` |
| `pdo_monthly.csv` | PDO as currently served by NCEI (ERSST v5) and by NOAA PSL | 1854 → 2026 | `pdo_ncei`, `pdo_psl` |
| `*_provenance.txt` | URL, dataset id, download date, package version, md5 of each table | | |

**Vintages.** The cached `BEUTI_daily.csv`, `CUTI_daily.csv` and `pdo_index.csv` above differ from the current server files throughout the record (the indices are regenerated from an updated reanalysis; the PDO is recomputed from revised ERSST). The pipeline uses the cached snapshots unless run with `--vintage=current`; `09_env_record_diagnostics.R` (F) quantifies the difference and refits the pre-specified tests under both.

## Caveats

- **BEUTI** May–Aug at 47°N increases about tenfold over the record (0.18 → 2.14), far more than CUTI. Verify product homogeneity before interpreting this (task T6).
- **Discharge** at The Dalles is about 300 km upstream of the river mouth and excludes lower-basin tributaries; the Beaver and Willamette gauges in `external/` close that gap (task T12).
- **Salinity** records are too short (≤11 years) for the 1997–2024 analysis.

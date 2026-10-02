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

The legacy notebook blends raw temperatures from whichever stations report, so its beach temperature series contain station-switch artifacts (`docs/methodology-review.md` §2.4). The new pipeline uses only the three open-coast buoys and averages anomalies (`02_data/derived/env_monthly.csv`, column `sst_anom`).

## Caveats

- **BEUTI** May–Aug at 47°N increases about tenfold over the record (0.18 → 2.14), far more than CUTI. Verify product homogeneity before interpreting this (task T6).
- **Discharge** at The Dalles is about 300 km upstream of the river mouth and excludes lower-basin tributaries (task T12).
- **Salinity** records are too short (≤11 years) for the 1997–2024 analysis.

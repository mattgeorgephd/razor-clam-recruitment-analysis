# 01_code/R/acquire

Scripts that fetch **external environmental products** the repository does not yet contain, and cache them as monthly tables that the pipeline picks up automatically. They exist because the current record is a patchwork of buoys and shore gauges (see `docs/environmental-record-options.md`); these products fill the gaps with homogeneous, gridded or long-running sources.

> **Status: written but not executed.** The sandbox in which they were written had no access to NOAA, USGS or OOI servers. Dataset identifiers and site numbers are the ones expected on the public servers but must be confirmed (each script prints how). Run them on a networked machine, inspect the diagnostics they print, then run `./run_pipeline.sh`.

| Script | Product | Period | Output (in `02_data/Environmental Data/external/`) |
|---|---|---|---|
| `fetch_oisst.R` | NOAA OISST v2.1, daily 0.25 deg SST, via CoastWatch ERDDAP | 1981-09 to present | `oisst_monthly.csv` (regional and per-beach anomalies), `oisst_pixels.csv`, `oisst_provenance.txt` |
| `fetch_mur.R` | NASA JPL MUR 1 km SST (monthly), via CoastWatch ERDDAP | 2002-06 to present | `mur_monthly.csv` (per-beach nearshore anomalies), `mur_provenance.txt` |
| `fetch_ndbc_met.R` | NDBC buoy winds, waves and pressure (same buoys as the temperature record), via `cwwcNDBCMet` | 1990 to present | `ndbc_met_monthly.csv` (homogenised alongshore wind stress / Ekman transport, wave energy, storm hours), `ndbc_met_stations.csv`, `ndbc_met_provenance.txt` |
| `fetch_usgs_lower_columbia.R` | USGS daily discharge, Columbia River at Beaver Army Terminal (14246900) and Willamette at Portland (14211720) | 1968/1972 to present | `columbia_lower_monthly.csv`, `columbia_lower_provenance.txt` |

## How the pipeline uses them

`01_build_datasets.R` joins every `external/*_monthly.csv` that has `year` and `month` columns into `02_data/derived/env_monthly.csv`, prefixing the other columns with the file stem (e.g. `oisst_anom_regional`, `ndbc_met_tau_along_anom`). Nothing downstream requires these columns. To use one as a predictor, add a spec to `predictor_specs` in `01_build_datasets.R` and a label in `04_confirmatory_models.R` (see `AGENTS.md`, "Add a predictor"), and record it as a *new* pre-specified family in the manuscript methods.

## Requirements

`rerddap` (and `rerddapXtracto` for the gridded products), `dataRetrieval` for USGS, plus the pipeline packages. Install from CRAN. The scripts cache raw downloads under `external/raw/` so reruns are cheap; delete that folder to refresh.

## Checks before trusting a product

1. **Identifier check.** Each script searches the server (`rerddap::ed_search`) and stops with a message if the expected dataset id is not found; use the id it suggests.
2. **Coverage check.** Each script prints months per year; compare with `03_analyses/robust-reanalysis/tables/env_coverage_by_year.csv`.
3. **Validation against buoys.** After running, rerun `./run_pipeline.sh`; `09_env_record_diagnostics.R` will include the new columns in `env_sst_variants.csv` only if you add them there (one line; see the comment in that script). Expected monthly agreement with the homogenised buoy anomaly: r > 0.9 for OISST/MUR.
4. **Provenance.** Keep the `*_provenance.txt` files (URL, dataset id, date, package versions, checksum) in version control alongside the CSVs.

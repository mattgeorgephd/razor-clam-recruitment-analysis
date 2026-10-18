# 01_code/R/acquire

Scripts that fetch **external environmental products** the repository does not yet contain, and cache them as monthly tables that the pipeline picks up automatically. They exist because the current record is a patchwork of buoys and shore gauges (see `docs/environmental-record-options.md`); these products fill the gaps with homogeneous, gridded or long-running sources.

> **Status: all five scripts were run on 2026-10-02** against the live servers (dataset ids and site numbers confirmed; the fixes needed are noted in each script). Their outputs and provenance files are committed in `02_data/Environmental Data/external/`; the raw download caches in `external/raw/` are git-ignored and regenerable. Rerun a script to refresh its product (delete its files in `external/raw/` first to force a new download).

| Script | Product | Period | Output (in `02_data/Environmental Data/external/`) |
|---|---|---|---|
| `fetch_oisst.R` | NOAA OISST v2.1, daily 0.25 deg SST (`ncdcOisst21Agg_LonPM180`), via CoastWatch ERDDAP | 1981-09 to present | `oisst_monthly.csv` (regional and per-beach anomalies), `oisst_pixels.csv`, `oisst_provenance.txt` |
| `fetch_mur.R` | NASA JPL MUR 1 km SST, monthly composites (`jplMURSST41mday`), via CoastWatch ERDDAP | 2002-06 to present | `mur_monthly.csv` (per-beach nearshore anomalies, 150 pixels per beach box), `mur_provenance.txt` |
| `fetch_ndbc_met.R` | NDBC buoy winds, waves and pressure (same buoys as the temperature record), via `cwwcNDBCMet` | 1990 to present | `ndbc_met_monthly.csv` (homogenised alongshore wind stress / Ekman transport, wave energy, storm hours), `ndbc_met_stations.csv`, `ndbc_met_provenance.txt` |
| `fetch_usgs_lower_columbia.R` | USGS daily mean discharge via the Water Data API (`dataRetrieval::read_waterdata_daily`): Columbia at Port Westward / Beaver Army Terminal (14246900, from 1991-06), Willamette at Portland (14211720), The Dalles (14105700) | 1990 to present | `columbia_lower_monthly.csv`, `columbia_lower_provenance.txt` |
| `fetch_climate_indices.R` | Current vintages of BEUTI and CUTI (mjacox.com, creation date read from the NetCDF) and of the PDO (NCEI ERSST v5 and NOAA PSL) | 1988 (indices), 1854 (PDO) to present | `BEUTI_daily_<date>.csv`, `CUTI_daily_<date>.csv`, `upwelling_monthly.csv`, `pdo_monthly.csv`, `climate_indices_provenance.txt` |

**Index vintages.** The cached `BEUTI_daily.csv`, `CUTI_daily.csv` and `pdo_index.csv` in `02_data/Environmental Data` are snapshots. The index authors regenerate the whole BEUTI/CUTI record when the underlying reanalysis is updated, and NCEI recomputes the PDO when ERSST is revised, so the current files differ from the cache throughout the record (daily r about 0.94 at 46–47N; PDO monthly r 0.975). The pipeline uses the cached snapshots by default and the current files with `./run_pipeline.sh --vintage=current` (`INDEX_VINTAGE` in `00_config.R`); `09_env_record_diagnostics.R` section F refits the pre-specified tests under both.

## How the pipeline uses them

`01_build_datasets.R` joins every `external/*_monthly.csv` that has `year` and `month` columns into `02_data/derived/env_monthly.csv`, prefixing the other columns with the file stem (e.g. `oisst_anom_regional`, `ndbc_met_tau_along_anom`). Nothing downstream requires these columns. To use one as a predictor, add a spec to `predictor_specs` in `01_build_datasets.R` and a label in `04_confirmatory_models.R` (see `AGENTS.md`, "Add a predictor"), and record it as a *new* pre-specified family in the manuscript methods.

## Requirements

`rerddap` (gridded and tabular ERDDAP access), `dataRetrieval` (>= 2.7.x, which needs a current `httr2`) for USGS, `ncdf4` for the index creation dates, plus the pipeline packages. Install from CRAN; on Ubuntu the R `curl` package needs `libcurl4-openssl-dev` (or the `r-cran-curl` apt package). The scripts cache raw downloads under `external/raw/` (git-ignored) so reruns are cheap; delete that folder to refresh.

Server quirks handled in the scripts: ERDDAP rejects time bounds outside a dataset's coverage, so the scripts read `time_coverage_start/end` from the dataset metadata and pass the full ISO strings; OISST has a degenerate `zlev` axis that must be requested; `cwwcNDBCMet` field names are upper case; ERDDAP occasionally returns a truncated CSV without an error, so `fetch_oisst.R` checks the number of days returned per year and does not cache short years; the NWIS services behind `readNWISdv` are being decommissioned, so the USGS script uses the Water Data API.

## Checks before trusting a product

1. **Coverage check.** Each script prints months per year; `env_coverage_by_year.csv` and `fig_env_coverage.png` in the pipeline output show the external products beside the cached sources.
2. **Validation against buoys.** `09_env_record_diagnostics.R` adds OISST (V4) and MUR (V5) to `env_sst_variants.csv` and `env_sst_variant_effects.csv`, and writes per-beach agreement to `env_satellite_vs_buoy.csv`. Expected monthly agreement with the homogenised buoy anomaly: r > 0.9 for both.
3. **Sign conventions.** In `ndbc_met_monthly.csv` positive alongshore stress is equatorward (upwelling-favourable); the monthly climatology of the raw winds (southward in May–Aug, northward in Nov–Feb) confirms the rotation. `env_wind_vs_upwelling.csv` reports the agreement with CUTI.
4. **Provenance.** Keep the `*_provenance.txt` files (URL, dataset id, date, package versions, checksum) in version control alongside the CSVs.

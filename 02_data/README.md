# 02_data

Raw inputs (treat as read-only) and regenerated analysis tables (`derived/`). Record data-quality problems in `../task.md` (items T20–T24); do not silently edit raw files.

| Path | Contents | Read by |
|---|---|---|
| `razor-clam-season-summary-1997-2025.xlsx` | WDFW stock-assessment abundance estimates and fishery statistics, 5 beaches × 28 seasons | notebook §3; `R/01_build_datasets.R` |
| `shell_length_data-summary/` | 218,101 individual shell lengths from the stock-assessment surveys, 1997–2025 (see its README) | notebook §3, §21–26; `R/01`, `R/02` |
| `Environmental Data/` | Upwelling indices, buoy temperature and salinity, Columbia discharge, PDO, station metadata (see its README) | notebook §3–7; `R/01`, `R/lib_original_grid.R` |
| `derived/` | Analysis-ready tables written by `01_code/R/01_build_datasets.R` (see its README) | `R/02`–`07` |

## `razor-clam-season-summary-1997-2025.xlsx`

Sheets:

- **`data`:** 140 rows, one per beach × season.
- **`sort_season`:** season ordering.
- **`sort_beach`:** beach order, north to south.

Columns in `data`:

| Column | Meaning |
|---|---|
| `beach` | Kalaloch, Mocrocks, Copalis, Twin Harbors, Long Beach |
| `year` | Season index 1–28 (**not** a calendar year; the notebook drops it) |
| `season` | Harvest season label, e.g. `2003-04`. The stock-assessment survey happens April–August of the first year (`survey_year` = 2003) |
| `habitat_m2` | Razor clam habitat area used to expand density to abundance; changes in steps over time |
| `pre_recruits` | Estimated beach-wide abundance of clams < 76 mm (3 in) at the survey |
| `recruits` | Estimated beach-wide abundance of clams ≥ 76 mm at the survey (harvestable size) |
| `ER` | Target exploitation rate (%) |
| `TAC`, `TAC_state`, `TAC_tribal` | Total allowable catch (clams), with state and tribal shares |
| `harvest_total`, `harvest_state`, `harvest_tribal` | Realized harvest (clams) |
| `effort_state` | Recreational effort (digger trips; unit to confirm) |
| `BSMY` | Constant per beach; appears to be a reference abundance (possibly B_MSY). **Definition to confirm** |
| `TAC_used_*` | Percent of TAC harvested |
| `ratio_pre-recruit_recruit`, `ratio_recruit_BSMY` | Derived ratios (%) |
| `over_40%`, `10_to_40%`, `low_pre_recruits` | Harvest-control-rule category values; sparse |
| `ER_calc`, `ER_actual` | Calculated and realized exploitation rates (%) |

**Provenance:** WDFW razor clam program. The contact and date received are not recorded (task T23). No standard errors are included (task T10).

## Unused or legacy files

- `../WDF Razor Clam Hatchery.1988.pdf` (repo root): background reference, not data.
- In `Environmental Data/`, the files `channel-measurements.csv`, `field-measurements.csv`, `MonthlyWtmp.RData`, `MonthlySalinity.RData` and `CUTI_monthly.csv` are not read by any code (task T24).

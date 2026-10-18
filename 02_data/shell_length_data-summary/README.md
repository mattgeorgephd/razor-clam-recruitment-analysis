# 02_data/shell_length_data-summary

Individual razor clam shell lengths measured during the annual WDFW (and cooperating tribal and NPS) stock-assessment surveys, 1997–2025. The surveys use the pumped-area method (Berry-Powell et al. 2023, *J. Shellfish Res.* 42:91–98), sampling plots along transects at set tidal elevations. According to the notebook (§3) every clam counted is also measured; confirm with WDFW.

| File | Sheets | Rows (raw) |
|---|---|---|
| `All_Beaches_shell_lengths_1997-2025.xlsx` | `All_Clams_Raw` (all beaches), `Year_Summary_All_Beaches`, per-beach `*_Year_Summary` | 218,101 |
| `COP_…`, `KAL_…`, `LB_…`, `MOC_…`, `TH_…` | `All_Clams_Raw`, `Year_Summary` for one beach | 42,260 / 47,011 / 52,903 / 49,021 / 26,906 |

The combined workbook is the one read by code. The per-beach files duplicate it; the Kalaloch file additionally has a `data_source` column.

## `All_Clams_Raw` columns

| Column | Meaning |
|---|---|
| `survey_year` | Calendar year of the survey (= first year of the harvest-season label) |
| `beach` | Beach name |
| `type` | Sampling type (`Pump`, `Pump - WDFW`, …) |
| `date` | Survey date. **Mixed encodings:** ISO text, Excel serial numbers, and `dd-Mon-yyyy` (Twin Harbors 2011). Kalaloch 2001 has no dates. A few typos (task T20–T21) |
| `transect`, `elevation`, `plot` | Sampling location identifiers |
| `clams` | Number of clams in the plot (text; may be blank) |
| `length_mm`, `length_cm` | Shell length |
| `class` | `P` = pre-recruit (<76 mm), `R` = recruit (≥76 mm) |
| `note` | Data source for Kalaloch (WDFW, QIN = Quinault, OLYM/ONP = Olympic National Park) and other notes |
| `est_age_yr`, `size_class`, `age_class` | Precomputed with an earlier growth equation (the notebook comments suggest a California equation); the notebook **recomputes** them, and its age labels are not reliable either (task T7) |
| `source_file` | Original per-year workbook (153 files) |

## Facts that matter for analysis

- **Survey timing varies.** Median survey date by beach: Long Beach about 6 June, Copalis about 16 June (late April–May in 1997–99), Mocrocks about 18 July, Kalaloch about 24 July, Twin Harbors about 9 August. Dates drift earlier at Kalaloch and Twin Harbors and later at Copalis. See `03_analyses/robust-reanalysis/tables/survey_timing_by_beach.csv`.
- **Current-year settlers.** A distinct ≤20 mm settler mode appears only at surveys after mid-July. At June surveys, pre-recruits (20–75 mm) settled the previous summer. See `03_analyses/robust-reanalysis/figures/fig_length_frequency.png`.
- **Sample sizes vary widely** (91–12,994 clams per beach-year). Use the expanded abundance estimates in `../razor-clam-season-summary-1997-2025.xlsx`, not raw counts, as abundance.
- **Kalaloch** shows length heaping (spikes at 50 and 58–60 mm) and mixes three survey organizations.
- **Missing data.** Copalis 2003 has no length records.

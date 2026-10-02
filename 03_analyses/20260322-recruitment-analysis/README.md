# 03_analyses/20260322-recruitment-analysis (superseded)

Outputs of the legacy exploratory notebook, version 7 (now `01_code/razor-clam-recruitment-analysis.Rmd`), committed in `1324017`. Identified as version 7 because only v7 writes `lag_profile_experienced_stage_by_group.png` and `lag0_concurrent_conditions_by_group.png`, and image sizes match v7's `ggsave` settings.

**Do not cite numbers from this folder.** They were produced before the 2026-10 fixes (`task.md`, "Fixed"), notably B3, under which BEUTI and discharge were dropped wherever buoy temperature was missing. They are also subject to the design problems in `docs/methodology-review.md`: lag alignment, multiplicity, trends and selection leakage. The robust replacements are in `../robust-reanalysis/`.

Active toggles for this run: Max temp, BEUTI and Discharge on; Min temp, CUTI, Salinity and PDO off. `save_cross_beach`, `save_scatter`, `save_barplots`, `save_corrplots`, `save_acf`, `save_prewhiten` and `save_models` were FALSE, so those subfolders are absent or contain only workbooks.

| Subfolder | Notebook section | Contents |
|---|---|---|
| `summary/` | §5a | Abundance time series |
| `climatology/` | §5b–c, §6 | Seasonal climatologies and monthly series (temperature, salinity, discharge) |
| `monthly/`, `half_monthly/`, `weekly/` | §10 | Correlation heatmaps: best lag, per lag, lag number. The three timescales use the same month-defined windows (task T18) |
| `periodicity/` | §15 | Smoothed periodograms (no significance test; task T16) |
| `excel/` | §9, §13, §17, §21–26 | Correlation matrices and model and summary workbooks |
| `models/` | §18 | `predictive_models.xlsx`. Its Q² values are inflated by selection leakage (review §4.6) |
| `synthesis/` | §19 | Lag profiles, N→S gradients, overlays, dashboard, cohort trace |
| `windows/` | §20 | Window × lag cascades, tiles, bubbles, fingerprints |
| `shell_length/` | §21 | Size-frequency histograms, violins, composition plots |
| `age_class_trends/` | §22 | Size-class abundance series |
| `age_class_heatmaps/` | §24 | Size-class lag heatmaps, lag profiles, biological-window figures |
| `age_class_models/` | §25 | Size-class model diagnostics |
| `cohort_tracking/` | §26a–b | YOY pulse decay and progression correlations |
| `population_structure/` | §26c–d | Mean structure and predictor overlays |

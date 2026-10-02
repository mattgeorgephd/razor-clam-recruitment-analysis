# 01_code/archive

Frozen earlier iterations (versions 2–6) of the exploratory notebook. Version 7 lives one level up as `../razor-clam-recruitment-analysis.Rmd`. Do not edit or run these files; they are kept only so the history of analytical choices stays visible outside git.

Changes between versions, from a `diff` review on 2026-10-02:

| Step | Main changes |
|---|---|
| 2 → 3 | Scatter plots restricted to active predictors (bug fix) |
| 3 → 4 | `use_temp_min` and `use_cuti` switched on. Half-corrplot labels rebuilt dynamically, and max temperature included (bug fix) |
| 4 → 5 | `use_temp_min` and `use_cuti` switched off again. `save_acf`, `save_prewhiten` and `save_models` switched off. Added §24d-iv (geographic-group peak-window profile) and §24d-v (significant-cell counts) |
| 5 → 6 | Added §24d-vi to viii (pre-specified biological windows: Max temp May–Aug, BEUTI May–Aug, discharge Apr–Jun) |
| 6 → 7 | Figure sizing and dpi changes. Added §24d-ix ("experienced life stage") and §24d-x (lag-0 concurrent conditions) |

Nothing analytical in versions 2–6 is missing from version 7. The only things not carried forward are the v4 toggle settings (min temp and CUTI on) and older figure sizes.

# Prospective forecast protocol

*Adopted 2 October 2026. Implemented in `01_code/R/08_forecast_protocol.R`; forecasts accumulate in `03_analyses/robust-reanalysis/tables/forecast_ledger.csv` and their scores in `forecast_scores.csv`. The 2025 forecasts archived earlier the same day by the previous script (`forecast_2025_archived.csv`, `01_code/archive/08_forecast_2025_proof_of_concept.R`) were a proof of concept and are superseded by this protocol.*

## 1. Why a protocol

A retrospective association, however carefully calibrated, is a hypothesis. The only test that cannot be contaminated by the analyst's choices is a forecast issued, recorded and scored before the outcome is known. The rolling-origin skill test in `06_forecast_skill.R` imitates this on the historical record and finds that no environmental model beats climatology for year-class pre-recruits once predictor selection is done honestly (`forecast_skill_cohort_framework.csv`). The protocol turns that into an ongoing test that WDFW's annual survey settles one year at a time.

## 2. What is forecast, and when

| Element | Rule |
|---|---|
| Target survey year T | The year after the last survey with abundance estimates in the repository (S). Each pipeline run issues T = S + 1 once; adding the estimates for T scores those rows and issues T + 1. |
| Targets | Per beach: (a) pre-recruit abundance at survey T, which is year class T − 1; (b) recruit abundance at survey T. Both on the log scale. |
| Issue date | Any time after the harvest season S/T has closed (about 1 May of year T) and before the survey at T (June–August). The ledger records the actual date, the git commit, the last survey year used, the last month of environmental data and the index vintage. |
| Blindness | The script refuses to issue T if any estimate for survey T is already in the data. Forecasts issued now for 2025 and 2026 are labelled *pseudo-prospective*: the surveys have happened and WDFW holds the estimates, but they have not entered the repository. The first fully prospective target is survey 2027 (year class 2026), to be issued in spring 2027. |
| Survey date at T | Used by the pre-recruit models. The actual date when the shell-length file already carries it (it does for 2025), otherwise the beach median; the source is recorded. |
| Never overwritten | Ledger rows are appended, never edited. Re-issuing a target requires `RC_FORECAST_REISSUE=1` and leaves the earlier rows in place. |

## 3. Models (fixed)

Each model gives a point forecast and a 95% prediction interval on the log scale, back-transformed for display.

**Pre-recruits at T (year class T − 1), per beach**

| Model | Specification | Role |
|---|---|---|
| climatology | mean of log pre-recruits over all training year classes | baseline every other model must beat |
| trend | log pre ~ year class | is the trend alone worth anything? |
| a_priori_beuti | log pre ~ year class + log spawners + survey date + BEUTI May–Aug of the spawning year | the one a priori hypothesis with retrospective support (negative) |
| exploratory_scan | same, with x = the (series, window) that had the strongest detrended correlation with the coastwide year-class index over the training data, chosen from the full catalogue of `05_window_scan.R` | the "best predictor" of the exploratory search; the chosen series and window are written to the ledger, so the choice is auditable |

**Recruits at T, per beach**

| Model | Specification | Role |
|---|---|---|
| climatology | mean of log recruits | baseline |
| persistence | log recruits at T − 1; interval from year-to-year changes | naive |
| carry_over | log rec_T ~ log pre_(T−1) + log rec_(T−1) | the stock carry-over model that had the only positive retrospective skill |
| carry_over_escapement | log rec_T ~ log pre_(T−1) + log(rec_(T−1) − harvest between the surveys) | the same with the recorded harvest removed (task T11); when the harvest total is missing it is treated as zero and the row says so |

Spawners are recruits at survey T − 1. Harvest is the season total in the season summary. The pre-recruit models use beach-specific least squares, because that is what can be issued and scored per beach; the pooled mixed model of the retrospective analysis is not a forecasting tool.

## 4. Scoring

When the estimates for T arrive, every ledger row for T is scored on the log scale:

- error and absolute error;
- whether the 95% interval covered the observation;
- the continuous ranked probability score (CRPS) of a normal forecast with the interval's standard deviation, which rewards both accuracy and honest width;
- skill against climatology, 1 − (error / climatology error)², per beach and target.

`forecast_scores_summary.csv` averages these by target and model. Three or more scored years are needed before any model is declared better than climatology; one year is one draw.

## 5. What would change the protocol

- Adding a model or changing a specification is allowed only for future targets, with the change dated in this document; rows already issued stay as they are.
- If WDFW supplies sampling variances for the abundance estimates (task T10), the observation will be scored as a distribution rather than a point, and the models refitted with weights; that is a protocol change and is dated here when it happens.
- Harvest totals of zero in the season summary (Kalaloch 2023-24 and 2024-25, Twin Harbors 2024-25) are treated as recorded; confirm whether they mean no harvest or missing data (task T36).

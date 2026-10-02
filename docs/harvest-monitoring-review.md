# Review of the companion repository `razor-clam-harvest-monitoring`

*2 October 2026. Read-only review of `mattgeorgephd/razor-clam-harvest-monitoring` at commit `be3aded` (261 tracked files), made to find what it offers the recruitment analysis: uncertainty for the abundance estimates, harvest between surveys, and context on the stock-assessment method. Claims below cite that repository's paths; numbers were checked against its files.*

## 1. What the repository is

A WDFW review of the recreational **harvest**-estimation method: it reconstructs harvest, effort and CPUE from the creel database, quantifies the uncertainty of the effort-expansion method, and models how reduced field staffing would degrade the estimates. Deliverables are a versioned methodology document (`04_documentation/2026-Review-WDFW_Harvest_Estimate_Methodology-v10.docx`), 21 figures, tidy CSVs and decks. Five R Markdown pipelines (`01_code/`) read only `02_data/consolidated/*.csv`; the Access databases are not in the repository.

The estimate is built in three layers: (1) event-level expansion in the database (validated to reproduce the database's own stored outputs on 13,651 of 13,653 rows), (2) imputation of uncounted beach-days from a donor beach, which lives only in in-season Excel formulas and is where most of the uncertainty sits, and (3) the season rollup.

## 2. The headline for this project

**The repository holds no stock-assessment data and no variance for the abundance estimates.** A search of every R, Python, Markdown, Word, PowerPoint and Excel file for variance, SE, CV, bootstrap, jackknife or confidence-interval calculations found only harvest-side material. There are no per-plot or per-transect pumped-area records, no shell lengths from assessments (the creel `TBL_Length` is harvested clams), and no abundance estimates with SE. The one pointer is the v10 document's reference list, which names Berry-Powell et al. (2023, *J. Shellfish Res.* 42(1):91–98, doi 10.2983/035.042.0109) and states that Cochran (1977, chapter 10, two-stage sampling) is the appropriate reference for the variance of the pumped-area estimator. The 2013 correction memo mentions a spreadsheet with "average recruit size and average density" columns from each assessment, but the workbook in the repository (`harvest correction summary.xls`) carries only harvest columns.

So task T10 (propagate abundance uncertainty) cannot be closed from this repository. What it needs is the per-transect, per-elevation, per-plot counts of the pumped-area surveys, from which a two-stage (transects within beach, plots within transect) variance, or a transect-level bootstrap, follows directly. The forecast protocol (`docs/forecast-protocol.md` §5) is written so that scoring switches to a distributional observation when that variance exists.

## 3. The stock-assessment method as documented there

From `04_documentation/Razor Clam ER Summary (distn).docx`: transects are systematically spaced along the beach with a random start; the transect begins 50 feet above the highest show; elevations are sampled every 50 feet with a random start; at each elevation six plots are pumped (three on either side of the line; 5 hp pump, 60 gal min⁻¹, aluminium ring, 3 minutes per plot, liquefying to 48 inches); clams of 75 mm and under are pre-recruits; the average recruit density by transect, elevation and plot is expanded by the harvestable habitat area to an abundance, which times the exploitation rate gives the TAC. Habitat areas in that memo (m²): Long Beach 7,019,568 (6,945,987 non-reserve + 73,581 reserve), Twin Harbors 2,425,210, Copalis 3,508,313, Mocrocks 2,198,582, Kalaloch 1,245,716. Our `habitat_m2` differs for some beach-years (Long Beach 1997-98: 7,063,716; Kalaloch 1,236,150), so the vintage or reserve treatment of the habitat areas differs (task T38). Plot area and the number of transects per beach are not stated anywhere in the repository.

The management history slide dates the pumped-area method's adoption to 1997, which is why the recruitment series starts there; the 2003 data-notes memo confirms there are no consistent pumped-area data before 1997 and no mark-recapture data.

Exploitation rates: 25% from M = 0.5 and F = 0.75M, 30% from 2006 (F = M), variable up to about 40% scaled by current over maximum spawning biomass with a 40-10 rule (v10 §6.4); Kalaloch fixed at 25.4%; co-managed beaches split 50/50 with the tribes. The v10 document cites "Cheng 2011" and the "Cheng and Kuk 2002 method" for this, so that reference is a WDFW internal report (the owner confirms it is unpublished grey literature; task T7).

## 4. Harvest uncertainty, which does exist

- Correction factor (vehicle-count expansion): bootstrap over component egress surveys gives relative SDs of 5–13% by beach (`02_data/consolidated/cf_uncertainty.csv`: Long Beach 0.056, Twin Harbors 0.051, Copalis 0.126, Mocrocks 0.095) and it is 71–96% of season effort variance (v10 Table 14).
- Imputation of uncounted beach-days: leave-one-out validation over 2,889 paired beach-days gives single-day SD of log error 0.45–0.64, falling to 0.22 over a tide series because errors alternate in sign (lag-1 autocorrelation −0.68).
- CPUE borrowed from a donor beach: SD of log ratio 0.448 overall (0.26–0.48 by pair).
- Season harvest CV by beach-season: 0.05–0.20 (Copalis 0.13–0.14 every season) in `season_estimates.csv`, 2007-08 to 2025-26, four beaches (no Kalaloch).
- The share of effort directly monitored fell from 0.96 (2012-13) to 0.68 (2025-26); the 2026-27 staffing plan would push Long Beach to 85% imputed and its season effort CV from about 9% to about 32%.

These are copied into `02_data/harvest-monitoring/` with provenance.

## 5. What this changes in the recruitment project

1. **Harvest between surveys (T11).** The season labelled by survey year t is the harvest taken between survey t and survey t+1, so it is the right removal term for a carry-over model. The protocol's `carry_over_escapement` model uses it from our own season summary. The harvest repository supplies the same totals with a CV for 2007-08 onward.
2. **Discrepancies in our season summary (new task T36).** Comparing `razor-clam-season-summary-1997-2025.xlsx` with the harvest repository's `Season_Beach_Summary`: most beach-seasons from 2012-13 agree within ±7%, but (i) Copalis and Mocrocks 2009-10 to 2011-12 are 18–30% lower in our file (Copalis 2010-11: 674,714 vs 962,042), consistent with pre-2013-correction values; (ii) Copalis and Mocrocks 2017-18 (233,140 and 164,125) equal the mid-season snapshot, not the final 546,213 and 771,324 plus wastage; (iii) Twin Harbors 2024-25 is recorded as zero harvest in our file against 1,248,274 clams plus 7,099 wastage with 98,096 digger-trips in the harvest repository; (iv) Kalaloch 2010-11: 14,345 vs 4,567; (v) 2016-17 Long Beach effort in our file (149,057) exceeds every harvest-repository figure. Our `exploitation_rate` column and any harvest-adjusted model inherit these.
3. **TAC entry error.** Our `TAC_state` for Mocrocks 2018-19 (3,852,458) exceeds the file's own `TAC` (3,017,548); the harvest workbook has 1,508,774 (task T37).
4. **Kalaloch** has 16 creel events in the database, 40 typed beach-days, a correction factor of exactly 1.000 on three events, and an expansion table borrowed from a 1998 Mocrocks survey. Its harvest numbers are the least reliable, which adds to the reasons to show results with and without it.
5. **Cheng and Kuk (2002)** is an internal WDFW report used for the exploitation-rate rule, not a growth study per se; whether it also carries the von Bertalanffy parameters the notebook used will be known when the owner supplies it.

## 6. Red flags noted in passing

Hard-coded paths and ODBC credentials in `extract_recompute_harvest.Rmd` (cannot run outside WDFW); three spellings of Long Beach persisting inside `consolidated/` (`tide_series.csv`, `cpue_replacement.csv`, `dig_days.csv`, `egress_survey_inventory.csv`), which the pipeline's factor-level cast would turn into NA; hard-coded variance parameters in the staffing model (0.448, 0.137, 0.060, 0.170, 0.541) and the figure pipeline (0.289, 0.046, 0.117); a stale coverage note in `DATA_DICTIONARY.md`; the 2012-13 in-season workbook missing and 2017-18 surviving only as a snapshot. None of these affects what was copied here.

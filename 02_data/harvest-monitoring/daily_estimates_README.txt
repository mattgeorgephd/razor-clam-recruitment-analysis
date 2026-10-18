Recreational fishery, Washington outer coast. Prepared for NOAA (OAP recreational site-choice / travel-cost work).


Overview
Deliverable Daily (beach-day) estimates of effort, harvest, wastage, and CPUE for the five managed razor clam beaches, with a per-row flag stating whether each estimate came from on-beach harvest monitoring or was imputed from another beach.
Beaches (N to S) Long Beach, Twin Harbors, Copalis, Mocrocks, Kalaloch.
Time span 19 harvest seasons, 2007-08 through 2025-26 (dates 2007-10-25 to 2026-05-06). Daily coverage with the monitored/imputed flag begins in 2007-08; season-level coastwide totals extend back to 1949 in WDFW summaries but are not daily and are out of scope here.
Rows One row per open beach-day. 3395 rows.
Prepared 2026-08-04, from the razor-clam-harvest-monitoring repository (main), consolidated data suite + harvest database extract.
Units Effort = expanded digger trips. Harvest & wastage = clams. CPUE = clams per digger trip. Harvest is clams retained (before wastage); total removals = harvest + wastage.

The monitored-vs-imputed flag (what NOAA asked for)
estimate_basis The binary flag. "harvest_monitoring" = a creel/beach-count census was conducted on that beach that day, so effort, harvest and CPUE are measured. "imputed" = no census that day; the value was filled in inside the in-season workbook, usually by scaling a donor beach. "not_estimated" = beach open but no effort recorded.
provenance_detail Finer breakdown. censused = full census; partial_section = Long Beach, one section counted and the other scaled within-beach (still monitoring-based); cross_beach_imputed = effort scaled from a donor beach and harvest = imputed effort x a hand-typed CPUE; reported_no_census = a value was typed for the beach-day with no census on file and no cross-beach donor; open_no_effort = open, no effort recorded.
donor_beach / reference_days For imputed days: the beach(es) whose effort/CPUE were borrowed and the reference date(s) used to scale.

How the estimates are built (WDFW method, 3 layers)
Layer 1 <U+2014> event expansion On a censused beach-day, expanded effort = calculated people x (diggers/people) / correction-factor; harvest = expanded effort x measured CPUE; wastage = harvest x (dead clams / holes) from mortality subsamples. Recomputed from the raw harvest-database census tables and validated to <1e-6 against the database.
Layer 2 <U+2014> imputation On an uncounted open day, effort is scaled from a donor beach counted that day, and harvest = imputed effort x a CPUE typed into the workbook (often ~14-15). This layer carries nearly all of the uncertainty and is exactly what the "imputed" flag marks.
Layer 3 <U+2014> rollup Beach-days sum to beach-season and coastwide totals (see Season_Beach_Summary).

Two value sets, side by side
Operational columns effort_digger_trips, cpue_clams_per_trip, harvest_clams, wastage_clams <U+2014> the estimates as WDFW produced them in-season (workbook effort x measured/typed CPUE). These reproduce the in-season workbook cell-for-cell and sum to the workbook season totals.
Database columns db_effort_digger_trips, db_cpue_clams_per_trip, db_harvest_clams (+ n_events, n_census_rows, n_interviews) <U+2014> an independent clean re-computation from the raw census tables, censused days only. Differs from operational by ~0-2% on effort; use to gauge reliability.
Imputed-day alternative cpue_typed_imputed (the workbook value), cpue_donor_measured (the donor beach's measured CPUE that day), harvest_donor_corrected (effort x donor CPUE). The donor-corrected harvest is the minimum-defensible alternative to the un-verifiable typed CPUE.

Coverage & validation
Monitoring coverage Of 3,324 open beach-days with an effort value: 2,518 monitoring-based (2,355 censused + 163 Long Beach partial-section), 678 cross-beach imputed, 128 reported-no-census. Coverage varies strongly by beach and season (Copalis/Mocrocks often 100% counted; Long Beach frequently 30-60% counted). See Coverage_By_Season.
Reconciliation Census-day database sums tie to the WDFW database recompute exactly (0 residual across 78 beach-seasons). Operational effort sums tie to the in-season workbook season totals to machine precision for all core seasons.

Known limitations (surfaced deliberately)
CPUE > 15 flag 320 beach-days show CPUE above the 15-clam daily limit (cpue_over_15_flag = Y), concentrated in 2021-22 (168) and 2022-23 (58). Flagged in the WDFW methodology review as a data item to scrutinize; may reflect a bag-limit change or measurement issue <U+2014> confirm with WDFW (Bryce Blumenthal) before economic use.
Wastage is sparse Daily wastage is available only for censused days where a mortality subsample was taken (>0 on 534 days, 0 on other censused days, blank on imputed days). Not a full daily series.
2017-18 restored The in-season 2017-18 workbook is a mid-season snapshot (Effort tab held ~10 of 27 dig days). Censused days present in the database but absent from that workbook were added (flagged spine via operational_source); the restored season total (~256,810 trips) matches the FINAL printout (~257,003) to 0.08%.
2022-23 completed Uses the completed-season file (tides restored through 14 May 2023). It classifies days as monitored/imputed only, so Long Beach partial-section detail is not separated for that season.
Kalaloch is thin Kalaloch (co-managed, Olympic NP) appears on only 40 beach-days across 5 seasons and is monitored differently; treat its daily series as sparse.
8 unfilled days 8 open beach-days carry effort but no CPUE source, so operational harvest is blank (all <0.5% of their season effort). NOAA can gross these up with effort x an assumed CPUE if needed.
No digger origin The monitoring data records destination beach/segment, date, effort and harvest, but no digger ORIGIN (home ZIP/city). For a travel-cost/site-choice model, origin must come from license/WILD linkage or a prospective interview add-on (per the 2026-07-23 OAP data-availability note).

Primary sources
Database Razor Clam Recreational Harvest Database iForms.accdb (ACE14), extracted 2026-07-09; estimator recovered from the DB's saved queries + Macro Calculate Harvest Estimate.
In-season workbooks WDFW "YYYY Fall - YYYY Spring Harvest" Effort/Harvest/CPUE workbooks (canonical revision per season).
Methodology 04_documentation/2026-Review-WDFW_Harvest_Estimate_Methodology-v10.docx; 2010 WDFW Harvest Estimate Methodology; Effort_Expansion_Protocol.md; RazorClam_Harvest_DB_DataDictionary.md.
Contact Matt George (WDFW). Lead razor clam biologist: Bryce Blumenthal (WDFW).

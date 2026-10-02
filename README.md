# Razor clam recruitment analysis

Climate and ocean drivers of recruitment in the Washington coast recreational razor clam (*Siliqua patula*) fishery, 1997–2024. The work combines WDFW stock-assessment abundance estimates for five management beaches (Kalaloch, Mocrocks, Copalis, Twin Harbors, Long Beach) with upwelling indices, sea temperature, Columbia River discharge and the PDO.

**Status (2026-10-02).**

- The original exploratory notebook has been reviewed and bug-fixed.
- A reproducible re-analysis has been added (`01_code/R/`): a priori hypotheses tested with multiplicity control, a calibrated exploratory search over every environmental series with honest out-of-sample selection, and a prospective forecast protocol with a scored ledger.
- The environmental record has been extended with satellite SST, buoy winds and waves, lower-river gauges and the current vintages of the upwelling indices and the PDO (`02_data/Environmental Data/external/`).
- A manuscript draft is in `manuscript/`.

Read [`docs/methodology-review.md`](docs/methodology-review.md) §1 for the key findings, [`task.md`](task.md) for open issues, and [`AGENTS.md`](AGENTS.md) if you are an AI agent.

## Quick start

```bash
# from the repository root (R >= 4.3; packages listed in AGENTS.md)
./run_pipeline.sh                # ~2 min; rebuilds 02_data/derived/ and 03_analyses/robust-reanalysis/,
                                 # then compiles every figure and table into 03_analyses/robust-reanalysis/report.md (+ .html)
./run_pipeline.sh --fast         # ~1 min with 200 surrogates, into the git-ignored robust-reanalysis-fast/
./run_pipeline.sh --list         # steps; --help for all flags (--steps, --from, --out, --vintage, --notebook, --install)
# Windows: Rscript 01_code/R/run_all.R [flags]
```

Open `03_analyses/robust-reanalysis/report.md` (or `report.html`) for all results in one place.

The legacy notebook `01_code/razor-clam-recruitment-analysis.Rmd` can still be knitted from RStudio with this project open.

## Repository layout

| Path | Contents |
|---|---|
| `01_code/` | Analysis code. `R/` holds the robust re-analysis pipeline (primary) and `R/acquire/` the fetch scripts for external environmental products (satellite SST, buoy winds and waves, lower-river gauges, current index vintages; run 2026-10-02); `razor-clam-recruitment-analysis.Rmd` is the legacy exploratory notebook; `archive/` holds earlier notebook versions |
| `run_pipeline.sh` | Batch runner (wrapper around `01_code/R/run_all.R`) |
| `02_data/` | Raw inputs (abundance estimates, shell lengths, environmental series), `Environmental Data/external/` (fetched products with provenance), `harvest-monitoring/` (harvest estimates with CVs from the companion repository) and `derived/` analysis-ready tables |
| `03_analyses/` | Outputs. `robust-reanalysis/` (current) and `20260322-recruitment-analysis/` (legacy notebook run, superseded) |
| `docs/` | `methodology-review.md`: full review of methods, data and results, with recommendations. `environmental-record-options.md`: diagnosis of the patchwork environmental record, options, and what the fetched products showed. `forecast-protocol.md`: the prospective forecast test. `harvest-monitoring-review.md`: review of the companion harvest repository. `growth-model-review.md`: the WDFW growth draft, its parameters, and the half-year age offset |
| `manuscript/` | Draft manuscript and its figure and table sources |
| `WDF Razor Clam Hatchery.1988.pdf` | Creekman, Huff & Andrews (1988) *The Razor Clam Hatchery 1980–1987*, WDF Tech. Rep. 1. Background biology (spawning season, larval duration, juvenile washout) |
| `task.md` | Prioritized list of outstanding issues and the fixes already made |
| `AGENTS.md` | Conventions, domain pitfalls and statistical guardrails for AI agents |
| `recruitment-analysis.Rproj` | RStudio project (defines the repository root for `here::here()`) |

## Headline results (robust re-analysis)

- **Survey timing.** Survey date differs by about two months among beaches. Pre-recruits counted at June surveys mostly settled the previous summer, so year-class alignment matters. WDFW's mark-recapture growth curve, once placed on the age axis with the survey length data (t0 about 0.4–0.5 yr), puts the 76 mm boundary at 1.1–1.3 yr and confirms the alignment, except that at the August surveys the fast tail of the year-old cohort is already above it.
- **The original screen.** The original analysis computed about 7,000 correlations; its monthly screen is not distinguishable from an autocorrelation-preserving null (global p = 0.07; 4/900 cells pass FDR). Its apparent forecast skill disappears when predictor selection is done inside cross-validation (skill vs climatology: +0.31 → −0.20).
- **A priori tests.** Of five cohort-aligned predictors, only larval-season upwelling (BEUTI, May–Aug) is associated with year-class strength, and *negatively*; on the current vintage of the index it is borderline after multiplicity correction (coastwide Holm p = 0.05), modest, and without forecast skill.
- **Exploratory search.** Across every environmental series (upwelling indices, buoy and satellite SST, PDO, winds, waves, three river gauges) and every 1–4 month window, no window passes family-wise control, and choosing the best predictor honestly inside each training window gives worse forecasts than climatology. The strongest in-sample signals are upwelling in the year *before* spawning, with the opposite sign to the a priori window.
- **Forecast skill.** Last year's pre-recruit survey forecasts this year's recruits better than any environmental index tested (out-of-sample skill +0.24 overall, up to +0.52 by beach). A prospective protocol now issues and scores forecasts each year (`docs/forecast-protocol.md`).
- **Environmental record.** The legacy station-blended temperature series contains station-switch offsets of up to 0.9 deg C; the pipeline uses a homogenised open-coast series that agrees with satellite SST (r 0.88–0.94), and the SST conclusion is null under seven constructions. The upwelling indices were re-issued by their authors in 2026 and the current vintage, now the primary, carries a 2010/2011 level shift at 47N; measured buoy winds corroborate CUTI's trend but only a third of BEUTI's (`docs/environmental-record-options.md` §6).
- **Uncertainty.** The abundance estimates have no published variance; the companion harvest-monitoring repository supplies harvest CVs only, and several harvest values in the season summary need reconciling (`docs/harvest-monitoring-review.md`).

Details and caveats: `docs/methodology-review.md` and `manuscript/manuscript.md`.

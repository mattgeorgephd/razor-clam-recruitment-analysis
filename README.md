# Razor clam recruitment analysis

Climate and ocean drivers of recruitment in the Washington coast recreational razor clam (*Siliqua patula*) fishery, 1997–2024. The work combines WDFW stock-assessment abundance estimates for five management beaches (Kalaloch, Mocrocks, Copalis, Twin Harbors, Long Beach) with upwelling indices, sea temperature, Columbia River discharge and the PDO.

**Status (2026-10-02).**

- The original exploratory notebook has been reviewed and bug-fixed.
- A reproducible, confirmatory re-analysis has been added (`01_code/R/`).
- A manuscript draft is in `manuscript/`.

Read [`docs/methodology-review.md`](docs/methodology-review.md) §1 for the key findings, [`task.md`](task.md) for open issues, and [`AGENTS.md`](AGENTS.md) if you are an AI agent.

## Quick start

```bash
# from the repository root (R >= 4.3; packages listed in AGENTS.md)
Rscript 01_code/R/run_all.R      # ~3 min; rebuilds 02_data/derived/ and 03_analyses/robust-reanalysis/
```

The legacy notebook `01_code/razor-clam-recruitment-analysis.Rmd` can still be knitted from RStudio with this project open.

## Repository layout

| Path | Contents |
|---|---|
| `01_code/` | Analysis code. `R/` holds the robust re-analysis pipeline (primary); `razor-clam-recruitment-analysis.Rmd` is the legacy exploratory notebook; `archive/` holds earlier notebook versions |
| `02_data/` | Raw inputs (abundance estimates, shell lengths, environmental series) and `derived/` analysis-ready tables |
| `03_analyses/` | Outputs. `robust-reanalysis/` (current) and `20260322-recruitment-analysis/` (legacy notebook run, superseded) |
| `docs/` | `methodology-review.md`: full review of methods, data and results, with recommendations |
| `manuscript/` | Draft manuscript and its figure and table sources |
| `WDF Razor Clam Hatchery.1988.pdf` | Creekman, Huff & Andrews (1988) *The Razor Clam Hatchery 1980–1987*, WDF Tech. Rep. 1. Background biology (spawning season, larval duration, juvenile washout) |
| `task.md` | Prioritized list of outstanding issues and the fixes already made |
| `AGENTS.md` | Conventions, domain pitfalls and statistical guardrails for AI agents |
| `recruitment-analysis.Rproj` | RStudio project (defines the repository root for `here::here()`) |

## Headline results (robust re-analysis)

- **Survey timing.** Survey date differs by about two months among beaches. Pre-recruits counted at June surveys mostly settled the previous summer, so year-class alignment matters.
- **The original screen.** The original analysis computed about 7,000 correlations; its monthly screen is not distinguishable from an autocorrelation-preserving null (global p = 0.07; 4/900 cells pass FDR). Its apparent forecast skill disappears when predictor selection is done inside cross-validation (skill vs climatology: +0.31 → −0.20).
- **Pre-specified tests.** Of five pre-specified, cohort-aligned predictors, only larval-season upwelling (BEUTI, May–Aug) is associated with year-class strength after correction, and *negatively*. The association is modest, robust to detrending method, and has negligible forecast skill.
- **Forecast skill.** Last year's pre-recruit survey forecasts this year's recruits better than any environmental index tested (out-of-sample skill +0.24 overall, up to +0.52 by beach).

Details and caveats: `docs/methodology-review.md` and `manuscript/manuscript.md`.

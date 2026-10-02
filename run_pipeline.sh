#!/usr/bin/env bash
# Batch runner for the robust re-analysis pipeline (thin wrapper around
# 01_code/R/run_all.R; all flags are passed through).
#
#   ./run_pipeline.sh                full run, ~4 min  -> 03_analyses/robust-reanalysis/
#   ./run_pipeline.sh --fast         ~1.5 min, 200 surrogates -> 03_analyses/robust-reanalysis-fast/
#   ./run_pipeline.sh --steps=04,10  rerun the confirmatory models and the report only
#   ./run_pipeline.sh --notebook     also run the legacy notebook afterwards (~15 min)
#   ./run_pipeline.sh --list         list steps;  --help for all options
#
# Windows (no bash): run the same thing from a terminal in the repo root:
#   Rscript 01_code/R/run_all.R [flags]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript not found. Install R >= 4.3 (https://cran.r-project.org) and make sure Rscript is on PATH." >&2
  exit 1
fi
exec Rscript 01_code/R/run_all.R "$@"

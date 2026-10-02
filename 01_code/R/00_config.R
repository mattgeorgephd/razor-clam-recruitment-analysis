# ═══════════════════════════════════════════════════════════════════════════════
# 00_config.R — shared configuration for the robust re-analysis pipeline
# ═══════════════════════════════════════════════════════════════════════════════
# Sourced by every script in 01_code/R/. Run scripts from the repository root
# (the folder containing recruitment-analysis.Rproj), e.g.
#   Rscript 01_code/R/run_all.R
#
# Design decisions are documented in docs/methodology-review.md (section 5).

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(lubridate)
  library(nlme)
})

# ── Paths ────────────────────────────────────────────────────────────────────
# Locate the repo root robustly (works from RStudio project or Rscript).
find_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:5) {
    if (file.exists(file.path(d, "recruitment-analysis.Rproj"))) return(d)
    d <- dirname(d)
  }
  stop("Run from inside the repository (recruitment-analysis.Rproj not found).")
}
ROOT      <- find_root()
DATA_DIR  <- file.path(ROOT, "02_data")
ENV_DIR   <- file.path(DATA_DIR, "Environmental Data")
DERIVED   <- file.path(DATA_DIR, "derived")
OUT_DIR   <- file.path(ROOT, "03_analyses", "robust-reanalysis")   # fixed name: reruns overwrite
FIG_DIR   <- file.path(OUT_DIR, "figures")
TAB_DIR   <- file.path(OUT_DIR, "tables")
for (d in c(DERIVED, OUT_DIR, FIG_DIR, TAB_DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ── Constants ────────────────────────────────────────────────────────────────
BEACHES  <- c("Kalaloch", "Mocrocks", "Copalis", "Twin Harbors", "Long Beach")  # N → S
BEACH_LAT_BIN <- c(Kalaloch = "47N", Mocrocks = "47N", Copalis = "47N",
                   `Twin Harbors` = "47N", `Long Beach` = "46N")
PRE_RECRUIT_MAX_MM <- 75     # WDFW pre-recruit / recruit boundary (<76 mm vs >=76 mm)

# Offshore / open-coast buoys used for the homogeneous regional SST anomaly.
# 46029 Columbia River Bar (1991-), 46041 Cape Elizabeth (1990-2024),
# 46211 Grays Harbor waverider (2004-). Estuarine/harbor stations
# (TOKW1, WPTW1, LAPW1, HMDO3, ...) are deliberately excluded.
SST_STATIONS <- c("46029", "46041", "46211")
SST_MIN_HOURLY_OBS <- 240    # ≈10 days of hourly data for a valid monthly mean
SST_CLIM_YEARS <- 1991:2024  # climatology baseline for station anomalies

SEED <- 20261002
N_SURROGATES <- 2000         # surrogate series for permutation / null calibration

# ── Plot theme ───────────────────────────────────────────────────────────────
theme_ms <- function(base_size = 11) {
  theme_bw(base_size = base_size) +
    theme(panel.grid.minor = element_blank(),
          strip.background = element_rect(fill = "grey92", colour = "black"),
          legend.position = "bottom")
}

save_fig <- function(p, name, width = 7, height = 5, dpi = 300) {
  ggsave(file.path(FIG_DIR, paste0(name, ".png")), p, width = width, height = height, dpi = dpi)
  invisible(p)
}

write_tab <- function(x, name) {
  readr::write_csv(x, file.path(TAB_DIR, paste0(name, ".csv")))
  invisible(x)
}

# z-score helper that tolerates NA
zs <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)

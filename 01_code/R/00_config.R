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
# Output folder: fixed name so reruns overwrite. run_all.R --out=DIR (or the
# RC_OUT_DIR environment variable) redirects everything, e.g. for a --fast run.
OUT_DIR   <- Sys.getenv("RC_OUT_DIR", unset = "")
OUT_DIR   <- if (nzchar(OUT_DIR)) {
  if (grepl("^(/|[A-Za-z]:)", OUT_DIR)) OUT_DIR else file.path(ROOT, OUT_DIR)
} else file.path(ROOT, "03_analyses", "robust-reanalysis")
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

# Station classes for the water-temperature record (02_data/Environmental Data).
# Only open-coast stations enter the regional SST anomaly; the others are kept
# for diagnostics (10_env_record_diagnostics.R). 46087 (Neah Bay offshore,
# 48.5N) sits in the Juan de Fuca eddy and is excluded from the regional index.
STATION_CLASS <- c(
  `46010` = "open coast", `46029` = "open coast", `46041` = "open coast",
  `46087` = "open coast", `46099` = "open coast", `46100` = "open coast",
  `46119` = "open coast", `46211` = "open coast", `46248` = "open coast",
  `46096` = "river mouth", `46127` = "river mouth", `46243` = "river mouth",
  HMDO3 = "estuary/harbor", LAPW1 = "estuary/harbor", NEAW1 = "estuary/harbor",
  TOKW1 = "estuary/harbor", WPTW1 = "estuary/harbor")
SST_OPEN_COAST <- c("46029", "46041", "46211", "46099", "46100", "46248", "46119", "46010")
SST_MIN_STATION_MONTHS <- 24  # stations with shorter records cannot get a climatology

# Which vintage of BEUTI/CUTI and the PDO feeds the predictors.
#   "current" (default since 2026-10-02, owner decision, task T35) the files
#             fetched by acquire/fetch_climate_indices.R into external/
#             (BEUTI/CUTI daily <date> files; PDO from NCEI)
#   "cached"  the earlier snapshots in 02_data/Environmental Data (BEUTI/CUTI
#             to 2025-04; PDO as cached by the notebook), kept for comparison
# The two differ throughout the record (see 09_env_record_diagnostics.R, F).
# run_all.R --vintage=cached sets the other.
INDEX_VINTAGE <- match.arg(Sys.getenv("RC_INDEX_VINTAGE", unset = "current"), c("cached", "current"))

# Growth curve (Cheng and Ayres 2008, docs/references/; method Cheng & Kuk 2002).
# K and L-inf per beach from the two study sites (northern beaches use Copalis,
# Twin Harbors uses Long Beach). The study cannot identify t0; VB_T0 is the
# midpoint of the two survey-based estimates in 02_cohort_diagnostics.R (f)
# (0.39 from mixture components, 0.51 from kernel modes; docs/growth-model-
# review.md). SETTLE_DOY is the nominal settlement date (1 August) from which
# a year class's age is counted; t0 shifts one-for-one with it.
VB_LINF <- c(Kalaloch = 143.17, Mocrocks = 143.17, Copalis = 143.17, `Twin Harbors` = 141.67, `Long Beach` = 141.67)
VB_K    <- c(Kalaloch = 1.00,   Mocrocks = 1.00,   Copalis = 1.00,   `Twin Harbors` = 0.98,   `Long Beach` = 0.98)
VB_T0   <- 0.45
SETTLE_DOY <- 213L
# expected shell length (mm) of a clam of `age` years (counted from SETTLE_DOY)
vb_length <- function(beach, age, K = VB_K[beach], t0 = VB_T0) unname(VB_LINF[beach] * (1 - exp(-K * (age - t0))))
# age (years) at which the curve reaches length L
vb_age <- function(beach, L, K = VB_K[beach], t0 = VB_T0) unname(t0 - log(1 - L / VB_LINF[beach]) / K)

# Growth used by the length mixture (lib_cohort_mixture.R, 01b_cohort_separation.R).
# The WDFW curve at the four southern beaches: tracking year classes across
# consecutive surveys (02_cohort_diagnostics.R (g), tables/cohort_growth_
# increments_summary.csv) gives K = 1.02 at both study beaches with L-inf fixed
# at the WDFW value, so the curve is corroborated there. Kalaloch, which the
# study did not cover, grows about half as fast at a given length (annual
# increment at 55 mm about 31 mm against 56 mm): K from the tracking (0.43),
# with t0 chosen so that the year-old cohort sits at its observed mode (58.8 mm
# at the median survey date, DOY 205; growth_model_check.csv). The year-old cohort gets a fast
# component only where the 76-95 mm clams track the same survey's 25-75 mm
# clams (the four southern beaches); at Kalaloch they track the previous
# survey's 25-75 mm clams, i.e. they are two-year-olds
# (tables/cohort_length_transitions_by_beach.csv).
MIX_K  <- replace(VB_K, "Kalaloch", 0.43)
MIX_T0 <- c(Kalaloch = -0.25, Mocrocks = VB_T0, Copalis = VB_T0, `Twin Harbors` = VB_T0, `Long Beach` = VB_T0)
MIX_FAST_TAIL <- c(Kalaloch = FALSE, Mocrocks = TRUE, Copalis = TRUE, `Twin Harbors` = TRUE, `Long Beach` = TRUE)
mix_length <- function(beach, age) vb_length(beach, age, K = MIX_K[beach], t0 = MIX_T0[beach])

SEED <- 20261002
# Surrogate series for permutation / null calibration. run_all.R --fast sets
# RC_N_SURROGATES=200 (about 1 min instead of 1.5); p-values are then coarser.
N_SURROGATES <- as.integer(Sys.getenv("RC_N_SURROGATES", unset = "2000"))

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

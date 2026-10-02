#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════════════════
# run_all.R — batch runner for the robust re-analysis pipeline
# ═══════════════════════════════════════════════════════════════════════════════
# Runs the numbered scripts in 01_code/R/ in order, each in a fresh environment,
# logs timing and status, and compiles every figure and table into
# <out>/report.md (and report.html when pandoc is available).
#
# Usage, from the repository root (./run_pipeline.sh accepts the same flags):
#   Rscript 01_code/R/run_all.R                full run (~1.5 min) -> 03_analyses/robust-reanalysis/
#   Rscript 01_code/R/run_all.R --fast         200 surrogates instead of 2000 (~1 min);
#                                              writes to 03_analyses/robust-reanalysis-fast/ (git-ignored)
#   Rscript 01_code/R/run_all.R --steps=04,10  only these steps, in this order
#   Rscript 01_code/R/run_all.R --from=05      this step and every later one
#   Rscript 01_code/R/run_all.R --out=DIR      write outputs to DIR (absolute, or relative to root)
#   Rscript 01_code/R/run_all.R --no-report    skip the report step
#   Rscript 01_code/R/run_all.R --notebook     also run the legacy notebook afterwards (~15 min,
#                                              writes 03_analyses/<today>-recruitment-analysis/)
#   Rscript 01_code/R/run_all.R --install      install missing CRAN packages before running
#   Rscript 01_code/R/run_all.R --list         list the steps and exit
#   Rscript 01_code/R/run_all.R --help
#
# Exit status is non-zero if any step fails. Each run appends to <out>/run_log.txt
# and overwrites <out>/run_info.txt and <out>/sessionInfo.txt.
#
# Steps communicate only through files (02_data/derived/, <out>/tables, <out>/figures),
# so any step can be rerun alone once 01 has produced the derived tables.

# ── Step registry (order matters: 10 compiles what 01–09 produce) ───────────
STEPS <- data.frame(
  id   = c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10"),
  file = c("01_build_datasets.R", "02_cohort_diagnostics.R", "03_null_audit.R",
           "04_confirmatory_models.R", "05_window_scan.R", "06_forecast_skill.R",
           "07_figures_overview.R", "08_forecast_2025.R",
           "09_env_record_diagnostics.R", "10_report.R"),
  what = c("Parse raw inputs; derived tables; pre-specified cohort-aligned predictors",
           "Survey timing, length-frequency, cohort linkage, synchrony, trends",
           "Surrogate-null audit of the original screening grid",
           "Pre-specified confirmatory models (LMM, GLS-AR1) and sensitivity analyses",
           "Exploratory window scan with family-wise calibration",
           "Rolling-origin forecast skill (leaky vs honest selection, carry-over)",
           "Study-area map, abundance and predictor time series",
           "Archive forecasts for the 2025 survey (never overwritten)",
           "Environmental-record coverage and homogeneity diagnostics",
           "Compile all figures and tables into report.md / report.html"),
  stringsAsFactors = FALSE)

REQUIRED_PKGS <- c("here", "tidyverse", "readxl", "lubridate", "nlme", "lme4", "maps", "mapdata")
NOTEBOOK_PKGS <- c("knitr", "openxlsx", "scales", "corrplot", "patchwork", "sf", "jsonlite")

# ── Argument parsing ────────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = TRUE)
flag  <- function(name) any(args == paste0("--", name))
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit) == 0) default else sub(paste0("^--", name, "="), "", hit[1])
}
known <- c("fast", "no-report", "notebook", "install", "list", "help", "steps", "from", "out")
unknown <- args[!sub("=.*$", "", sub("^--", "", args)) %in% known]
if (length(unknown) > 0) stop("Unknown argument(s): ", paste(unknown, collapse = " "), "\nRun with --help.")

if (flag("help")) {
  cat(paste(readLines(sub("--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1]))[2:26], collapse = "\n"), "\n")
  quit(status = 0)
}
if (flag("list")) {
  cat(sprintf("  %s  %-30s %s\n", STEPS$id, STEPS$file, STEPS$what), sep = "")
  quit(status = 0)
}

# ── Locate the repository root ──────────────────────────────────────────────
find_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:5) {
    if (file.exists(file.path(d, "recruitment-analysis.Rproj"))) return(d)
    d <- dirname(d)
  }
  stop("Run from inside the repository (recruitment-analysis.Rproj not found).")
}
ROOT <- find_root()
setwd(ROOT)

# ── Dependencies ────────────────────────────────────────────────────────────
need <- REQUIRED_PKGS
if (flag("notebook")) need <- c(need, NOTEBOOK_PKGS)
missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0 && flag("install")) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = getOption("repos", "https://cloud.r-project.org"))
  missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
}
if (length(missing) > 0) {
  stop("Missing R packages: ", paste(missing, collapse = ", "),
       "\nInstall them (install.packages(c(", paste0('"', missing, '"', collapse = ", "),
       "))) or rerun with --install. On Ubuntu/Debian the r-cran-* apt packages also work.")
}

# ── Output folder and run-time overrides (read by 00_config.R) ──────────────
out <- value("out", if (flag("fast")) "03_analyses/robust-reanalysis-fast" else "03_analyses/robust-reanalysis")
if (!grepl("^(/|[A-Za-z]:)", out)) out <- file.path(ROOT, out)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(RC_OUT_DIR = out)
if (flag("fast")) Sys.setenv(RC_N_SURROGATES = "200")
n_surr <- Sys.getenv("RC_N_SURROGATES", unset = "2000")

# ── Which steps ─────────────────────────────────────────────────────────────
ids <- STEPS$id
if (!is.null(value("steps"))) {
  ids <- trimws(strsplit(value("steps"), ",")[[1]])
  bad <- setdiff(ids, STEPS$id)
  if (length(bad) > 0) stop("Unknown step id(s): ", paste(bad, collapse = ", "), ". Use --list.")
} else if (!is.null(value("from"))) {
  if (!value("from") %in% STEPS$id) stop("Unknown step id for --from. Use --list.")
  ids <- STEPS$id[STEPS$id >= value("from")]
}
if (flag("no-report")) ids <- setdiff(ids, "10")
steps <- STEPS[match(ids, STEPS$id), ]

# ── Logging helpers ─────────────────────────────────────────────────────────
LOG <- file.path(out, "run_log.txt")
log_line <- function(...) {
  msg <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ", ...)
  message(msg)
  cat(msg, "\n", file = LOG, append = TRUE, sep = "")
}
git <- function(...) tryCatch(suppressWarnings(system2("git", c("-C", shQuote(ROOT), ...),
                                                        stdout = TRUE, stderr = FALSE)),
                              error = function(e) character(0))
commit <- git("rev-parse", "--short", "HEAD"); if (length(commit) == 0) commit <- "unknown"
dirty  <- length(git("status", "--porcelain", "--untracked-files=no")) > 0

log_line("═══ run_all.R start ═══ args: ", if (length(args)) paste(args, collapse = " ") else "(none)")
log_line("root ", ROOT, " | out ", out, " | commit ", commit, if (dirty) " (uncommitted changes)" else "",
         " | surrogates ", n_surr, " | R ", getRversion())

# ── Run the steps ───────────────────────────────────────────────────────────
t_all <- Sys.time()
timings <- data.frame(id = character(), file = character(), seconds = numeric(), status = character(),
                      stringsAsFactors = FALSE)
for (i in seq_len(nrow(steps))) {
  s <- steps[i, ]
  path <- file.path(ROOT, "01_code", "R", s$file)
  log_line("▶ step ", s$id, "  ", s$file, "  (", s$what, ")")
  t0 <- Sys.time()
  status <- "ok"
  res <- tryCatch({
    source(path, local = new.env())   # fresh environment: steps stay independent
    NULL
  }, error = function(e) e)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (inherits(res, "error")) {
    status <- "FAILED"
    log_line("✖ step ", s$id, " failed after ", round(secs), " s: ", conditionMessage(res))
    timings[nrow(timings) + 1, ] <- list(s$id, s$file, secs, status)
    log_line("═══ run_all.R aborted ═══")
    quit(status = 1)
  }
  log_line("  done in ", round(secs), " s")
  timings[nrow(timings) + 1, ] <- list(s$id, s$file, secs, status)
}

# ── Optional: legacy notebook ───────────────────────────────────────────────
if (flag("notebook")) {
  log_line("▶ legacy notebook (01_code/razor-clam-recruitment-analysis.Rmd)")
  t0 <- Sys.time()
  purled <- file.path(tempdir(), "razor-clam-notebook.R")
  knitr::purl(file.path(ROOT, "01_code", "razor-clam-recruitment-analysis.Rmd"),
              output = purled, quiet = TRUE)
  nb_log <- file.path(out, "notebook_run.log")
  st <- system2("Rscript", shQuote(purled), stdout = nb_log, stderr = nb_log)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (st != 0) {
    log_line("✖ notebook failed after ", round(secs), " s; see ", nb_log)
    quit(status = 1)
  }
  log_line("  notebook done in ", round(secs), " s; outputs in 03_analyses/",
           format(Sys.Date(), "%Y%m%d"), "-recruitment-analysis/; log ", nb_log)
}

# ── Wrap up ─────────────────────────────────────────────────────────────────
total <- as.numeric(difftime(Sys.time(), t_all, units = "secs"))
writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
writeLines(c(
  paste0("run_all.R  ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("commit     ", commit, if (dirty) " (uncommitted changes present)" else ""),
  paste0("args       ", if (length(args)) paste(args, collapse = " ") else "(none)"),
  paste0("out        ", out),
  paste0("surrogates ", n_surr),
  paste0("R          ", getRversion()),
  paste0("total      ", round(total), " s"),
  "",
  sprintf("%s  %-30s %6.0f s  %s", timings$id, timings$file, timings$seconds, timings$status)
), file.path(out, "run_info.txt"))
log_line("═══ run_all.R finished in ", round(total), " s ═══  report: ",
         if ("10" %in% ids) file.path(out, "report.md") else "(skipped)")

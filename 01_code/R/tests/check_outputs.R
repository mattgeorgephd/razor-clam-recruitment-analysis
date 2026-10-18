#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════════════════
# tests/check_outputs.R — regression checks on the pipeline outputs (task T30)
# ═══════════════════════════════════════════════════════════════════════════════
# Compares a curated set of key numbers in <out>/tables/ with the values in
# expected_key_numbers.csv (one row per number: table, a dplyr filter that
# selects exactly one row, the column, the expected value, a tolerance and a
# note), and checks that the derived tables and every required output exist
# with the expected shape. Exit status is non-zero on any failure, so CI fails.
#
#   Rscript 01_code/R/tests/check_outputs.R                  check the main output folder
#   Rscript 01_code/R/tests/check_outputs.R --out=DIR        check another folder
#   Rscript 01_code/R/tests/check_outputs.R --write-expected rewrite the expected values
#                                                            from the current outputs
#                                                            (keeps filters, tolerances,
#                                                            notes); do this only after a
#                                                            deliberate change, and commit
#                                                            the new file with the outputs
# Tolerances: exact for counts and medians of integers; 1e-6 for deterministic
# statistics; looser (0.01-0.02) for surrogate-based thresholds and skill scores,
# which can move with platform numerics.

suppressPackageStartupMessages({ library(dplyr); library(readr); library(rlang) })
args <- commandArgs(trailingOnly = TRUE)
val <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), args, value = TRUE); if (length(h)) sub(paste0("^--", name, "="), "", h[1]) else default }
root <- normalizePath(here::here())
out <- val("out", file.path(root, "03_analyses", "robust-reanalysis"))
if (!grepl("^(/|[A-Za-z]:)", out)) out <- file.path(root, out)
tab_dir <- file.path(out, "tables"); fig_dir <- file.path(out, "figures")
spec_file <- file.path(root, "01_code", "R", "tests", "expected_key_numbers.csv")
spec <- read_csv(spec_file, show_col_types = FALSE, col_types = cols(.default = col_character(), expected = col_double(), tolerance = col_double()))

fails <- character(0); passes <- 0L
fail <- function(msg) { fails <<- c(fails, msg); message("FAIL  ", msg) }
pass <- function(msg) { passes <<- passes + 1L; message("ok    ", msg) }

# ── structure: derived tables and required outputs ──────────────────────────
derived <- file.path(root, "02_data", "derived")
for (f in c("survey_beach_year.csv", "env_monthly.csv", "cohort_table.csv", "cohort_lengths.csv")) {
  if (file.exists(file.path(derived, f))) pass(paste("derived", f)) else fail(paste("missing derived table", f))
}
if (file.exists(file.path(root, "02_data", "corrected", "shell_lengths_corrected.csv.gz"))) pass("corrected shell lengths present") else fail("missing 02_data/corrected/shell_lengths_corrected.csv.gz")
required_tabs <- c("survey_timing_by_beach", "cohort_linkage", "cohort_separation_summary", "cohort_growth_increments_summary",
                   "null_audit_global", "confirmatory_pooled", "confirmatory_coastwide_index", "confirmatory_pooled_lengthbased",
                   "confirmatory_sst_beachlevel", "confirmatory_pooled_density", "window_scan_summary", "window_scan_top10",
                   "forecast_skill_cohort_framework", "forecast_skill_cohort_framework_lengthbased", "forecast_ledger",
                   "env_sst_variants", "env_index_vintages", "habitat_area_changes")
for (t in required_tabs) if (file.exists(file.path(tab_dir, paste0(t, ".csv")))) pass(paste("table", t)) else fail(paste("missing table", t))
required_figs <- c("fig_confirmatory_forest", "fig_window_scan_pre", "fig_forecast_skill_cohort", "fig_cohort_mixture_examples", "fig_growth_increments")
for (f in required_figs) if (file.exists(file.path(fig_dir, paste0(f, ".png")))) pass(paste("figure", f)) else fail(paste("missing figure", f))

sv <- read_csv(file.path(derived, "survey_beach_year.csv"), show_col_types = FALSE)
if (!anyDuplicated(sv[c("beach", "survey_year")])) pass("no duplicated beach-years") else fail("duplicated beach-years in survey_beach_year")
ct <- read_csv(file.path(derived, "cohort_table.csv"), show_col_types = FALSE)
if (nrow(ct) == 5 * length(1988:2024)) pass("cohort_table is a complete grid") else fail(paste("cohort_table has", nrow(ct), "rows"))
ledger <- read_csv(file.path(tab_dir, "forecast_ledger.csv"), show_col_types = FALSE)
if (nrow(ledger) >= as.numeric(spec$expected[spec$id == "ledger_rows_min"])) pass("forecast ledger has not shrunk") else fail("forecast ledger has fewer rows than expected (it must never be overwritten)")

# ── key numbers ─────────────────────────────────────────────────────────────
get_value <- function(row) {
  f <- file.path(tab_dir, paste0(row$table, ".csv"))
  if (!file.exists(f)) return(NA_real_)
  d <- read_csv(f, show_col_types = FALSE, progress = FALSE)
  if (!is.na(row$filter) && nzchar(row$filter)) d <- d %>% filter(!!parse_expr(row$filter))
  if (nrow(d) != 1) return(NA_real_)
  as.numeric(d[[row$column]])
}
values <- vapply(seq_len(nrow(spec)), function(i) get_value(spec[i, ]), numeric(1))

if ("--write-expected" %in% args) {
  spec$expected <- ifelse(spec$id == "ledger_rows_min", nrow(ledger), values)
  write_csv(spec, spec_file)
  message("wrote ", spec_file, " (", nrow(spec), " expected values from ", out, ")")
  quit(status = 0)
}
for (i in seq_len(nrow(spec))) {
  r <- spec[i, ]
  if (r$id == "ledger_rows_min") next
  v <- values[i]
  lab <- sprintf("%s: %s = %s (expected %s, tol %s)", r$id, r$column, format(v, digits = 6), format(r$expected, digits = 6), format(r$tolerance))
  if (is.na(v)) fail(paste(lab, "[value not found: table missing or filter did not select one row]"))
  else if (abs(v - r$expected) <= r$tolerance) pass(lab) else fail(lab)
}

message("\n", passes, " checks passed, ", length(fails), " failed")
if (length(fails) > 0) { message("Failures:\n  ", paste(fails, collapse = "\n  ")); quit(status = 1) }

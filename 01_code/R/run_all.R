# ═══════════════════════════════════════════════════════════════════════════════
# run_all.R — rebuild every derived dataset, table and figure of the robust
# re-analysis. From the repository root:
#     Rscript 01_code/R/run_all.R
# Runtime ≈ 3 min on a laptop. Outputs: 02_data/derived/, 03_analyses/robust-reanalysis/
# ═══════════════════════════════════════════════════════════════════════════════

scripts <- c("01_build_datasets.R", "02_cohort_diagnostics.R", "03_null_audit.R",
             "04_confirmatory_models.R", "05_window_scan.R", "06_forecast_skill.R",
             "07_figures_overview.R")
for (s in scripts) {
  message("\n▶ ", s)
  t0 <- Sys.time()
  # each script in a fresh environment so they stay independent
  source(here::here("01_code", "R", s), local = new.env())
  message("  done in ", round(difftime(Sys.time(), t0, units = "secs")), " s")
}
writeLines(capture.output(sessionInfo()),
           here::here("03_analyses", "robust-reanalysis", "sessionInfo.txt"))

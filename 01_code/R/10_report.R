# ═══════════════════════════════════════════════════════════════════════════════
# 10_report.R — compile every figure and table into one document
# ═══════════════════════════════════════════════════════════════════════════════
# Writes <out>/report.md (GitHub-renderable: relative image links, pipe tables)
# and, when pandoc is available (on PATH, or bundled with RStudio and found via
# rmarkdown), <out>/report.html with all images embedded. No knitr/rmarkdown
# dependency for the Markdown itself. Tables longer than MAX_ROWS are truncated
# with a pointer to the CSV.

source(here::here("01_code", "R", "00_config.R"))

MAX_ROWS <- 60
REPORT_MD   <- file.path(OUT_DIR, "report.md")
REPORT_HTML <- file.path(OUT_DIR, "report.html")

FIG_CAPTIONS <- c(
  fig_study_area = "Study area: management beaches (red), open-coast buoys used for the regional SST anomaly (triangles), and the 46N / 47N upwelling-index latitude bins.",
  fig_abundance_timeseries = "Estimated abundance of pre-recruits (<76 mm) and recruits (>=76 mm) by beach and survey year (log scale).",
  fig_predictor_timeseries = "The five pre-specified cohort-aligned predictors with linear trends.",
  fig_survey_timing = "Median stock-assessment survey date by beach and year (crosses: imputed).",
  fig_length_frequency = "Length-frequency distributions by beach and survey timing; a <=20 mm settler mode appears only in surveys after mid-July.",
  fig_cohort_linkage = "Log pre-recruits at survey t versus log recruits at survey t+1.",
  fig_null_audit = "Largest |r| in the original 90-cell screening grid per beach and size class (red) against phase-randomised surrogates (grey).",
  fig_confirmatory_forest = "Pre-specified predictor effects (per SD, 95% CI) on pre-recruits of year class Y at survey Y+1 and recruits at Y+2, under three specifications.",
  fig_beach_heterogeneity = "Beach-specific GLS-AR(1) estimates for the same predictors.",
  fig_window_scan_pre = "Exploratory window scan for pre-recruits: detrended r of every 1-4 month window with the coastwide year-class index; outlined cells would pass family-wise control.",
  fig_window_scan_rec = "Exploratory window scan for recruits (same conventions).",
  fig_forecast_skill = "Rolling-origin forecast skill versus climatology: leaky vs honest predictor selection, persistence, stock carry-over.",
  fig_env_coverage = "Coverage of every environmental source by year-month; the clam survey period is boxed.",
  fig_legacy_idw_vs_homogenized = "The legacy notebook's station-blended beach temperature (points, coloured by dominant station) against the homogenised regional anomaly (line).",
  fig_sst_homogenization = "The regional SST anomaly under four constructions, with +/- 2 SE of the pipeline series.",
  fig_beuti_homogeneity = "May-Aug BEUTI, CUTI and their ratio at 46N and 47N, with the 2010/2011 source-model boundary marked.")

TAB_DESCRIPTIONS <- c(
  abundance_summary = "Median, range and SD of log abundance by beach and size class",
  survey_timing_by_beach = "Median and SD of survey day of year; trend in days per year",
  prerecruit_lt30_share_by_timing = "Share of pre-recruits <20 mm and <30 mm by survey-timing class",
  cohort_linkage = "Correlations linking pre-recruits and recruits across consecutive surveys",
  synchrony_prerecruits = "Cross-beach correlation matrix, log pre-recruits",
  synchrony_recruits = "Cross-beach correlation matrix, log recruits",
  synchrony_summary = "Mean cross-beach correlation, raw and detrended, with and without Kalaloch",
  trends = "GLS-AR(1) linear trends of log abundance and of predictors",
  null_audit_reproduction_check = "Agreement of the re-implemented screening grid with the committed legacy workbook",
  null_audit_global = "Observed vs surrogate-null count of p<0.05 cells; BH-FDR counts",
  null_audit_by_series = "Per beach x size class: observed max|r|, null quantiles, family-wise p",
  null_audit_all_cells = "All 900 screening cells (sorted by p)",
  null_audit_selected_predictors = "The 20 predictors chosen by the legacy models: raw, detrended and effective-n p-values",
  confirmatory_pooled = "Pooled LMM effects with LRT p, Holm and BH, under three specifications",
  confirmatory_full_model = "All five predictors in one model",
  confirmatory_coastwide_index = "Coastwide index GLS-AR(1) effects",
  confirmatory_by_beach = "Beach-specific GLS-AR(1) effects with BH q",
  confirmatory_beuti_robustness = "BEUTI and CUTI under alternative detrending, first differences, leave-one-out, without the most influential year",
  confirmatory_predictor_correlations = "Correlations among predictors and with year",
  window_scan_summary = "Window-scan totals and null thresholds",
  window_scan_best_per_variable = "Best window per variable with naive, BH and family-wise p",
  window_scan_all = "All scanned windows (sorted by naive p)",
  forecast_skill_original_framework = "Skill vs climatology, original response definition",
  forecast_skill_original_by_series = "Skill by beach x size class",
  forecast_skill_cohort_framework = "Skill of trend, BEUTI and trend+BEUTI models for year-class pre-recruits",
  forecast_skill_fallback_counts = "Forecasts that fell back to climatology for lack of a predictor",
  forecast_2025_archived = "Archived forecasts for the 2025 survey (made before the estimates were available)",
  env_coverage_by_station = "Temperature and salinity stations: class, distance to nearest beach, record length",
  env_coverage_by_year = "Months of data per year for each environmental source",
  env_legacy_idw_station_eras = "Mean difference between the legacy blended series and the homogenised anomaly, by beach and dominant station",
  env_sst_variants = "Agreement and coverage of alternative regional SST constructions",
  env_sst_variant_effects = "Effect of May-Sep SST on the pre-recruit index under each construction",
  env_sst_station_parameters = "Station gains, error SDs and leave-one-station-out agreement",
  env_beuti_step_tests = "Trend, 2011 level shift and best single breakpoint for BEUTI, CUTI and their ratio",
  env_beuti_latitude_periods = "BEUTI and CUTI May-Aug means by latitude bin and period",
  env_index_annual_correlations = "Annual correlations among indices, raw and detrended")

# ── helpers ──────────────────────────────────────────────────────────────────
fmt_num <- function(v) {
  if (is.na(v)) return("")
  if (abs(v - round(v)) < 1e-9 && abs(v) < 1e7) return(format(round(v), scientific = FALSE))
  format(signif(v, 3), scientific = FALSE, drop0trailing = TRUE)
}
md_table <- function(df, max_rows = MAX_ROWS) {
  n <- nrow(df)
  if (n == 0) return("(empty table)")
  shown <- head(df, max_rows)
  cells <- lapply(names(shown), function(cn) {
    col <- shown[[cn]]
    if (is.numeric(col)) vapply(col, fmt_num, "")
    else { s <- as.character(col); s[is.na(s)] <- ""; gsub("\\|", "\\\\|", gsub("[\r\n]+", " ", s)) }
  })
  rows <- do.call(paste, c(cells, sep = " | "))
  out <- c(paste0("| ", paste(names(shown), collapse = " | "), " |"),
           paste0("|", paste(rep("---", ncol(shown)), collapse = "|"), "|"),
           paste0("| ", rows, " |"))
  if (n > max_rows) out <- c(out, "", sprintf("*First %d of %d rows; full table in the CSV.*", max_rows, n))
  paste(out, collapse = "\n")
}
get_tab <- function(name) {
  f <- file.path(TAB_DIR, paste0(name, ".csv"))
  if (!file.exists(f)) return(NULL)
  readr::read_csv(f, show_col_types = FALSE, progress = FALSE)
}
r2 <- function(x, d = 2) formatC(x, format = "f", digits = d)
safe <- function(expr) tryCatch(expr, error = function(e) NULL)

# ── run metadata ─────────────────────────────────────────────────────────────
git <- function(...) tryCatch(suppressWarnings(system2("git", c("-C", shQuote(ROOT), ...), stdout = TRUE, stderr = FALSE)),
                              error = function(e) character(0))
commit <- git("rev-parse", "--short", "HEAD"); if (length(commit) == 0) commit <- "unknown"
run_info <- if (file.exists(file.path(OUT_DIR, "run_info.txt"))) readLines(file.path(OUT_DIR, "run_info.txt")) else character(0)

# ── key results ──────────────────────────────────────────────────────────────
key <- character(0)
add <- function(...) key <<- c(key, paste0(...))
safe({
  st <- get_tab("survey_timing_by_beach")
  if (!is.null(st)) {
    d <- function(doy) format(as.Date(doy - 1, origin = "2001-01-01"), "%d %b")
    add("- **Survey timing.** Median survey date ranges from ", d(min(st$median_doy)), " (",
        st$beach[which.min(st$median_doy)], ") to ", d(max(st$median_doy)), " (", st$beach[which.max(st$median_doy)],
        "); significant drift (p < 0.05) at ", sum(st$p < 0.05), " of 5 beaches.")
  }
})
safe({
  cl <- get_tab("cohort_linkage")
  if (!is.null(cl)) add("- **Cohort linkage.** Pre-recruits at survey t predict recruits at t+1 at ",
                        sum(cl$p_pre_t_rec_t1 < 0.05), " of 5 beaches (r = ",
                        r2(min(cl$r_pre_t_rec_t1)), " to ", r2(max(cl$r_pre_t_rec_t1)), ").")
})
safe({
  g <- get_tab("null_audit_global")
  if (!is.null(g)) add("- **Original screen vs chance.** ", g$observed_sig_p05, " of ", g$cells,
                       " cells have p < 0.05; the surrogate null gives a median of ", round(g$null_median),
                       " (95th percentile ", round(g$null_95), "), global p = ", r2(g$p_global),
                       "; ", g$bh_q05, " cells survive BH-FDR at q < 0.05.")
})
safe({
  cp <- get_tab("confirmatory_pooled"); cc <- get_tab("confirmatory_coastwide_index")
  if (!is.null(cp)) {
    pr <- cp %>% filter(response == "log_pre_next", predictor == "beuti_larval", trend, !drop_kalaloch)
    nk <- cp %>% filter(response == "log_pre_next", predictor == "beuti_larval", trend, drop_kalaloch)
    add("- **BEUTI (May-Aug Y) on pre-recruits of year class Y.** Pooled LMM: ", r2(pr$estimate), " (",
        r2(pr$lo), " to ", r2(pr$hi), ") per SD, LRT p = ", r2(pr$p_lrt, 3), ", Holm p = ", r2(pr$p_holm, 2),
        "; excluding Kalaloch: ", r2(nk$estimate), ", Holm p = ", r2(nk$p_holm, 3),
        if (!is.null(cc)) { x <- cc %>% filter(response == "log_pre_next", predictor == "beuti_larval")
          paste0("; coastwide index GLS-AR(1): ", r2(x$estimate), " +/- ", r2(x$se), " SD, Holm p = ", r2(x$p_holm, 3)) } else "",
        ".")
    other <- cp %>% filter(response == "log_pre_next", predictor != "beuti_larval", trend, !drop_kalaloch)
    add("- **Other pre-specified predictors of pre-recruits.** None approach significance (smallest p = ",
        r2(min(other$p_lrt), 2), ").")
    rq <- cp %>% filter(response == "log_rec_next2", predictor == "q_freshet", trend, !drop_kalaloch)
    add("- **Recruits at Y+2.** Only Columbia freshet discharge is nominally associated: ", r2(rq$estimate),
        " (", r2(rq$lo), " to ", r2(rq$hi), "), p = ", r2(rq$p_lrt, 3), ", Holm p = ", r2(rq$p_holm, 2), ".")
  }
})
safe({
  ws <- get_tab("window_scan_summary")
  if (!is.null(ws)) add("- **Exploratory window scan.** ", sum(ws$n_windows), " windows tested; ",
                        sum(ws$n_fwer_sig), " pass family-wise control.")
})
safe({
  fs <- get_tab("forecast_skill_original_framework")
  if (!is.null(fs)) {
    g <- function(resp, model) fs$skill_vs_climatology[fs$resp == resp & fs$model == model]
    add("- **Forecast skill vs climatology.** Pre-recruits: leaky selection ", r2(g("Pre", "leaky_1")),
        " vs honest selection ", r2(g("Pre", "honest_1")), ". Recruits: leaky ", r2(g("Rec", "leaky_1")),
        ", honest ", r2(g("Rec", "honest_1")), ", stock carry-over (no environment) ", r2(g("Rec", "carryover")), ".")
  }
})
safe({
  ev <- get_tab("env_sst_variants"); er <- get_tab("env_legacy_idw_station_eras"); bs <- get_tab("env_beuti_step_tests")
  if (!is.null(ev)) add("- **SST construction.** Alternative regional anomaly constructions agree at r = ",
                        r2(min(ev$r_vs_V1_monthly[ev$variant != "V1 homogenised open coast (pipeline)"])), " to ",
                        r2(max(ev$r_vs_V1_monthly[ev$variant != "V1 homogenised open coast (pipeline)"])), " monthly.")
  if (!is.null(er)) add("- **Legacy station blend.** Largest era-mean offset of the legacy blended series from the homogenised anomaly: ",
                        r2(max(abs(er$mean_diff_legacy_minus_homog))), " deg C (", er$beach[which.max(abs(er$mean_diff_legacy_minus_homog))],
                        ", ", er$dom_label[which.max(abs(er$mean_diff_legacy_minus_homog))], ").")
  if (!is.null(bs)) { b47 <- bs %>% filter(lat == "47N", series == "beuti")
    add("- **BEUTI homogeneity.** At 47N the May-Aug BEUTI trend is ", r2(b47$trend_per_decade), " per decade; a 2011 level shift of ",
        r2(b47$step_2011), " (p = ", r2(b47$step_2011_p, 2), ") after allowing for the trend; best single breakpoint ", b47$best_break_year, ".") }
})

# ── assemble ─────────────────────────────────────────────────────────────────
figs <- list.files(FIG_DIR, pattern = "\\.png$")
fig_names <- sub("\\.png$", "", figs)
ordered_figs <- c(intersect(names(FIG_CAPTIONS), fig_names), setdiff(fig_names, names(FIG_CAPTIONS)))
tabs <- sub("\\.csv$", "", list.files(TAB_DIR, pattern = "\\.csv$"))
ordered_tabs <- c(intersect(names(TAB_DESCRIPTIONS), tabs), setdiff(tabs, names(TAB_DESCRIPTIONS)))

md <- c(
  "# Razor clam recruitment re-analysis: results report",
  "",
  paste0("*Generated ", format(Sys.time(), "%Y-%m-%d %H:%M"), " by `01_code/R/10_report.R` at commit `", commit,
         "`. Every figure and table below is regenerated by `Rscript 01_code/R/run_all.R`; ",
         "methods are described in `docs/methodology-review.md` and the manuscript draft in `manuscript/manuscript.md`.*"),
  "",
  if (length(run_info)) c("```", run_info, "```", "") else NULL,
  "## Key results",
  "",
  if (length(key)) key else "(tables not found; run steps 02-09 first)",
  "",
  "## Figures",
  "",
  unlist(lapply(seq_along(ordered_figs), function(i) {
    f <- ordered_figs[i]
    cap <- if (f %in% names(FIG_CAPTIONS)) FIG_CAPTIONS[[f]] else "(no caption registered in 10_report.R)"
    c(paste0("### Figure ", i, ": ", f), "", paste0("![", cap, "](figures/", f, ".png)"), "", cap, "")
  })),
  "## Tables",
  "",
  unlist(lapply(ordered_tabs, function(t) {
    df <- get_tab(t)
    desc <- if (t %in% names(TAB_DESCRIPTIONS)) TAB_DESCRIPTIONS[[t]] else "(no description registered in 10_report.R)"
    c(paste0("### ", t), "", paste0(desc, ". Source: `tables/", t, ".csv`."), "", md_table(df), "")
  }))
)
writeLines(md, REPORT_MD)
message("10_report: wrote ", REPORT_MD)

# ── HTML via pandoc, if available ───────────────────────────────────────────
find_pandoc <- function() {
  p <- unname(Sys.which("pandoc"))
  if (nzchar(p)) return(p)
  if (requireNamespace("rmarkdown", quietly = TRUE)) {
    p <- tryCatch(rmarkdown::pandoc_exec(), error = function(e) "")
    if (nzchar(p) && file.exists(p)) return(p)
  }
  ""
}
pandoc <- find_pandoc()
if (nzchar(pandoc)) {
  ver <- tryCatch(as.numeric_version(sub("^pandoc(\\.exe)?\\s+", "", system2(pandoc, "--version", stdout = TRUE)[1])),
                  error = function(e) as.numeric_version("0"))
  embed <- if (ver >= "2.19") "--embed-resources" else "--self-contained"
  css <- tempfile(fileext = ".css")
  writeLines(c("body{max-width:1100px;margin:2em auto;padding:0 1em;font-family:system-ui,sans-serif;line-height:1.45}",
               "img{max-width:100%;height:auto;border:1px solid #ddd}",
               "table{border-collapse:collapse;font-size:12px;margin:0.5em 0}",
               "th,td{border:1px solid #ccc;padding:2px 6px;text-align:right}th{background:#f3f3f3}",
               "td:first-child,th:first-child{text-align:left}",
               "pre{background:#f6f6f6;padding:0.5em;font-size:12px}",
               "nav#TOC{font-size:13px;column-count:2}"), css)
  st <- system2(pandoc, c(shQuote(REPORT_MD), "-o", shQuote(REPORT_HTML), "--from=gfm", "--standalone", embed,
                          "--toc", "--toc-depth=2", "--metadata", shQuote("title=Razor clam recruitment re-analysis results report"),
                          "--css", shQuote(css), "--resource-path", shQuote(OUT_DIR)),
                stdout = FALSE, stderr = FALSE)
  if (st == 0) message("10_report: wrote ", REPORT_HTML) else message("10_report: pandoc failed (status ", st, "); report.md is complete")
} else {
  message("10_report: pandoc not found; report.md written, report.html skipped")
}

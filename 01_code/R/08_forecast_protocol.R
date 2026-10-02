# ═══════════════════════════════════════════════════════════════════════════════
# 08_forecast_protocol.R — prospective forecasts under a fixed protocol, with a
# ledger that is scored when the estimates arrive
# ═══════════════════════════════════════════════════════════════════════════════
# Protocol: docs/forecast-protocol.md. In short:
#   * Target survey year T = (last survey year with abundance estimates) + 1.
#     Forecasts are issued once per T, appended to tables/forecast_ledger.csv
#     with the issue date, git commit and the data they used, and never
#     overwritten. Rerunning the pipeline after T's estimates are added scores
#     the T rows (tables/forecast_scores.csv) and issues T+1.
#   * Targets: log pre-recruits at survey T (year class T-1) and log recruits
#     at survey T, per beach. Scores on the log scale: error, absolute error,
#     95% interval coverage, CRPS (normal), skill vs climatology.
#   * Models are fixed here and in the protocol document. Pre-recruits:
#     climatology, trend, a priori (trend + spawners + survey date + BEUTI
#     May-Aug of the spawning year), exploratory (the same model with the
#     best (series, window) chosen from the window catalogue on the data
#     available at issue, recorded in the ledger). Recruits: climatology,
#     persistence, carry-over (pre and recruits at T-1), carry-over with
#     escapement (recruits at T-1 minus the harvest taken between the surveys).
#   * Survey date at T: the actual date when the shell-length file already has
#     it, else the beach median (recorded).
# The 2025 forecasts archived on 2026-10-02 by the earlier script
# (forecast_2025_archived.csv) were a proof of concept and are kept as they are.

source(here::here("01_code", "R", "00_config.R"))
source(here::here("01_code", "R", "lib_window_catalogue.R"))

survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE) %>%
  mutate(beach = factor(beach, BEACHES)) %>% arrange(beach, survey_year)
cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE)
env    <- read_csv(file.path(DERIVED, "env_monthly.csv"), show_col_types = FALSE)
ledger_file <- file.path(TAB_DIR, "forecast_ledger.csv")
read_ledger <- function(f) {
  if (!file.exists(f)) return(tibble())
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) %>%
    mutate(across(c(target_survey_year, year_class, data_through_survey), as.integer),
           across(c(doy_used, fit_log, lwr_log, upr_log, predictor_value, fit, lwr, upr), as.numeric))
}
ledger <- read_ledger(ledger_file)

S <- max(survey$survey_year[!is.na(survey$recruits) & !is.na(survey$pre_recruits)])
T_target <- S + 1L
commit <- tryCatch(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)[1], error = function(e) NA_character_)
env_through <- env %>% filter(!is.na(beuti_47N)) %>% summarise(y = max(year), m = max(month[year == max(year)])) %>%
  with(sprintf("%d-%02d", y, m))
tq <- function(n) qt(0.975, n - 1)

# ── Scoring of ledger rows whose target estimates now exist ─────────────────
score_rows <- function(L) {
  obs <- survey %>% transmute(beach = as.character(beach), target_survey_year = survey_year,
                              obs_pre = log(pre_recruits), obs_rec = log(recruits))
  L %>% left_join(obs, by = c("beach", "target_survey_year")) %>%
    mutate(obs_log = ifelse(target == "pre_recruits", obs_pre, obs_rec)) %>% select(-obs_pre, -obs_rec) %>%
    filter(!is.na(obs_log)) %>%
    mutate(error = fit_log - obs_log, abs_error = abs(error), covered_95 = obs_log >= lwr_log & obs_log <= upr_log,
           sd_log = (upr_log - lwr_log) / (2 * 1.96),
           crps = { z <- (obs_log - fit_log) / sd_log; sd_log * (z * (2 * pnorm(z) - 1) + 2 * dnorm(z) - 1 / sqrt(pi)) }) %>%
    group_by(beach, target_survey_year, target) %>%
    mutate(skill_vs_climatology = 1 - error^2 / error[model == "climatology"]^2) %>% ungroup()
}
if (nrow(ledger) > 0) {
  scores <- score_rows(ledger)
  write_tab(scores, "forecast_scores")
  if (nrow(scores) > 0) write_tab(scores %>% group_by(target, model) %>%
                                    summarise(n = n(), mean_abs_error = mean(abs_error), coverage_95 = mean(covered_95),
                                              mean_crps = mean(crps), mean_skill_vs_climatology = mean(skill_vs_climatology),
                                              .groups = "drop"), "forecast_scores_summary")
  message("08_forecast_protocol: scored ", nrow(scores), " ledger rows")
} else write_tab(tibble(beach = character(), target_survey_year = integer(), target = character(), model = character(),
                        obs_log = numeric(), error = numeric(), abs_error = numeric(), covered_95 = logical(),
                        crps = numeric(), skill_vs_climatology = numeric()), "forecast_scores")

# ── Issue forecasts for T, once ─────────────────────────────────────────────
already <- nrow(ledger) > 0 && any(ledger$target_survey_year == T_target)
if (already && Sys.getenv("RC_FORECAST_REISSUE", "") != "1") {
  message("08_forecast_protocol: forecasts for survey ", T_target, " already in the ledger; not reissued")
} else {
  stopifnot(all(is.na(survey$pre_recruits[survey$survey_year == T_target])))   # the target is unseen by the repository
  YC <- 1988:2024
  cat_pre <- window_catalogue(YC, last_offset = 1)
  detr <- function(x, t) { ok <- !is.na(x); out <- rep(NA_real_, length(x)); out[ok] <- resid(lm(x[ok] ~ t[ok])); out }
  idx_pre <- cohort %>% filter(!is.na(log_pre_next), !is.na(log_spawners), !is.na(doy_next)) %>%
    group_by(beach) %>% mutate(res = zs(resid(lm(log_pre_next ~ log_spawners + doy_next)))) %>%
    group_by(year_class) %>% summarise(index = mean(res), .groups = "drop")
  # exploratory choice on everything available at issue (year classes with a response)
  rows <- match(idx_pre$year_class, YC)
  y_dt <- detr(idx_pre$index, idx_pre$year_class)
  Xd <- apply(cat_pre$X[rows, , drop = FALSE], 2, detr, t = idx_pre$year_class)
  r <- suppressWarnings(cor(Xd, y_dt, use = "pairwise.complete.obs"))[, 1]
  r[colSums(!is.na(Xd)) < 15] <- NA
  j <- which.max(abs(r))
  chosen <- cat_pre$meta[j, ]
  message("08_forecast_protocol: exploratory predictor for survey ", T_target, ": ", chosen$var, ", ", chosen$window,
          " (detrended r = ", round(r[j], 2), ")")

  issue <- map_dfr(BEACHES, function(b) {
    sb <- survey %>% filter(beach == b)
    doy_T <- sb$survey_doy[sb$survey_year == T_target]
    doy_src <- if (length(doy_T) == 1 && !is.na(doy_T) && !isTRUE(sb$survey_doy_imputed[sb$survey_year == T_target])) "survey date in shell-length file" else "beach median"
    if (doy_src == "beach median") doy_T <- median(sb$survey_doy[sb$survey_year <= S], na.rm = TRUE)
    # pre-recruits of year class T-1
    d <- cohort %>% filter(beach == b, year_class <= S - 1, !is.na(log_pre_next), !is.na(log_spawners), !is.na(doy_next))
    nd <- cohort %>% filter(beach == b, year_class == S) %>% mutate(doy_next = doy_T)
    x_all <- cat_pre$X[, j]; d$x <- x_all[match(d$year_class, YC)]; nd$x <- x_all[match(S, YC)]
    clim <- d$log_pre_next; n <- length(clim)
    pi_of <- function(m, newd) { p <- predict(m, newdata = newd, interval = "prediction"); c(p[1, "fit"], p[1, "lwr"], p[1, "upr"]) }
    pre <- list(
      climatology = c(mean(clim), mean(clim) - tq(n) * sd(clim) * sqrt(1 + 1 / n), mean(clim) + tq(n) * sd(clim) * sqrt(1 + 1 / n)),
      trend = pi_of(lm(log_pre_next ~ year_class, d), nd),
      a_priori_beuti = if (!is.na(nd$beuti_larval)) pi_of(lm(log_pre_next ~ year_class + log_spawners + doy_next + beuti_larval, d %>% filter(!is.na(beuti_larval))), nd) else c(NA, NA, NA),
      exploratory_scan = if (!is.na(nd$x)) pi_of(lm(log_pre_next ~ year_class + log_spawners + doy_next + x, d %>% filter(!is.na(x))), nd) else c(NA, NA, NA))
    pre_tab <- imap_dfr(pre, ~ tibble(model = .y, fit_log = .x[1], lwr_log = .x[2], upr_log = .x[3])) %>%
      mutate(target = "pre_recruits", year_class = S,
             spec = c("beach mean of log pre-recruits", "log pre ~ year class",
                      "log pre ~ year class + log spawners + survey doy + BEUTI May-Aug Y",
                      paste0("log pre ~ year class + log spawners + survey doy + x; x = ", chosen$var, " [", chosen$window, "]")),
             predictor = c(NA, NA, "BEUTI May-Aug Y", chosen$var), window = c(NA, NA, "May Y - Aug Y", chosen$window),
             predictor_value = c(NA, NA, nd$beuti_larval, nd$x))
    # recruits at T
    s2 <- sb %>% filter(survey_year <= S) %>%
      mutate(lr = log(recruits), lp_l1 = lag(log(pre_recruits)), lr_l1 = lag(log(recruits)),
             esc_l1 = lag(log(pmax(recruits - coalesce(harvest_total, 0), 0.1 * recruits))))
    last <- sb %>% filter(survey_year == S)
    ndr <- tibble(lp_l1 = log(last$pre_recruits), lr_l1 = log(last$recruits),
                  esc_l1 = log(pmax(last$recruits - coalesce(last$harvest_total, 0), 0.1 * last$recruits)))
    clim_r <- s2$lr; nr <- length(clim_r)
    rec <- list(
      climatology = c(mean(clim_r), mean(clim_r) - tq(nr) * sd(clim_r) * sqrt(1 + 1 / nr), mean(clim_r) + tq(nr) * sd(clim_r) * sqrt(1 + 1 / nr)),
      persistence = { res <- diff(clim_r); c(last(clim_r), last(clim_r) - tq(nr - 1) * sd(res) * sqrt(1 + 1 / (nr - 1)), last(clim_r) + tq(nr - 1) * sd(res) * sqrt(1 + 1 / (nr - 1))) },
      carry_over = pi_of(lm(lr ~ lp_l1 + lr_l1, s2), ndr),
      carry_over_escapement = pi_of(lm(lr ~ lp_l1 + esc_l1, s2), ndr))
    rec_tab <- imap_dfr(rec, ~ tibble(model = .y, fit_log = .x[1], lwr_log = .x[2], upr_log = .x[3])) %>%
      mutate(target = "recruits", year_class = NA_integer_,
             spec = c("beach mean of log recruits", "log recruits at T-1 (interval from year-to-year changes)",
                      "log rec_T ~ log pre_(T-1) + log rec_(T-1)",
                      "log rec_T ~ log pre_(T-1) + log(rec_(T-1) - harvest between the surveys)"),
             predictor = c(NA, NA, "pre, rec at T-1", "pre, escapement at T-1"), window = NA_character_,
             predictor_value = c(NA, NA, NA, last$harvest_total))
    bind_rows(pre_tab, rec_tab) %>%
      mutate(beach = b, target_survey_year = T_target, doy_used = doy_T, doy_source = doy_src, .before = 1)
  }) %>%
    mutate(fit = exp(fit_log), lwr = exp(lwr_log), upr = exp(upr_log),
           issued_on = as.character(Sys.Date()), commit = commit, data_through_survey = S,
           env_through = env_through, index_vintage = INDEX_VINTAGE,
           status = ifelse(T_target <= as.integer(format(Sys.Date(), "%Y")) - 1L, "pseudo-prospective (survey already happened; estimates not in repository)", "prospective"),
           note = "issued under docs/forecast-protocol.md")
  ledger <- bind_rows(ledger, issue)
  write_csv(ledger, ledger_file)
  message("08_forecast_protocol: issued ", nrow(issue), " forecasts for survey ", T_target, " (ledger now ", nrow(ledger), " rows)")
}

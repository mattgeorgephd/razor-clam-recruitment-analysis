# ═══════════════════════════════════════════════════════════════════════════════
# 08_forecast_2025.R — archived forecasts for the 2025 stock-assessment survey
# ═══════════════════════════════════════════════════════════════════════════════
# Produces forecasts for survey year 2025 (harvest season 2025-26) from data
# through survey 2024, BEFORE the 2025 abundance estimates are added to this
# repository. When they are added, compare them with this file before
# refitting anything (task.md T15).
#
#   pre-recruits, year class 2024, survey 2025:
#     climatology      beach mean of log pre-recruits (training years)
#     beuti_model      lm(log pre ~ year class + log spawners + survey doy + BEUTI May–Aug)
#   recruits, survey 2025:
#     carryover        lm(log rec_t ~ log pre_{t-1} + log rec_{t-1})
# 95% prediction intervals on the log scale, back-transformed (median scale).
# Output: tables/forecast_2025_archived.csv (the file is not overwritten if it
# already exists, so the archived forecast stays fixed; delete it deliberately
# to regenerate).

source(here::here("01_code", "R", "00_config.R"))

out_file <- file.path(TAB_DIR, "forecast_2025_archived.csv")
if (file.exists(out_file)) {
  message("08_forecast_2025: archived forecast exists; not overwriting (", out_file, ")")
} else {
  survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE)
  cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE)
  stopifnot(!any(!is.na(survey$pre_recruits[survey$survey_year == 2025])))   # truly unseen

  fc <- map_dfr(BEACHES, function(b) {
    d  <- cohort %>% filter(beach == b, !is.na(log_pre_next), !is.na(log_spawners),
                            !is.na(doy_next), !is.na(beuti_larval))
    nd <- cohort %>% filter(beach == b, year_class == 2024)
    clim <- d$log_pre_next
    tq <- qt(0.975, length(clim) - 1) * sd(clim) * sqrt(1 + 1 / length(clim))
    m  <- lm(log_pre_next ~ year_class + log_spawners + doy_next + beuti_larval, data = d)
    pm <- predict(m, newdata = nd, interval = "prediction")

    s  <- survey %>% filter(beach == b) %>% arrange(survey_year) %>%
      mutate(lr = log(recruits), lp_l1 = lag(log(pre_recruits)), lr_l1 = lag(log(recruits)))
    mc <- lm(lr ~ lp_l1 + lr_l1, data = s %>% filter(survey_year <= 2024))
    ndc <- tibble(lp_l1 = log(s$pre_recruits[s$survey_year == 2024]),
                  lr_l1 = log(s$recruits[s$survey_year == 2024]))
    pc <- predict(mc, newdata = ndc, interval = "prediction")

    bind_rows(
      tibble(beach = b, target = "pre_recruits (year class 2024)", model = "climatology",
             fit = mean(clim), lwr = mean(clim) - tq, upr = mean(clim) + tq),
      tibble(beach = b, target = "pre_recruits (year class 2024)", model = "trend+spawners+doy+BEUTI",
             fit = pm[1, "fit"], lwr = pm[1, "lwr"], upr = pm[1, "upr"],
             beuti_2024 = nd$beuti_larval, beuti_z_vs_training = (nd$beuti_larval - mean(d$beuti_larval)) / sd(d$beuti_larval)),
      tibble(beach = b, target = "recruits", model = "carry-over: pre(2024) + rec(2024)",
             fit = pc[1, "fit"], lwr = pc[1, "lwr"], upr = pc[1, "upr"])
    )
  }) %>%
    mutate(across(c(fit, lwr, upr), exp, .names = "{.col}_millions"),
           across(ends_with("_millions"), ~ .x / 1e6),
           survey_year = 2025, created = as.character(Sys.Date()),
           note = "Archived before 2025 survey estimates were added to the repository")
  write_csv(fc, out_file)
  message("08_forecast_2025: wrote ", out_file)
}

# ═══════════════════════════════════════════════════════════════════════════════
# 04_confirmatory_models.R — pre-specified, cohort-aligned hypothesis tests
# ═══════════════════════════════════════════════════════════════════════════════
# Unit of analysis: year class Y at beach b.
# Responses:
#   log_pre_next   log pre-recruit abundance at survey Y+1 (year class Y aged ~1)
#   log_rec_next2  log recruit abundance at survey Y+2 (same year class, mostly)
# Pre-specified predictors (01_build_datasets.R §4), each z-scored over year classes:
#   beuti_larval, sst_larval, pdo_larval, q_freshet, cuti_winter
# Covariates: beach (fixed), linear year-class trend, log spawners (recruits at
#   survey Y, beach-centred), survey day-of-year at the response survey
#   (beach-centred). Shared coastwide year effects enter as a random intercept
#   for year class, so predictor effects are judged against year-to-year
#   variation (≈27 independent years), not 5 x 27 beach-years.
# Inference: likelihood-ratio tests (ML) for each predictor added singly, Holm
#   adjustment across the 5 predictors x 2 responses; Wald 95% CIs.
# Sensitivity: (i) no trend term; (ii) excluding Kalaloch; (iii) coastwide
#   index (mean of beach-standardised residuals) with GLS-AR(1); (iv) beach-
#   specific GLS-AR(1) fits for heterogeneity.
# Outputs: tables/confirmatory_*.csv, figures/fig_confirmatory_forest.png,
#          figures/fig_beach_heterogeneity.png

source(here::here("01_code", "R", "00_config.R"))
suppressPackageStartupMessages(library(lme4))

PREDICTORS <- c(beuti_larval = "BEUTI, May-Aug (Y)",
                sst_larval   = "SST anomaly, May-Sep (Y)",
                pdo_larval   = "PDO, May-Sep (Y)",
                q_freshet    = "Columbia discharge, Apr-Jun (Y)",
                cuti_winter  = "CUTI, Nov (Y)-Feb (Y+1)")
RESPONSES  <- c(log_pre_next = "Pre-recruits at survey Y+1",
                log_rec_next2 = "Recruits at survey Y+2")

survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE)
cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE) %>%
  left_join(survey %>% transmute(beach, year_class = survey_year - 2L, doy_next2 = survey_doy),
            by = c("beach", "year_class")) %>%
  mutate(beach = factor(beach, levels = BEACHES)) %>%
  group_by(beach) %>%
  mutate(spawn_c = log_spawners - mean(log_spawners, na.rm = TRUE),
         doy1_c  = doy_next  - mean(doy_next,  na.rm = TRUE),
         doy2_c  = doy_next2 - mean(doy_next2, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(trend = (year_class - 2010) / 10) %>%              # per decade
  mutate(across(all_of(names(PREDICTORS)), zs, .names = "{.col}_z"))

predictor_cor <- cohort %>% filter(beach == "Copalis", year_class %in% 1996:2023) %>%
  select(all_of(names(PREDICTORS)), year_class) %>% cor(use = "pairwise.complete.obs")
write_tab(as_tibble(predictor_cor, rownames = "var"), "confirmatory_predictor_correlations")

model_data <- function(resp, drop_kalaloch = FALSE) {
  doy <- if (resp == "log_pre_next") "doy1_c" else "doy2_c"
  d <- cohort %>%
    filter(!is.na(.data[[resp]]), !is.na(spawn_c), !is.na(.data[[doy]])) %>%
    mutate(y = .data[[resp]], doy_c = .data[[doy]], yc = factor(year_class))
  if (drop_kalaloch) d <- d %>% filter(beach != "Kalaloch") %>% mutate(beach = droplevels(beach))
  d
}

fit_one <- function(resp, pred, trend = TRUE, drop_kalaloch = FALSE) {
  d <- model_data(resp, drop_kalaloch) %>% filter(!is.na(.data[[paste0(pred, "_z")]]))
  d$x <- d[[paste0(pred, "_z")]]
  base <- if (trend) y ~ beach + trend + spawn_c + doy_c + (1 | yc) else y ~ beach + spawn_c + doy_c + (1 | yc)
  m0 <- lmer(base, data = d, REML = FALSE)
  m1 <- update(m0, . ~ . + x)
  lrt <- anova(m0, m1)
  co <- summary(m1)$coefficients["x", ]
  tibble(response = resp, predictor = pred, trend = trend, drop_kalaloch = drop_kalaloch,
         n_obs = nrow(d), n_yc = n_distinct(d$yc),
         estimate = co[["Estimate"]], se = co[["Std. Error"]],
         lo = estimate - 1.96 * se, hi = estimate + 1.96 * se,
         chisq = lrt$Chisq[2], p_lrt = lrt$`Pr(>Chisq)`[2],
         sd_year = attr(VarCorr(m1)$yc, "stddev"), sd_resid = sigma(m1),
         trend_coef = if (trend) fixef(m1)[["trend"]] else NA_real_,
         spawn_coef = fixef(m1)[["spawn_c"]], doy_coef = fixef(m1)[["doy_c"]])
}

grid <- expand_grid(response = names(RESPONSES), predictor = names(PREDICTORS),
                    trend = c(TRUE, FALSE), drop_kalaloch = c(FALSE, TRUE)) %>%
  filter(!(trend == FALSE & drop_kalaloch == TRUE))
res <- pmap_dfr(grid, function(response, predictor, trend, drop_kalaloch)
  fit_one(response, predictor, trend, drop_kalaloch))

res <- res %>%
  group_by(trend, drop_kalaloch) %>%
  mutate(p_holm = p.adjust(p_lrt, "holm"), p_bh = p.adjust(p_lrt, "BH")) %>%
  ungroup() %>%
  mutate(analysis = case_when(trend & !drop_kalaloch ~ "Primary (trend + spawners + survey date)",
                              !trend ~ "No trend term",
                              drop_kalaloch ~ "Primary, excluding Kalaloch"))
write_tab(res, "confirmatory_pooled")

# Full model with all five predictors (primary specification)
full_fit <- map_dfr(names(RESPONSES), function(resp) {
  d <- model_data(resp) %>% drop_na(ends_with("_z"))
  f <- as.formula(paste("y ~ beach + trend + spawn_c + doy_c +",
                        paste0(names(PREDICTORS), "_z", collapse = " + "), "+ (1 | yc)"))
  m <- lmer(f, data = d, REML = TRUE)
  co <- summary(m)$coefficients
  as_tibble(co, rownames = "term") %>% mutate(response = resp, n_obs = nrow(d), n_yc = n_distinct(d$yc))
})
write_tab(full_fit, "confirmatory_full_model")

# ── Coastwide index (sensitivity iii) ───────────────────────────────────────
# Within each beach, regress the response on spawners + survey date, take
# standardised residuals, average across beaches per year class, then fit
# GLS with AR(1) errors: index ~ trend + predictor.
coast <- map_dfr(names(RESPONSES), function(resp) {
  d <- model_data(resp) %>%
    group_by(beach) %>%
    mutate(res = zs(resid(lm(y ~ spawn_c + doy_c)))) %>%
    ungroup() %>%
    group_by(year_class) %>%
    summarise(index = mean(res), n_beach = n(), across(ends_with("_z"), mean), .groups = "drop") %>%
    mutate(trend = (year_class - 2010) / 10)
  map_dfr(names(PREDICTORS), function(pred) {
    dd <- d %>% transmute(year_class, index, trend, x = .data[[paste0(pred, "_z")]]) %>% drop_na()
    f <- tryCatch(gls(index ~ trend + x, data = dd, correlation = corAR1(form = ~ year_class), method = "REML"),
                  error = function(e) gls(index ~ trend + x, data = dd, method = "REML"))
    tt <- summary(f)$tTable
    tibble(response = resp, predictor = pred, n_yc = nrow(dd),
           estimate = tt["x", 1], se = tt["x", 2], p = tt["x", 4],
           phi = tryCatch(coef(f$modelStruct$corStruct, unconstrained = FALSE), error = function(e) NA_real_))
  })
}) %>% mutate(p_holm = p.adjust(p, "holm"))
write_tab(coast, "confirmatory_coastwide_index")

# ── Robustness of the BEUTI result (sensitivity v) ──────────────────────────
# Coastwide pre-recruit index (as above) vs BEUTI May–Aug at 47N (and CUTI as a
# transport-only analogue) under alternative ways of removing low-frequency
# variation, leave-one-year-out, and with the most influential year removed.
idx_pre <- model_data("log_pre_next") %>%
  group_by(beach) %>% mutate(res = zs(resid(lm(y ~ spawn_c + doy_c)))) %>% ungroup() %>%
  group_by(year_class) %>% summarise(index = mean(res), .groups = "drop")
env_m <- read_csv(file.path(DERIVED, "env_monthly.csv"), show_col_types = FALSE)
ann <- env_m %>% filter(month %in% 5:8) %>% group_by(year) %>%
  summarise(beuti = mean(beuti_47N), cuti = mean(cuti_47N), .groups = "drop")
rb <- idx_pre %>% left_join(ann, by = c("year_class" = "year")) %>% drop_na() %>% arrange(year_class)

rob_one <- function(d, var) {
  x <- zs(d[[var]]); y <- d$index; t <- d$year_class
  lin <- summary(lm(y ~ t + x))$coefficients["x", ]
  lo_x <- resid(loess(x ~ t, span = 0.75)); lo_y <- resid(loess(y ~ t, span = 0.75))
  ct_lo <- cor.test(lo_x, lo_y)
  fd <- summary(lm(diff(y) ~ diff(x)))$coefficients[2, ]
  loo <- sapply(seq_len(nrow(d)), function(i) coef(lm(y[-i] ~ t[-i] + x[-i]))[3])
  infl <- d$year_class[which.max(abs(loo - lin[1]))]
  ex <- d %>% filter(year_class != infl)
  exc <- summary(lm(index ~ year_class + zs(ex[[var]]), data = ex))$coefficients[3, ]
  tibble(variable = var, n = nrow(d),
         linear_detrend_est = lin[[1]], linear_detrend_p = lin[[4]],
         loess_detrend_r = unname(ct_lo$estimate), loess_detrend_p = ct_lo$p.value,
         first_diff_est = fd[[1]], first_diff_p = fd[[4]],
         loo_min = min(loo), loo_max = max(loo), loo_all_negative = all(loo < 0),
         most_influential_year = infl, without_influential_est = exc[[1]], without_influential_p = exc[[4]],
         post2003_est = summary(lm(index ~ year_class + zs(get(var)), data = filter(d, year_class >= 2003)))$coefficients[3, 1],
         post2003_p = summary(lm(index ~ year_class + zs(get(var)), data = filter(d, year_class >= 2003)))$coefficients[3, 4])
}
write_tab(bind_rows(rob_one(rb, "beuti"), rob_one(rb, "cuti")), "confirmatory_beuti_robustness")

# ── Beach-specific GLS-AR(1) (sensitivity iv) ───────────────────────────────
by_beach <- map_dfr(names(RESPONSES), function(resp) {
  d <- model_data(resp)
  map_dfr(BEACHES, function(b) map_dfr(names(PREDICTORS), function(pred) {
    dd <- d %>% filter(beach == b) %>% transmute(year_class, y, trend, spawn_c, doy_c,
                                                 x = .data[[paste0(pred, "_z")]]) %>% drop_na()
    f <- tryCatch(gls(y ~ trend + spawn_c + doy_c + x, data = dd,
                      correlation = corAR1(form = ~ year_class), method = "REML"),
                  error = function(e) gls(y ~ trend + spawn_c + doy_c + x, data = dd, method = "REML"))
    tt <- summary(f)$tTable
    tibble(response = resp, beach = b, predictor = pred, n = nrow(dd),
           estimate = tt["x", 1], se = tt["x", 2], p = tt["x", 4])
  }))
}) %>% mutate(q_bh = p.adjust(p, "BH"))
write_tab(by_beach, "confirmatory_by_beach")

# ── Figures ─────────────────────────────────────────────────────────────────
p_forest <- res %>%
  mutate(predictor = factor(PREDICTORS[predictor], levels = rev(PREDICTORS)),
         response = factor(RESPONSES[response], levels = RESPONSES),
         analysis = factor(analysis, levels = c("Primary (trend + spawners + survey date)",
                                                "Primary, excluding Kalaloch", "No trend term"))) %>%
  ggplot(aes(estimate, predictor, colour = analysis)) +
  geom_vline(xintercept = 0, linetype = 2) +
  geom_pointrange(aes(xmin = lo, xmax = hi), position = position_dodge(width = 0.6), size = 0.3) +
  facet_wrap(~ response) +
  scale_colour_manual(values = c("black", "grey55", "#D55E00"), name = NULL) +
  labs(x = "Effect on log abundance per 1 SD of predictor (95% CI)", y = NULL,
       title = "Pre-specified, cohort-aligned predictors of year-class strength",
       subtitle = "Pooled mixed models across beaches with a random year-class effect") +
  theme_ms(10) + guides(colour = guide_legend(nrow = 2))
save_fig(p_forest, "fig_confirmatory_forest", 9, 4.8)

p_het <- by_beach %>%
  mutate(predictor = factor(PREDICTORS[predictor], levels = rev(PREDICTORS)),
         response = factor(RESPONSES[response], levels = RESPONSES),
         beach = factor(beach, levels = BEACHES)) %>%
  ggplot(aes(estimate, predictor, colour = beach)) +
  geom_vline(xintercept = 0, linetype = 2) +
  geom_pointrange(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se),
                  position = position_dodge(width = 0.7), size = 0.2) +
  facet_wrap(~ response) +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  labs(x = "Effect per 1 SD (95% CI), beach-specific GLS-AR(1)", y = NULL,
       title = "Beach-level heterogeneity of cohort-aligned effects") +
  theme_ms(10)
save_fig(p_het, "fig_beach_heterogeneity", 9, 5)

message("04_confirmatory_models: done")

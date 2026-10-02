# ═══════════════════════════════════════════════════════════════════════════════
# 02_cohort_diagnostics.R — what does a "pre-recruit" represent, and when?
# ═══════════════════════════════════════════════════════════════════════════════
# Establishes empirically (rather than from an assumed growth model):
#   (a) survey timing by beach and year (it differs by ~2 months among beaches
#       and drifts at some beaches);
#   (b) length-frequency structure relative to survey date (current-year
#       settlers are only visible at late surveys);
#   (c) cohort linkage: pre-recruits at survey t predict recruits at t+1;
#   (d) cross-beach synchrony and long-term trends;
#   (f) the WDFW mark-recapture growth curve (Cheng and Ayres 2008 draft; K
#       and L-infinity only, since the design cannot locate the curve on the
#       age axis) placed on the age axis with the survey length modes.
# Outputs: figures/fig_survey_timing.png, fig_length_frequency.png,
#          fig_cohort_linkage.png, fig_growth_curve_check.png;
#          tables/cohort_linkage.csv, synchrony_*.csv, trends.csv,
#          growth_model_check.csv, growth_model_check_by_year.csv

source(here::here("01_code", "R", "00_config.R"))

survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE) %>%
  mutate(beach = factor(beach, levels = BEACHES))
cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE) %>%
  mutate(beach = factor(beach, levels = BEACHES))

# ── (a) Survey timing ───────────────────────────────────────────────────────
timing_trend <- survey %>%
  filter(!is.na(survey_doy), !survey_doy_imputed) %>%
  group_by(beach) %>%
  group_modify(~ {
    f <- lm(survey_doy ~ survey_year, data = .x)
    tibble(median_doy = median(.x$survey_doy), sd_doy = sd(.x$survey_doy),
           slope_days_per_yr = coef(f)[2], p = summary(f)$coefficients[2, 4],
           n_years = nrow(.x))
  }) %>% ungroup()
write_tab(timing_trend, "survey_timing_by_beach")

p_timing <- survey %>%
  filter(!is.na(survey_doy)) %>%
  ggplot(aes(survey_year, as.Date(survey_doy - 1, origin = "2001-01-01"), colour = beach)) +
  geom_line() + geom_point(aes(shape = survey_doy_imputed), size = 1.8) +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 4), labels = c("observed", "imputed"), name = NULL) +
  scale_y_date(date_labels = "%d %b", date_breaks = "2 weeks") +
  labs(x = "Survey year", y = "Median survey date", colour = NULL,
       title = "Stock-assessment survey timing differs by beach and drifts over time") +
  theme_ms()
save_fig(p_timing, "fig_survey_timing", 8, 5)

# ── (b) Length-frequency by survey timing ───────────────────────────────────
sl <- read_excel(file.path(DATA_DIR, "shell_length_data-summary",
                           "All_Beaches_shell_lengths_1997-2025.xlsx"),
                 sheet = "All_Clams_Raw", col_types = "text") %>%
  transmute(beach = factor(beach, levels = BEACHES),
            survey_year = as.integer(survey_year),
            length_mm = as.numeric(length_mm)) %>%
  left_join(survey %>% select(beach, survey_year, survey_doy), by = c("beach", "survey_year")) %>%
  mutate(timing = cut(survey_doy, c(0, 166, 196, 366),
                      labels = c("before 15 Jun", "15 Jun - 15 Jul", "after 15 Jul")))

p_lf <- sl %>%
  filter(!is.na(timing)) %>%
  ggplot(aes(length_mm, after_stat(density), fill = timing)) +
  geom_histogram(binwidth = 3, boundary = 0, colour = NA) +
  geom_vline(xintercept = 75.5, linetype = 2) +
  facet_grid(timing ~ beach) +
  scale_fill_brewer(palette = "Dark2", guide = "none") +
  labs(x = "Shell length (mm)", y = "Density",
       title = "Length-frequency by beach and survey timing",
       subtitle = paste0("Dashed line = 76 mm recruit boundary. A distinct <=20 mm current-year settler mode appears only in surveys after mid-July;\n",
                         "15-40 mm clams at June surveys are survivors of the previous summer's settlement.")) +
  theme_ms(10)
save_fig(p_lf, "fig_length_frequency", 11, 6.5)

lt30_by_timing <- sl %>% filter(!is.na(timing), length_mm <= PRE_RECRUIT_MAX_MM) %>%
  group_by(timing) %>% summarise(n = n(), share_pre_lt20mm = mean(length_mm < 20),
            share_pre_lt30mm = mean(length_mm < 30), .groups = "drop")
write_tab(lt30_by_timing, "prerecruit_lt30_share_by_timing")

# ── (c) Cohort linkage ──────────────────────────────────────────────────────
link <- survey %>%
  arrange(beach, survey_year) %>%
  group_by(beach) %>%
  mutate(lp = log(pre_recruits), lr = log(recruits),
         lr_next = lead(lr), lp_next = lead(lp)) %>%
  summarise(
    r_pre_t_rec_t1 = cor(lp, lr_next, use = "complete.obs"),
    p_pre_t_rec_t1 = cor.test(lp, lr_next)$p.value,
    r_pre_t_rec_t  = cor(lp, lr, use = "complete.obs"),
    r_rec_t_rec_t1 = cor(lr, lr_next, use = "complete.obs"),
    r_pre_t_pre_t1 = cor(lp, lp_next, use = "complete.obs"),
    n = sum(!is.na(lp) & !is.na(lr_next)),
    .groups = "drop")
write_tab(link, "cohort_linkage")

p_link <- survey %>% arrange(beach, survey_year) %>% group_by(beach) %>%
  mutate(lr_next = lead(log(recruits))) %>% ungroup() %>%
  ggplot(aes(log(pre_recruits), lr_next)) +
  geom_point(alpha = .7) + geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = "black") +
  facet_wrap(~ beach, nrow = 1, scales = "free") +
  labs(x = "log pre-recruits, survey t", y = "log recruits, survey t+1",
       title = "Pre-recruits in year t become recruits in year t+1 (except Twin Harbors)") +
  theme_ms(10)
save_fig(p_link, "fig_cohort_linkage", 11, 3.4)

# ── (d) Synchrony and trends ────────────────────────────────────────────────
sync <- function(var, detrend = FALSE) {
  survey %>% select(beach, survey_year, v = all_of(var)) %>%
    filter(!is.na(v)) %>% mutate(v = log(v)) %>%
    group_by(beach) %>%
    mutate(v = if (detrend) resid(lm(v ~ survey_year)) else v) %>% ungroup() %>%
    pivot_wider(names_from = beach, values_from = v) %>%
    select(-survey_year) %>% cor(use = "pairwise.complete.obs") %>%
    as.data.frame() %>% rownames_to_column("beach")
}
write_tab(sync("pre_recruits"), "synchrony_prerecruits")
write_tab(sync("recruits"), "synchrony_recruits")

gls_trend <- function(y, t) {
  d <- tibble(y = y, t = t) %>% filter(!is.na(y))
  f <- tryCatch(gls(y ~ t, data = d, correlation = corAR1(form = ~ t), method = "ML"),
                error = function(e) gls(y ~ t, data = d, method = "ML"))
  s <- summary(f)$tTable
  tibble(slope_per_yr = s[2, 1], se = s[2, 2], p = s[2, 4],
         phi = tryCatch(coef(f$modelStruct$corStruct, unconstrained = FALSE), error = function(e) NA_real_))
}
trends_clam <- survey %>% filter(!is.na(pre_recruits)) %>%
  pivot_longer(c(pre_recruits, recruits), names_to = "series") %>%
  group_by(beach, series) %>%
  group_modify(~ gls_trend(log(.x$value), .x$survey_year)) %>% ungroup()
trends_env <- cohort %>% filter(beach %in% c("Copalis", "Long Beach"), year_class %in% 1996:2023) %>%
  pivot_longer(beuti_larval:cuti_winter, names_to = "series") %>%
  group_by(beach, series) %>%
  group_modify(~ gls_trend(.x$value, .x$year_class)) %>% ungroup()
write_tab(bind_rows(trends_clam, trends_env), "trends")

# ── (e) Descriptive summary of abundance ────────────────────────────────────
abund_summary <- survey %>% filter(!is.na(pre_recruits)) %>%
  pivot_longer(c(pre_recruits, recruits), names_to = "series") %>%
  group_by(beach, series) %>%
  summarise(n_years = n(), first = min(survey_year), last = max(survey_year),
            median_millions = median(value) / 1e6, min_millions = min(value) / 1e6,
            max_millions = max(value) / 1e6, max_min_ratio = max(value) / min(value),
            sd_log = sd(log(value)), .groups = "drop")
write_tab(abund_summary, "abundance_summary")

sync_summary <- map_dfr(c("pre_recruits", "recruits"), function(v) map_dfr(c(FALSE, TRUE), function(dt) {
  m <- sync(v, detrend = dt) %>% select(-beach) %>% as.matrix()
  rownames(m) <- colnames(m)
  south <- c("Mocrocks", "Copalis", "Twin Harbors", "Long Beach")
  tibble(series = v, detrended = dt,
         mean_r_all = mean(m[lower.tri(m)]),
         mean_r_excl_kalaloch = mean(m[south, south][lower.tri(m[south, south])]),
         mean_r_kalaloch_vs_others = mean(m["Kalaloch", south]))
}))
write_tab(sync_summary, "synchrony_summary")

# ── (f) Growth curve from the WDFW mark-recapture draft, placed on the age axis ──
# Cheng and Ayres (2008, unpublished WDFW draft; method of Cheng and Kuk 2002,
# Biometrics 58:459-462) fitted von Bertalanffy curves to 2006-2007 recaptures:
# Copalis L-inf 143.17 mm, K 1.00/yr; Long Beach 141.67 mm, 0.98/yr. Increments
# identify K and L-inf but not t0, so the curve's age scale is arbitrary (the
# legacy notebook took t0 = 0 and labelled pre-recruits "young-of-year"). The
# year-old cohort (year class Y-1) is the dominant group below 76 mm at every
# survey, and the beaches are surveyed on different dates, so its length
# against survey date locates the curve. Two identifications are used, because
# the answer depends on it: (i) the kernel-density mode of 15-72 mm lengths,
# which can land on a secondary group of 20-30 mm clams; (ii) the mean of the
# year-old component of a 3- or 4-component normal mixture over the whole
# length range (settlers, year-old, two-year-old, older), which can merge the
# year-old cohort with slow two-year-olds in strong years. Settlement is taken
# as 1 August (DOY 213) of the previous year; t0 shifts one-for-one with that.
# See docs/growth-model-review.md.
VB <- tibble(beach = BEACHES, Linf = c(143.17, 143.17, 143.17, 141.67, 141.67), K = c(1, 1, 1, 0.98, 0.98),
             source = c("Copalis (proxy)", "Copalis (proxy)", "Copalis (study)", "Long Beach (proxy)", "Long Beach (study)"))
SETTLE_DOY <- 213
age_at <- function(L, Linf, K, t0) t0 - log(1 - L / Linf) / K
len_at <- function(t, Linf, K, t0) Linf * (1 - exp(-K * (t - t0)))

emk <- function(x, mu, sd, w, iter = 300) {   # normal mixture by EM, SDs floored at 2 mm
  for (i in seq_len(iter)) {
    dens <- sapply(seq_along(mu), function(k) w[k] * dnorm(x, mu[k], sd[k])); dens[dens == 0] <- 1e-300
    r <- dens / rowSums(dens); nk <- colSums(r)
    w <- nk / length(x); mu <- colSums(r * x) / nk
    sd <- pmax(sqrt(colSums(r * (x - rep(mu, each = length(x)))^2) / nk), 2)
  }
  ll <- sum(log(rowSums(sapply(seq_along(mu), function(k) w[k] * dnorm(x, mu[k], sd[k])))))
  list(mu = mu, sd = sd, w = w, bic = -2 * ll + (3 * length(mu) - 1) * log(length(x)))
}
year_old_component <- function(x) {
  f3 <- emk(x, mu = c(45, 100, 125), sd = c(10, 10, 8), w = c(.3, .4, .3))
  f4 <- emk(x, mu = c(22, 50, 100, 125), sd = c(5, 10, 10, 8), w = c(.1, .3, .3, .3))
  best <- if (f4$bic < f3$bic - 10) f4 else f3          # a 4th (settler) component only when BIC clearly prefers it
  cand <- which(best$mu > 25 & best$mu < 80)
  if (length(best$mu) == 4 && length(cand) > 1) cand <- cand[cand != which.min(best$mu)]
  if (length(cand) == 0) return(tibble(k = length(best$mu), mix_mu1 = NA_real_, mix_sd1 = NA_real_, mix_w1 = NA_real_,
                                       mix_mu_settler = NA_real_, mix_w_settler = NA_real_))
  j <- cand[which.max(best$w[cand])]
  tibble(k = length(best$mu), mix_mu1 = best$mu[j], mix_sd1 = best$sd[j], mix_w1 = best$w[j],
         mix_mu_settler = if (length(best$mu) == 4) best$mu[1] else NA_real_,
         mix_w_settler = if (length(best$mu) == 4) best$w[1] else NA_real_)
}
sl_g <- sl %>% filter(!is.na(survey_doy), length_mm >= 8, length_mm <= 145)
by_year <- sl_g %>% group_by(beach, survey_year, survey_doy) %>% filter(n() >= 150) %>%
  group_modify(~ {
    x <- .x$length_mm
    xm <- x[x >= 15 & x <= 72 & !(.y$survey_doy > 196 & x <= 20)]
    bind_cols(tibble(n = length(x),
                     mode_mm = if (length(xm) >= 100) { k <- density(xm, bw = 3, from = 15, to = 72); k$x[which.max(k$y)] } else NA_real_),
              year_old_component(x))
  }) %>% ungroup() %>%
  left_join(VB, by = "beach") %>%
  mutate(age_assumed_yr = 1 + (survey_doy - SETTLE_DOY) / 365.25,
         t0_mode = age_assumed_yr + log(1 - mode_mm / Linf) / K,
         t0_mixture = age_assumed_yr + log(1 - mix_mu1 / Linf) / K,
         year_old_partly_above_76mm = !is.na(mix_mu1) & mix_mu1 + mix_sd1 > 76)
write_tab(by_year, "growth_model_check_by_year")
t0_mode_hat <- mean(by_year$t0_mode, na.rm = TRUE); t0_mix_hat <- mean(by_year$t0_mixture, na.rm = TRUE)
growth_check <- by_year %>% group_by(beach) %>%
  summarise(n_beach_years = n(), median_survey_doy = median(survey_doy),
            median_mode_mm = median(mode_mm, na.rm = TRUE), median_mixture_mean_mm = median(mix_mu1, na.rm = TRUE),
            share_with_settler_component = mean(k == 4), median_settler_mm = median(mix_mu_settler, na.rm = TRUE),
            share_year_old_partly_above_76mm = mean(year_old_partly_above_76mm),
            t0_mode_mean = mean(t0_mode, na.rm = TRUE), t0_mode_sd = sd(t0_mode, na.rm = TRUE),
            t0_mixture_mean = mean(t0_mixture, na.rm = TRUE), t0_mixture_sd = sd(t0_mixture, na.rm = TRUE),
            Linf = first(Linf), K = first(K), .groups = "drop") %>%
  bind_rows(tibble(beach = "All beaches", n_beach_years = nrow(by_year),
                   t0_mode_mean = t0_mode_hat, t0_mode_sd = sd(by_year$t0_mode, na.rm = TRUE),
                   t0_mixture_mean = t0_mix_hat, t0_mixture_sd = sd(by_year$t0_mixture, na.rm = TRUE),
                   share_with_settler_component = mean(by_year$k == 4),
                   share_year_old_partly_above_76mm = mean(by_year$year_old_partly_above_76mm),
                   Linf = 143.17, K = 1)) %>%
  mutate(age_at_76mm_t0_zero = age_at(76, Linf, K, 0),
         age_at_76mm_t0_mode = age_at(76, Linf, K, t0_mode_hat), age_at_76mm_t0_mixture = age_at(76, Linf, K, t0_mix_hat),
         expected_mm_1Jun_Y1_range = sprintf("%.0f-%.0f", len_at(1 + (152 - SETTLE_DOY) / 365.25, Linf, K, t0_mode_hat), len_at(1 + (152 - SETTLE_DOY) / 365.25, Linf, K, t0_mix_hat)),
         expected_mm_1Sep_Y1_range = sprintf("%.0f-%.0f", len_at(1 + (244 - SETTLE_DOY) / 365.25, Linf, K, t0_mode_hat), len_at(1 + (244 - SETTLE_DOY) / 365.25, Linf, K, t0_mix_hat)),
         expected_mm_1Jun_Y2_range = sprintf("%.0f-%.0f", len_at(2 + (152 - SETTLE_DOY) / 365.25, Linf, K, t0_mode_hat), len_at(2 + (152 - SETTLE_DOY) / 365.25, Linf, K, t0_mix_hat)),
         mixture_mean_vs_doy_mm_per_day = coef(lm(mix_mu1 ~ survey_doy, by_year))[2],
         settlement_doy_assumed = SETTLE_DOY)
write_tab(growth_check, "growth_model_check")

curves <- VB %>% filter(beach == "Copalis") %>% crossing(doy = seq(110, 245, 5)) %>%
  mutate(age = 1 + (doy - SETTLE_DOY) / 365.25,
         `t0 = 0 (legacy notebook)` = len_at(age, Linf, K, 0),
         `t0 from the kernel modes` = len_at(age, Linf, K, t0_mode_hat),
         `t0 from the mixture components` = len_at(age, Linf, K, t0_mix_hat)) %>%
  pivot_longer(starts_with("t0"), names_to = "curve", values_to = "length_mm")
pts <- by_year %>% select(beach, survey_doy, `kernel mode, 15-72 mm` = mode_mm, `mixture: year-old component` = mix_mu1,
                          `mixture: settler component` = mix_mu_settler) %>%
  pivot_longer(-c(beach, survey_doy), names_to = "estimate", values_to = "length_mm") %>% filter(!is.na(length_mm))
p_growth <- ggplot() +
  geom_hline(yintercept = 75.5, linetype = 2, colour = "grey40") +
  geom_point(data = pts, aes(survey_doy, length_mm, colour = estimate, shape = beach), size = 1.7, alpha = 0.75) +
  geom_line(data = curves, aes(doy, length_mm, linetype = curve), colour = "black") +
  scale_colour_manual(values = c("#0072B2", "#999999", "#D55E00"), name = NULL) +
  scale_linetype_manual(values = c(3, 1, 2), name = NULL) +
  scale_shape_manual(values = c(16, 17, 15, 3, 4), name = NULL) +
  scale_x_continuous(breaks = c(121, 152, 182, 213, 244), labels = c("1 May", "1 Jun", "1 Jul", "1 Aug", "1 Sep")) +
  labs(x = "Survey date (year after settlement)", y = "Shell length (mm)",
       title = "The year-old cohort by survey date, against the WDFW growth curve (Copalis parameters)",
       subtitle = sprintf("Points per beach-year: kernel mode (15-72 mm) and mixture components. Curves: t0 = 0, %.2f yr (modes), %.2f yr (mixture).",
                          t0_mode_hat, t0_mix_hat)) +
  theme_ms(9) + theme(legend.box = "vertical", legend.spacing.y = unit(0, "pt")) +
  guides(colour = guide_legend(order = 1, nrow = 1), linetype = guide_legend(order = 2, nrow = 1), shape = guide_legend(order = 3, nrow = 1))
save_fig(p_growth, "fig_growth_curve_check", 10, 7)
message("02 (f): implied t0 = ", round(t0_mode_hat, 2), " yr (kernel modes) / ", round(t0_mix_hat, 2), " yr (mixture) over ", nrow(by_year), " beach-years")

message("02_cohort_diagnostics: done")

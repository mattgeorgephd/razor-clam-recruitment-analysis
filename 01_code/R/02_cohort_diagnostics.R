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
#       age axis) placed on the age axis with the survey length modes;
#   (g) the year classes separated from the lengths by 01b_cohort_separation.R:
#       why 76 mm is not a cohort boundary (length groups tracked across
#       surveys), where the fitted boundaries fall, how much of each size
#       class belongs to another year class, and whether the length-based
#       year classes link better across surveys than the size classes.
# Outputs: figures/fig_survey_timing.png, fig_length_frequency.png,
#          fig_cohort_linkage.png, fig_growth_curve_check.png,
#          fig_cohort_separation.png, fig_cohort_mixture_examples.png,
#          fig_cohort_linkage_lengthbased.png, fig_yearclass_abundance.png;
#          tables/cohort_linkage.csv, synchrony_*.csv, trends.csv,
#          growth_model_check.csv, growth_model_check_by_year.csv,
#          cohort_length_transitions.csv, cohort_length_transitions_by_beach.csv,
#          cohort_separation_summary.csv

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
sl <- read_lengths() %>%
  transmute(beach = factor(beach, levels = BEACHES), survey_year, length_mm) %>%
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
         consecutive = lead(survey_year) == survey_year + 1,   # every beach is surveyed yearly; guard for future gaps
         lr_next = ifelse(consecutive, lead(lr), NA_real_), lp_next = ifelse(consecutive, lead(lp), NA_real_)) %>%
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

# habitat area used to expand density to abundance changes in steps (task T19)
habitat_changes <- survey %>% filter(!is.na(habitat_m2)) %>% arrange(beach, survey_year) %>% group_by(beach) %>%
  summarise(n_distinct_values = n_distinct(habitat_m2), min_m2 = min(habitat_m2), max_m2 = max(habitat_m2),
            max_over_min = max(habitat_m2) / min(habitat_m2),
            change_years = paste(survey_year[which(habitat_m2 != lag(habitat_m2))], collapse = ", "), .groups = "drop")
write_tab(habitat_changes, "habitat_area_changes")

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
# VB_LINF, VB_K and SETTLE_DOY come from 00_config.R; t0 is estimated here and
# VB_T0 there records the adopted value (0.45 yr), which lib_cohort_mixture.R uses.
VB <- tibble(beach = BEACHES, Linf = unname(VB_LINF[BEACHES]), K = unname(VB_K[BEACHES]),
             source = c("Copalis (proxy)", "Copalis (proxy)", "Copalis (study)", "Long Beach (proxy)", "Long Beach (study)"))
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

# ── (g) Year classes from the lengths (task T14) ────────────────────────────
# 01b_cohort_separation.R fitted a growth-curve-informed length mixture to every
# beach-year (lib_cohort_mixture.R) and applied its cohort shares to the
# abundance estimates (02_data/derived/cohort_lengths.csv). This section shows
# (i) why 76 mm is not a cohort boundary: log numbers in five length groups are
# tracked across consecutive surveys of the same beach, and a group that belongs
# to the same year class as another covaries with it in the SAME survey and
# reappears one group up a year later; (ii) whether the length-based year
# classes link across surveys better than the size classes; (iii) where the
# fitted boundaries fall and how much of each size class belongs to another year
# class; (iv) example fits, so the mixture can be judged by eye.
cl_file <- file.path(DERIVED, "cohort_lengths.csv")
if (!file.exists(cl_file)) {
  message("02 (g): ", cl_file, " not found; run 01b_cohort_separation.R first (section skipped)")
} else {
source(here::here("01_code", "R", "lib_cohort_mixture.R"))
cl <- read_csv(cl_file, show_col_types = FALSE) %>% mutate(beach = factor(beach, levels = BEACHES))

# (i) length-group transitions. Numbers per group = share of the measured clams
# x total abundance, floored at 1,000 clams, logged, standardised within beach.
# Beaches are pooled by survey timing because a length group means a different
# age at a June survey than at an August survey.
LGROUPS <- c("5-24", "25-75", "76-95", "96-125", "126+")
lg <- sl %>% filter(!is.na(length_mm), length_mm >= 5) %>%
  inner_join(survey %>% select(beach, survey_year, pre_recruits, recruits), by = c("beach", "survey_year")) %>%
  filter(!is.na(pre_recruits)) %>%
  group_by(beach, survey_year) %>% filter(n() >= 150) %>%
  summarise(N = first(pre_recruits) + first(recruits),
            `5-24` = mean(length_mm < 25), `25-75` = mean(length_mm >= 25 & length_mm <= 75),
            `76-95` = mean(length_mm >= 76 & length_mm <= 95), `96-125` = mean(length_mm >= 96 & length_mm <= 125),
            `126+` = mean(length_mm > 125), .groups = "drop") %>%
  mutate(across(all_of(LGROUPS), ~ log(pmax(.x * N, 1000)))) %>%
  arrange(beach, survey_year) %>%
  group_by(beach) %>%
  mutate(across(all_of(LGROUPS), list(lag1 = ~ ifelse(lag(survey_year) == survey_year - 1, lag(.x), NA_real_),
                                      lag2 = ~ ifelse(lag(survey_year, 2) == survey_year - 2, lag(.x, 2), NA_real_)))) %>%
  mutate(across(-c(survey_year, N), ~ as.numeric(scale(.x)))) %>% ungroup()
BEACH_SETS <- list(`June-July surveys (Copalis, Long Beach, Mocrocks)` = c("Copalis", "Long Beach", "Mocrocks"),
                   `Late surveys (Twin Harbors, Kalaloch)` = c("Twin Harbors", "Kalaloch"),
                   `All beaches` = BEACHES)
lag_col <- function(g, lag) if (lag == 0) g else paste0(g, "_lag", lag)
trans <- map_dfr(names(BEACH_SETS), function(set) {
  d <- lg %>% filter(beach %in% BEACH_SETS[[set]])
  expand_grid(group_t = LGROUPS, lag_years = 0:2, group_lagged = LGROUPS) %>%
    mutate(col = map2_chr(group_lagged, lag_years, lag_col),
           r = map2_dbl(group_t, col, ~ cor(d[[.x]], d[[.y]], use = "complete.obs")),
           n = map2_int(group_t, col, ~ sum(!is.na(d[[.x]]) & !is.na(d[[.y]]))),
           beach_set = set)
})
trans_wide <- trans %>%
  mutate(column = paste0(ifelse(lag_years == 0, "same_survey", paste0("survey_t_minus_", lag_years)), "__", group_lagged)) %>%
  group_by(beach_set, group_t) %>%
  mutate(n_min = min(n), n_max = max(n)) %>% ungroup() %>%
  select(beach_set, group_t, n_min, n_max, column, r) %>%
  pivot_wider(names_from = column, values_from = r) %>%
  mutate(beach_set = factor(beach_set, names(BEACH_SETS)), group_t = factor(group_t, LGROUPS)) %>%
  arrange(beach_set, group_t) %>% mutate(across(c(beach_set, group_t), as.character))
write_tab(trans_wide, "cohort_length_transitions")
trans_beach <- lg %>% group_by(beach) %>%
  summarise(n = n(),
            r_76_95_vs_25_75_same_survey = cor(`76-95`, `25-75`),
            r_76_95_vs_25_75_prev_survey = cor(`76-95`, `25-75_lag1`, use = "complete.obs"),
            r_76_95_vs_76_95_prev_survey = cor(`76-95`, `76-95_lag1`, use = "complete.obs"),
            r_96_125_vs_25_75_prev_survey = cor(`96-125`, `25-75_lag1`, use = "complete.obs"),
            r_96_125_vs_76_95_prev_survey = cor(`96-125`, `76-95_lag1`, use = "complete.obs"),
            r_126plus_vs_25_75_two_surveys_before = cor(`126+`, `25-75_lag2`, use = "complete.obs"),
            r_126plus_vs_96_125_prev_survey = cor(`126+`, `96-125_lag1`, use = "complete.obs"),
            .groups = "drop")
write_tab(trans_beach, "cohort_length_transitions_by_beach")

# (i b) annual growth increments from the same tracking, as an independent check
# of the growth curve: for each 10 mm source bin at survey t-1, the bin at t (at
# or above it) whose log numbers it predicts best; the distance between them is
# the modal increment over one year. K is then fitted with L-inf fixed at the
# WDFW value (r-weighted mean of 1 - exp(-K) over bins with r >= 0.4), and both
# parameters freely. This is what justifies MIX_K / MIX_T0 in 00_config.R.
edges <- seq(20, 140, 10); bins10 <- paste0(edges); mids <- edges + 5
lg10 <- sl %>% filter(!is.na(length_mm), length_mm >= 20) %>%
  inner_join(survey %>% select(beach, survey_year, pre_recruits, recruits), by = c("beach", "survey_year")) %>%
  filter(!is.na(pre_recruits)) %>% group_by(beach, survey_year) %>% filter(n() >= 150) %>%
  mutate(N = first(pre_recruits) + first(recruits), bin = cut(length_mm, c(edges, 200), right = FALSE, labels = bins10)) %>%
  filter(!is.na(bin)) %>% group_by(beach, survey_year, N) %>% count(bin, name = "k") %>%
  mutate(share = k / sum(k), ln = log(pmax(share * N, 1000))) %>% ungroup() %>%
  select(beach, survey_year, bin, ln) %>% pivot_wider(names_from = bin, values_from = ln, values_fill = log(1000)) %>%
  arrange(beach, survey_year)
incr <- map_dfr(BEACHES, function(b) {
  d <- lg10 %>% filter(beach == b) %>% mutate(across(all_of(bins10), ~ as.numeric(scale(.x))))
  d1 <- d %>% mutate(across(all_of(bins10), ~ ifelse(lag(survey_year) == survey_year - 1, lag(.x), NA_real_), .names = "{.col}_l1"))
  map_dfr(seq_along(bins10), function(i) {
    r <- sapply(seq_along(bins10), function(j) if (j < i) NA_real_ else
      suppressWarnings(cor(d1[[paste0(bins10[i], "_l1")]], d1[[bins10[j]]], use = "complete.obs")))
    j <- if (all(is.na(r))) NA_integer_ else which.max(r)
    tibble(beach = b, source_mm = mids[i], target_mm = mids[j], r = r[j], increment_mm = mids[j] - mids[i],
           n_pairs = sum(!is.na(d1[[paste0(bins10[i], "_l1")]]) & !is.na(d1[[bins10[i]]])),
           increment_wdfw_curve = (VB_LINF[[b]] - mids[i]) * (1 - exp(-VB_K[[b]])),
           increment_mixture_curve = (VB_LINF[[b]] - mids[i]) * (1 - exp(-MIX_K[[b]])))
  })
})
write_tab(incr, "cohort_growth_increments")
incr_summary <- incr %>% filter(r >= 0.4, source_mm <= 125) %>% group_by(beach) %>% group_modify(~ {
  Linf <- VB_LINF[[.y$beach]]
  k_fixed <- -log(1 - sum(.x$r * .x$increment_mm / (Linf - .x$source_mm)) / sum(.x$r))
  free <- tryCatch(nls(increment_mm ~ (L - source_mm) * (1 - exp(-K)), data = .x, start = list(L = Linf, K = 0.8), weights = r),
                   error = function(e) NULL)
  tibble(n_bins_used = nrow(.x), Linf_wdfw = Linf, K_wdfw = VB_K[[.y$beach]], K_tracking_Linf_fixed = k_fixed,
         Linf_tracking_free = if (is.null(free)) NA_real_ else coef(free)[["L"]], K_tracking_free = if (is.null(free)) NA_real_ else coef(free)[["K"]],
         increment_at_55mm_tracking = (Linf - 55) * (1 - exp(-k_fixed)), increment_at_55mm_wdfw = (Linf - 55) * (1 - exp(-VB_K[[.y$beach]])),
         K_used_by_mixture = MIX_K[[.y$beach]], t0_used_by_mixture = MIX_T0[[.y$beach]], fast_tail_component = MIX_FAST_TAIL[[.y$beach]])
}) %>% ungroup() %>% mutate(beach = as.character(beach))
write_tab(incr_summary, "cohort_growth_increments_summary")
p_incr <- incr %>% filter(source_mm <= 135) %>%
  ggplot(aes(source_mm, increment_mm)) +
  geom_line(aes(y = increment_wdfw_curve, linetype = "WDFW curve (K, L-inf of the study beach or its proxy)"), colour = "grey30") +
  geom_line(aes(y = increment_mixture_curve, linetype = "curve used by the length mixture"), colour = "#0072B2") +
  geom_point(aes(size = r, colour = r >= 0.4)) +
  facet_wrap(~ beach, nrow = 1) +
  scale_colour_manual(values = c(`TRUE` = "black", `FALSE` = "grey70"), labels = c("r < 0.4 (not used)", "r >= 0.4"), name = NULL) +
  scale_size_continuous(range = c(0.6, 3), name = "r") +
  scale_linetype_manual(values = c(1, 2), name = NULL) +
  labs(x = "Shell length at survey t-1 (mm, bin midpoint)", y = "Modal increment to survey t (mm)",
       title = "Annual growth increments from year-class tracking across consecutive surveys",
       subtitle = "Points: the 10 mm bin at survey t best predicted by each bin at t-1. Kalaloch grows about half as fast as the Copalis curve at a given length.") +
  theme_ms(9) + theme(legend.position = "bottom", legend.box = "vertical")
save_fig(p_incr, "fig_growth_increments", 11, 4.4)

# (ii) cohort linkage of the length-based year classes, beside the size-class
# linkage of (c): the year-old cohort at survey t should reappear as the
# two-year-olds at t+1, and (at the late surveys) settlers at t as year-olds at t+1.
# Pearson r on the log numbers (as for the size classes), Spearman r beside it,
# and Pearson r over pairs where both fits are sound (>= 150 lengths, KS <= 0.08),
# because one poorly fitted survey can decide a Pearson r at Kalaloch.
link_lb <- cl %>% filter(fitted) %>% arrange(beach, survey_year) %>% group_by(beach) %>%
  mutate(l0 = ifelse(settler_component, log(N_settler), NA_real_),
         l1 = log(N_age1), l2 = log(N_age2), l3 = log(N_age3plus),
         sound = !low_precision & ks <= 0.08,
         consecutive = lead(survey_year) == survey_year + 1,
         l1_next = ifelse(consecutive, lead(l1), NA_real_), l2_next = ifelse(consecutive, lead(l2), NA_real_),
         l3_next = ifelse(consecutive, lead(l3), NA_real_),
         both_sound = sound & ifelse(consecutive, lead(sound), FALSE)) %>%
  summarise(r_age1_t_age2_t1 = cor(l1, l2_next, use = "complete.obs"),
            p_age1_t_age2_t1 = cor.test(l1, l2_next)$p.value,
            rho_age1_t_age2_t1 = cor(l1, l2_next, use = "complete.obs", method = "spearman"),
            r_age1_t_age2_t1_sound_fits = cor(l1[both_sound], l2_next[both_sound], use = "complete.obs"),
            n_sound_pairs = sum(both_sound & !is.na(l2_next)),
            r_age2_t_age3_t1 = cor(l2, l3_next, use = "complete.obs"),
            n_settler_pairs = sum(!is.na(l0) & !is.na(l1_next)),
            r_settler_t_age1_t1 = if (n_settler_pairs >= 8) cor(l0, l1_next, use = "complete.obs") else NA_real_,
            n_lengthbased = sum(!is.na(l1) & !is.na(l2_next)), .groups = "drop")
link <- link %>% left_join(link_lb, by = "beach")
write_tab(link, "cohort_linkage")

p_link_lb <- cl %>% filter(fitted) %>% arrange(beach, survey_year) %>% group_by(beach) %>%
  mutate(l2_next = ifelse(lead(survey_year) == survey_year + 1, lead(log(N_age2)), NA_real_)) %>% ungroup() %>%
  filter(!is.na(l2_next)) %>%
  ggplot(aes(log(N_age1), l2_next)) +
  geom_point(aes(shape = low_precision | ks > 0.08), alpha = .7) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = "black") +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 4), labels = c("fit ok", "few lengths or poor fit"), name = NULL) +
  facet_wrap(~ beach, nrow = 1, scales = "free") +
  labs(x = "log year-old cohort (length-based), survey t", y = "log two-year-olds (length-based), survey t+1",
       title = "Length-based year classes: the year-old cohort at survey t becomes the two-year-olds at t+1") +
  theme_ms(10) + theme(legend.position = "bottom")
save_fig(p_link_lb, "fig_cohort_linkage_lengthbased", 11, 3.8)

# (iii) boundaries, contamination of the size classes, summary by beach
sep_summary <- cl %>% filter(fitted) %>% group_by(beach) %>%
  summarise(n_beach_years = n(), n_few_lengths = sum(low_precision), n_poor_fit = sum(ks > 0.08),
            median_survey_doy = median(survey_doy), median_ks = median(ks),
            growth_K = first(growth_K), growth_t0 = first(growth_t0), fast_tail = first(fast_tail),
            n_with_settler_component = sum(settler_component),
            median_boundary_settler_age1 = median(boundary_settler_age1, na.rm = TRUE),
            median_boundary_age1_age2 = median(boundary_age1_age2, na.rm = TRUE),
            median_boundary_age2_age3 = median(boundary_age2_age3, na.rm = TRUE),
            median_mu_age1 = median(mu_age1), median_mu_age1_fast = median(mu_age1_fast, na.rm = TRUE), median_mu_age2 = median(mu_age2),
            median_mu_age3plus = median(mu_age3plus),
            mean_share_age1_above_76 = mean(share_age1_above_76), min_share_age1_above_76 = min(share_age1_above_76),
            max_share_age1_above_76 = max(share_age1_above_76),
            share_years_age1_above_76_over_half = mean(share_age1_above_76 > 0.5),
            mean_share_rec_class_age1 = mean(share_rec_class_age1),
            mean_share_pre_class_settlers = mean(share_pre_class_settlers[settler_component]),
            mean_abs_share_gap = mean(abs(share_gap)), .groups = "drop") %>%
  mutate(beach = as.character(beach)) %>%
  left_join(link %>% mutate(beach = as.character(beach)) %>%
              select(beach, r_pre_t_rec_t1, r_age1_t_age2_t1, rho_age1_t_age2_t1, r_age1_t_age2_t1_sound_fits,
                     r_age2_t_age3_t1, r_settler_t_age1_t1), by = "beach")
all_row <- cl %>% filter(fitted) %>%
  summarise(beach = "All beaches", n_beach_years = n(), n_few_lengths = sum(low_precision), n_poor_fit = sum(ks > 0.08),
            median_survey_doy = median(survey_doy), median_ks = median(ks), n_with_settler_component = sum(settler_component),
            median_boundary_settler_age1 = median(boundary_settler_age1, na.rm = TRUE),
            median_boundary_age1_age2 = median(boundary_age1_age2, na.rm = TRUE),
            median_boundary_age2_age3 = median(boundary_age2_age3, na.rm = TRUE),
            mean_share_age1_above_76 = mean(share_age1_above_76), min_share_age1_above_76 = min(share_age1_above_76),
            max_share_age1_above_76 = max(share_age1_above_76),
            share_years_age1_above_76_over_half = mean(share_age1_above_76 > 0.5),
            mean_share_rec_class_age1 = mean(share_rec_class_age1),
            mean_share_pre_class_settlers = mean(share_pre_class_settlers[settler_component]),
            mean_abs_share_gap = mean(abs(share_gap)))
write_tab(bind_rows(sep_summary, all_row), "cohort_separation_summary")

bnd <- cl %>% filter(fitted) %>%
  select(beach, survey_year, survey_doy, `settler | year-old` = boundary_settler_age1,
         `year-old | two-year-old` = boundary_age1_age2, `two-year-old | older` = boundary_age2_age3) %>%
  pivot_longer(-c(beach, survey_year, survey_doy), names_to = "boundary", values_to = "length_mm") %>%
  filter(!is.na(length_mm)) %>% mutate(panel = "A. Fitted cohort boundaries (mm) by survey date")
curve_g <- tibble(doy = seq(110, 245, 5)) %>%
  mutate(`year-old (curve)` = vb_length("Copalis", 1 + (doy - SETTLE_DOY) / 365.25),
         `two-year-old (curve)` = vb_length("Copalis", 2 + (doy - SETTLE_DOY) / 365.25)) %>%
  pivot_longer(-doy, names_to = "curve", values_to = "length_mm") %>% mutate(panel = "A. Fitted cohort boundaries (mm) by survey date")
cont <- cl %>% filter(fitted) %>%
  select(beach, survey_year, survey_doy, `year-old cohort above 76 mm` = share_age1_above_76,
         `recruit class (>=76 mm) that is year-old` = share_rec_class_age1,
         `pre-recruit class (<76 mm) that is current-year settlers` = share_pre_class_settlers) %>%
  pivot_longer(-c(beach, survey_year, survey_doy), names_to = "share", values_to = "value") %>%
  filter(!(share == "pre-recruit class (<76 mm) that is current-year settlers" & survey_doy < 182)) %>%
  mutate(panel = "B. Share of each size class that belongs to another year class")
doy_breaks <- c(121, 152, 182, 213, 244); doy_labels <- c("1 May", "1 Jun", "1 Jul", "1 Aug", "1 Sep")
pA <- ggplot(bnd, aes(survey_doy, length_mm)) +
  geom_hline(yintercept = 75.5, linetype = 2, colour = "grey40") +
  geom_line(data = curve_g, aes(doy, length_mm, linetype = curve), colour = "black") +
  geom_point(aes(colour = boundary, shape = beach), size = 1.8, alpha = 0.8) +
  scale_colour_manual(values = c("#D55E00", "#0072B2", "#009E73"), name = "Boundary") +
  scale_shape_manual(values = c(16, 17, 15, 3, 4), name = NULL) +
  scale_linetype_manual(values = c(1, 3), name = NULL) +
  scale_x_continuous(breaks = doy_breaks, labels = doy_labels) +
  labs(x = NULL, y = "Shell length (mm)", title = "A. Fitted cohort boundaries by survey date (dashed: the 76 mm recruit boundary)") +
  theme_ms(9) + theme(legend.box = "vertical", legend.spacing.y = unit(0, "pt")) +
  guides(colour = guide_legend(order = 1, nrow = 1), linetype = guide_legend(order = 2, nrow = 1), shape = guide_legend(order = 3, nrow = 1))
pB <- ggplot(cont, aes(survey_doy, value, colour = beach)) +
  geom_point(size = 1.5, alpha = 0.8) +
  facet_wrap(~ share, nrow = 1) +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  scale_x_continuous(breaks = doy_breaks, labels = doy_labels) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(x = "Survey date", y = "Share", title = "B. Share of each size class that belongs to another year class") +
  theme_ms(9)
save_fig(pA, "fig_cohort_separation_boundaries", 10, 4.6)
save_fig(pB, "fig_cohort_separation_shares", 10, 3.6)

# (iv) example fits: for each beach, the fitted year with >= 300 measured clams
# whose survey date is closest to the beach median (a typical survey)
ex_years <- cl %>% filter(fitted, n_lengths >= 300) %>% group_by(beach) %>%
  slice_min(abs(survey_doy - median(survey_doy)), n = 1, with_ties = FALSE) %>% ungroup() %>%
  select(beach, survey_year, survey_doy)
ex <- ex_years %>% mutate(fit = pmap(list(beach, survey_year, survey_doy), function(b, y, d) {
  x <- sl$length_mm[sl$beach == b & sl$survey_year == y]
  cohort_mixture(x, as.character(b), d)
}))
ex_comp <- ex %>% mutate(comp = map(fit, ~ .x$components[[1]])) %>% select(beach, survey_year, survey_doy, comp) %>% unnest(comp) %>%
  mutate(cohort = group_of(group)) %>%
  crossing(length_mm = seq(5, 180, by = 0.5)) %>%
  mutate(dens = w * dnorm(length_mm, mu, sd),
         facet = sprintf("%s %d (%s)", beach, survey_year, format(as.Date(survey_doy - 1, origin = "2001-01-01"), "%d %b")))
ex_tot <- ex_comp %>% group_by(facet, length_mm) %>% summarise(dens = sum(dens), .groups = "drop")
ex_len <- sl %>% inner_join(ex_years, by = c("beach", "survey_year")) %>% filter(!is.na(length_mm), length_mm >= 5, length_mm <= 180) %>%
  mutate(facet = sprintf("%s %d (%s)", beach, survey_year, format(as.Date(survey_doy.y - 1, origin = "2001-01-01"), "%d %b")))
ex_bnd <- ex %>% unnest(fit) %>% select(beach, survey_year, survey_doy, boundary_settler_age1, boundary_age1_age2, boundary_age2_age3) %>%
  pivot_longer(starts_with("boundary"), values_to = "length_mm") %>% filter(!is.na(length_mm)) %>%
  mutate(facet = sprintf("%s %d (%s)", beach, survey_year, format(as.Date(survey_doy - 1, origin = "2001-01-01"), "%d %b")))
facet_levels <- ex_years %>% arrange(survey_doy) %>%
  mutate(facet = sprintf("%s %d (%s)", beach, survey_year, format(as.Date(survey_doy - 1, origin = "2001-01-01"), "%d %b"))) %>% pull(facet)
p_ex <- ggplot() +
  geom_histogram(data = ex_len %>% mutate(facet = factor(facet, facet_levels)), aes(length_mm, after_stat(density)),
                 binwidth = 2, boundary = 0, fill = "grey85", colour = NA) +
  geom_vline(xintercept = 75.5, linetype = 2, colour = "grey40") +
  geom_vline(data = ex_bnd %>% mutate(facet = factor(facet, facet_levels)), aes(xintercept = length_mm), colour = "black", linewidth = 0.3) +
  geom_line(data = ex_comp %>% mutate(facet = factor(facet, facet_levels)), aes(length_mm, dens, colour = cohort, group = group), linewidth = 0.6) +
  geom_line(data = ex_tot %>% mutate(facet = factor(facet, facet_levels)), aes(length_mm, dens), colour = "black", linewidth = 0.4, linetype = 3) +
  facet_wrap(~ facet, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c(settler = "#D55E00", age1 = "#0072B2", age2 = "#009E73", age3plus = "#CC79A7"),
                      labels = c(settler = "current-year settlers", age1 = "year-old cohort (2-3 components)", age2 = "two-year-olds", age3plus = "older"), name = NULL) +
  labs(x = "Shell length (mm)", y = "Density",
       title = "Example mixture fits, one typical survey per beach (ordered by survey date)",
       subtitle = paste0("Grey: measured lengths. Coloured: fitted components by year class; dotted: their sum.\n",
                         "Solid verticals: fitted cohort boundaries; dashed: 76 mm.")) +
  theme_ms(9) + theme(legend.position = "bottom")
save_fig(p_ex, "fig_cohort_mixture_examples", 8, 11)

# (v) the length-based year classes beside the size classes, by survey year
yc_ts <- cl %>% filter(fitted) %>%
  transmute(beach, survey_year,
            `Year class Y-1: pre-recruits (<76 mm)` = pre_recruits, `Year class Y-1: year-old cohort (length-based)` = N_age1,
            `Year class Y-2 and older: recruits (>=76 mm)` = recruits, `Year class Y-2 and older: two-year-olds + older (length-based)` = N_age2 + N_age3plus) %>%
  pivot_longer(-c(beach, survey_year), names_to = "series", values_to = "n") %>%
  mutate(target = ifelse(str_starts(series, "Year class Y-1"), "Year class Y-1", "Year classes Y-2 and older"),
         definition = ifelse(str_detect(series, "length-based"), "length-based cohorts", "76 mm size classes"))
p_yc <- ggplot(yc_ts, aes(survey_year, n / 1e6, colour = definition)) +
  geom_line() + geom_point(size = 0.8) +
  facet_grid(target ~ beach, scales = "free_y") +
  scale_y_log10() +
  scale_colour_manual(values = c("grey45", "#0072B2"), name = NULL) +
  labs(x = "Survey year", y = "Millions of clams (log scale)",
       title = "Size classes versus length-based year classes") +
  theme_ms(9) + theme(legend.position = "bottom")
save_fig(p_yc, "fig_yearclass_abundance", 11, 5)
message("02 (g): length-based linkage r(age-1 at t, age-2 at t+1) = ",
        paste(sprintf("%s %.2f (rho %.2f, sound fits %.2f)", link$beach, link$r_age1_t_age2_t1, link$rho_age1_t_age2_t1,
                      link$r_age1_t_age2_t1_sound_fits), collapse = ", "),
        "; size-class linkage r(pre at t, rec at t+1) = ", paste(sprintf("%.2f", link$r_pre_t_rec_t1), collapse = ", "))
}

message("02_cohort_diagnostics: done")

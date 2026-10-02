# ═══════════════════════════════════════════════════════════════════════════════
# 02_cohort_diagnostics.R — what does a "pre-recruit" represent, and when?
# ═══════════════════════════════════════════════════════════════════════════════
# Establishes empirically (rather than from an assumed growth model):
#   (a) survey timing by beach and year (it differs by ~2 months among beaches
#       and drifts at some beaches);
#   (b) length-frequency structure relative to survey date (current-year
#       settlers are only visible at late surveys);
#   (c) cohort linkage: pre-recruits at survey t predict recruits at t+1;
#   (d) cross-beach synchrony and long-term trends.
# Outputs: figures/fig_survey_timing.png, fig_length_frequency.png,
#          fig_cohort_linkage.png; tables/cohort_linkage.csv,
#          synchrony_*.csv, trends.csv

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
sync <- function(var) {
  survey %>% select(beach, survey_year, v = all_of(var)) %>%
    filter(!is.na(v)) %>% mutate(v = log(v)) %>%
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

message("02_cohort_diagnostics: done")

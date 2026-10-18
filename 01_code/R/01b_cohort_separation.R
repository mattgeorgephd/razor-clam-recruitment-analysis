# ═══════════════════════════════════════════════════════════════════════════════
# 01b_cohort_separation.R — year-class abundances from the shell lengths
# ═══════════════════════════════════════════════════════════════════════════════
# For every beach-year with enough measured clams, fits the growth-curve-
# informed length mixture of lib_cohort_mixture.R and applies its cohort shares
# to the total abundance estimate (pre-recruits + recruits), giving:
#   N_settler   current-year settlers (year class = survey year; late surveys only)
#   N_age1      the year-old cohort (year class = survey year - 1), free of settlers
#               and including its fast tail above 76 mm
#   N_age2      two-year-olds (year class = survey year - 2)
#   N_age3plus  older clams
# Why: the fixed 76 mm boundary cuts through the year-old cohort at the August
# surveys and admits settlers into the pre-recruit class, so "pre-recruits at
# survey Y+1" and "recruits at survey Y+2" are impure measures of year class Y
# (docs/growth-model-review.md; task T14). N_age1 and N_age2 are year-class
# measures by construction. They are added to cohort_table.csv as yc1_next
# (year class Y at survey Y+1), yc2_next2 (at survey Y+2) and yc0_settlers
# (settlers of year class Y at the late survey of year Y), with logs, and used
# as length-based responses in 04, 05 and 06 beside the size-class responses.
# A cohort share below one measured clam (1 / n_lengths) is "not seen" rather
# than zero, so shares are floored there before being applied: without the
# floor a component whose weight collapses in one survey gives log N of -300
# and a single beach-year can decide a correlation (Kalaloch 2007 did).
# Outputs: 02_data/derived/cohort_lengths.csv (one row per beach-year),
#          cohort_table.csv (columns added), tables/cohort_separation_by_year.csv

source(here::here("01_code", "R", "00_config.R"))
source(here::here("01_code", "R", "lib_cohort_mixture.R"))

survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE)
sl <- read_lengths() %>% transmute(beach = as.character(beach), survey_year, length_mm)

fits <- sl %>% group_by(beach, survey_year) %>%
  summarise(lengths = list(length_mm), .groups = "drop") %>%
  inner_join(survey %>% select(beach, survey_year, survey_doy, survey_doy_imputed, pre_recruits, recruits),
             by = c("beach", "survey_year")) %>%
  mutate(fit = pmap(list(lengths, beach, survey_doy), ~ cohort_mixture(..1, ..2, ..3))) %>%
  select(-lengths) %>% unnest(fit) %>%
  mutate(N_total = pre_recruits + recruits,
         w_floor = 1 / n_lengths,
         N_settler = N_total * pmax(w_settler, w_floor), N_age1 = N_total * pmax(w_age1, w_floor),
         N_age2 = N_total * pmax(w_age2, w_floor), N_age3plus = N_total * pmax(w_age3plus, w_floor),
         low_precision = n_lengths < 150,
         # mixture shares are consistent with the 76 mm abundance split when the
         # measured share below 76 mm matches the abundance share; report the gap
         abundance_share_pre = pre_recruits / N_total,
         share_gap = share_measured_pre - abundance_share_pre) %>%
  arrange(factor(beach, BEACHES), survey_year)

# assertions (task T30): every fitted survey's cohort shares sum to one, and no
# year-class abundance is non-positive
ok <- fits$fitted %in% TRUE
stopifnot(all(abs(fits$w_settler[ok] + fits$w_age1[ok] + fits$w_age2[ok] + fits$w_age3plus[ok] - 1) < 1e-6),
          all(fits$N_age1[ok] > 0 | is.na(fits$N_age1[ok])), all(fits$N_age2[ok] > 0 | is.na(fits$N_age2[ok])))

write_csv(fits %>% select(-components), file.path(DERIVED, "cohort_lengths.csv"))
write_tab(fits %>% select(-components), "cohort_separation_by_year")

# ── Add the year-class abundances to the cohort table ───────────────────────
cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE) %>%
  select(-any_of(c("yc0_settlers", "yc1_next", "yc2_next2", "log_yc0_settlers", "log_yc1_next", "log_yc2_next2",
                   "n_lengths_next", "n_lengths_next2", "separation_flag_next")))
cl <- fits %>% mutate(beach = as.character(beach)) %>% filter(fitted)
cohort <- cohort %>% mutate(beach = as.character(beach)) %>%
  left_join(cl %>% transmute(beach, year_class = survey_year, yc0_settlers = ifelse(settler_component, N_settler, NA_real_)),
            by = c("beach", "year_class")) %>%
  left_join(cl %>% transmute(beach, year_class = survey_year - 1L, yc1_next = N_age1, n_lengths_next = n_lengths,
                             separation_flag_next = ifelse(low_precision, "few lengths", ifelse(ks > 0.08, "poor fit", "ok"))),
            by = c("beach", "year_class")) %>%
  left_join(cl %>% transmute(beach, year_class = survey_year - 2L, yc2_next2 = N_age2, n_lengths_next2 = n_lengths),
            by = c("beach", "year_class")) %>%
  mutate(log_yc0_settlers = log(yc0_settlers), log_yc1_next = log(yc1_next), log_yc2_next2 = log(yc2_next2),
         beach = factor(beach, levels = BEACHES)) %>%
  arrange(beach, year_class)
write_csv(cohort, file.path(DERIVED, "cohort_table.csv"))

message("01b_cohort_separation: fitted ", sum(fits$fitted), " of ", nrow(fits), " beach-years (",
        sum(fits$low_precision & fits$fitted, na.rm = TRUE), " with < 150 lengths, ",
        sum(fits$ks > 0.08, na.rm = TRUE), " with KS > 0.08); year-old cohort above 76 mm: mean share ",
        round(mean(fits$share_age1_above_76, na.rm = TRUE), 3), "; settlers in the pre-recruit class at late surveys: mean share ",
        round(mean(fits$share_pre_class_settlers[fits$settler_component %in% TRUE], na.rm = TRUE), 3))

# ═══════════════════════════════════════════════════════════════════════════════
# 06_forecast_skill.R — honest out-of-sample skill
# ═══════════════════════════════════════════════════════════════════════════════
# The original notebook selected predictors (best |r| over ~90 window x lag x
# metric cells) using ALL years, then cross-validated only the regression
# coefficients. Selection outside the CV loop leaks information and inflates
# skill (Ambroise & McLachlan 2002; Varma & Simon 2006).
#
# Rolling-origin evaluation, one-step-ahead, for each beach x {pre, rec}
# (original response definition: log1p abundance at survey t):
#   climatology    training-period mean
#   persistence    previous year's value
#   leaky_k        best k predictors chosen once from all 28 years (as the
#                  notebook did), coefficients refit on training years
#   honest_k       best k predictors re-selected inside every training window
# and, in the cohort framework (log pre-recruits of year class Y at survey Y+1):
#   trend          training-period linear trend
#   trend+BEUTI    pre-specified model (04_confirmatory_models.R), no selection
#   honest_scan    the best (series, window) from the full window catalogue of
#                  05_window_scan.R, re-selected inside every training window on
#                  the coastwide index, then used in a beach model
#                  log pre ~ year class + spawners + survey date + x. This is the
#                  exploratory "which predictor best explains recruitment" answer,
#                  scored out of sample. leaky_scan selects once on all years.
# The cohort framework is run twice: for the 76 mm pre-recruit class and, as a
# sensitivity (task T14), for the length-based year-old cohort of
# 01b_cohort_separation.R (outputs suffixed _lengthbased).
# Skill score SS = 1 - MSE(model) / MSE(climatology) over the same targets.
# Outputs: tables/forecast_skill_*.csv, forecast_selection_stability*.csv,
#          figures/fig_forecast_skill.png, fig_forecast_skill_cohort*.png

source(here::here("01_code", "R", "00_config.R"))
source(here::here("01_code", "R", "lib_original_grid.R"))

MIN_TRAIN <- 14
K_MAX <- 2

metric_of <- function(p) str_split_fixed(p, "_", 2)[, 1]

select_preds <- function(Xlist, y, rows, k) {
  # returns list of (lag index, predictor) for the top-k |r| cells using `rows`,
  # with the k-th chosen from a different metric than the first (as the notebook did)
  cand <- map_dfr(seq_along(Xlist), function(li) {
    Xb <- Xlist[[li]][rows, , drop = FALSE]; yy <- y[rows]
    n <- colSums(!is.na(Xb) & !is.na(yy))
    r <- suppressWarnings(cor(Xb, yy, use = "pairwise.complete.obs"))[, 1]
    tibble(li = li, pred = colnames(Xb), r = r, n = n)
  }) %>% filter(n >= 8, !is.na(r)) %>% arrange(desc(abs(r)))
  if (nrow(cand) == 0) return(NULL)
  out <- cand[1, ]
  if (k >= 2) {
    alt <- cand %>% filter(metric_of(pred) != metric_of(out$pred[1]))
    if (nrow(alt) > 0) out <- bind_rows(out, alt[1, ])
  }
  out
}

predict_with <- function(Xlist, y, sel, train, target) {
  if (is.null(sel)) return(NA_real_)
  Xs <- sapply(seq_len(nrow(sel)), function(j) Xlist[[sel$li[j]]][, sel$pred[j]])
  Xs <- matrix(Xs, ncol = nrow(sel))
  d <- as.data.frame(Xs); d$y <- y
  if (any(is.na(d[target, seq_len(nrow(sel))]))) return(NA_real_)
  fit <- lm(y ~ ., data = d[train, , drop = FALSE])
  as.numeric(predict(fit, newdata = d[target, , drop = FALSE]))
}

series <- colnames(Ymat)
fc <- map_dfr(series, function(s) {
  b <- str_split_fixed(s, "\\|", 2)[1]
  y <- Ymat[, s]; n <- length(y)
  leaky <- map(1:K_MAX, ~ select_preds(X[[b]], y, seq_len(n), .x))
  map_dfr(MIN_TRAIN:(n - 1), function(t) {
    train <- seq_len(t); target <- t + 1
    clim <- mean(y[train])
    out <- tibble(series = s, year = years[target], obs = y[target],
                  climatology = clim, persistence = y[t])
    # Stock carry-over (recruits only): recruits(t) ~ pre-recruits(t-1) + recruits(t-1),
    # using the cohort linkage documented in 02_cohort_diagnostics.R; no selection.
    if (str_ends(s, "Rec")) {
      pre <- Ymat[, paste(b, "Pre", sep = "|")]
      dd <- tibble(y = y, pre_l1 = dplyr::lag(pre), rec_l1 = dplyr::lag(y))
      f <- lm(y ~ pre_l1 + rec_l1, data = dd[2:t, ])
      out$carryover <- as.numeric(predict(f, newdata = dd[target, ]))
    } else out$carryover <- NA_real_
    for (k in 1:K_MAX) {
      honest_sel <- select_preds(X[[b]], y, train, k)
      out[[paste0("leaky_", k)]]  <- predict_with(X[[b]], y, leaky[[k]], train, target)
      out[[paste0("honest_", k)]] <- predict_with(X[[b]], y, honest_sel, train, target)
    }
    out
  })
})

# Missing predictor at target → fall back to climatology (counted)
model_cols <- c("persistence", "carryover", paste0(rep(c("leaky_", "honest_"), each = K_MAX), 1:K_MAX))
fallbacks <- fc %>% summarise(across(all_of(model_cols), ~ sum(is.na(.x))))
fc <- fc %>% mutate(across(all_of(setdiff(model_cols, "carryover")), ~ coalesce(.x, climatology)))

skill <- function(df, cols) {
  df %>% pivot_longer(all_of(cols), names_to = "model", values_to = "pred") %>%
    filter(!is.na(pred)) %>%
    group_by(model) %>%
    summarise(n_forecasts = n(), mse = mean((obs - pred)^2),
              mse_clim = mean((obs - climatology)^2), .groups = "drop") %>%
    mutate(skill_vs_climatology = 1 - mse / mse_clim)
}
skill_overall <- fc %>%
  mutate(resp = str_split_fixed(series, "\\|", 2)[, 2]) %>%
  group_by(resp) %>% group_modify(~ skill(.x, model_cols)) %>% ungroup()
skill_series <- fc %>% group_by(series) %>% group_modify(~ skill(.x, model_cols)) %>% ungroup()
write_tab(skill_overall, "forecast_skill_original_framework")
write_tab(skill_series, "forecast_skill_original_by_series")
write_tab(fallbacks, "forecast_skill_fallback_counts")

# ── Cohort framework: pre-specified BEUTI model and honest all-predictor selection ──
cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE)
survey_tab <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE)

# The window catalogue of 05_window_scan.R (same series, same windows), as a
# [year class x candidate] matrix of raw window means for year classes 1988-2024.
source(here::here("01_code", "R", "lib_window_catalogue.R"))
YC <- 1988:2024
cat_pre <- window_catalogue(YC, last_offset = 1)   # list(X = matrix, meta = tibble(var, window, start, end, dur))

# Coastwide index per year class (as in 05): used only to SELECT the candidate
# inside each training window; the beach models then use the raw window mean.
detr <- function(x, t) { ok <- !is.na(x); out <- rep(NA_real_, length(x)); out[ok] <- resid(lm(x[ok] ~ t[ok])); out }

cohort_framework <- function(resp, suffix = "", series_tag = "PreYC", title_lab = "Year-class pre-recruits") {
  d_all <- cohort %>% filter(!is.na(.data[[resp]]), !is.na(log_spawners), !is.na(doy_next)) %>%
    mutate(y = .data[[resp]])
  idx <- d_all %>% group_by(beach) %>% mutate(res = zs(resid(lm(y ~ log_spawners + doy_next)))) %>%
    group_by(year_class) %>% summarise(index = mean(res), .groups = "drop")
  select_window <- function(train_years) {
    # best |detrended r| between the coastwide index and every candidate, using training year classes only
    rows <- match(train_years, YC); ix <- idx$index[match(train_years, idx$year_class)]
    ok_y <- !is.na(ix); if (sum(ok_y) < 10) return(NA_integer_)
    y_dt <- detr(ix[ok_y], train_years[ok_y])
    X <- cat_pre$X[rows[ok_y], , drop = FALSE]
    n <- colSums(!is.na(X)); Xd <- apply(X, 2, detr, t = train_years[ok_y])
    r <- suppressWarnings(cor(Xd, y_dt, use = "pairwise.complete.obs"))[, 1]
    r[n < 12] <- NA
    if (all(is.na(r))) NA_integer_ else which.max(abs(r))
  }
  leaky_j <- select_window(idx$year_class)

  fc_c <- map_dfr(BEACHES, function(b) {
    d <- d_all %>% filter(beach == b) %>% arrange(year_class)
    n <- nrow(d)
    if (n <= MIN_TRAIN) return(NULL)
    map_dfr(MIN_TRAIN:(n - 1), function(t) {
      tr <- d[seq_len(t), ]; te <- d[t + 1, ]
      base <- tibble(series = paste(b, series_tag, sep = "|"), year = te$year_class, obs = te$y,
                     climatology = mean(tr$y),
                     persistence = tr$y[t],
                     trend = predict(lm(y ~ year_class, tr), te),
                     trend_spawn_doy = predict(lm(y ~ year_class + log_spawners + doy_next, tr), te))
      beuti_ok <- !is.na(te$beuti_larval) && sum(!is.na(tr$beuti_larval)) >= 10
      base$beuti <- if (beuti_ok) predict(lm(y ~ beuti_larval, tr %>% filter(!is.na(beuti_larval))), te) else NA_real_
      base$trend_beuti <- if (beuti_ok) predict(lm(y ~ year_class + beuti_larval, tr %>% filter(!is.na(beuti_larval))), te) else NA_real_
      with_x <- function(j) {   # beach model with candidate j from the catalogue (NA if unavailable)
        if (is.na(j)) return(list(pred = NA_real_, var = NA_character_, window = NA_character_))
        x <- cat_pre$X[match(c(tr$year_class, te$year_class), YC), j]
        xt <- x[seq_len(t)]; xe <- x[t + 1]
        if (is.na(xe) || sum(!is.na(xt)) < 10) return(list(pred = NA_real_, var = cat_pre$meta$var[j], window = cat_pre$meta$window[j]))
        dd <- tr %>% mutate(x = xt) %>% filter(!is.na(x))
        f <- lm(y ~ year_class + log_spawners + doy_next + x, dd)
        list(pred = as.numeric(predict(f, te %>% mutate(x = xe))), var = cat_pre$meta$var[j], window = cat_pre$meta$window[j])
      }
      h <- with_x(select_window(tr$year_class)); l <- with_x(leaky_j)
      base %>% mutate(honest_scan = h$pred, honest_var = h$var, honest_window = h$window,
                      leaky_scan = l$pred, leaky_var = l$var, leaky_window = l$window)
    })
  })
  cohort_models <- c("persistence", "trend", "trend_spawn_doy", "beuti", "trend_beuti", "honest_scan", "leaky_scan")
  write_tab(fc_c %>% summarise(across(all_of(cohort_models), ~ sum(is.na(.x)))), paste0("forecast_skill_cohort_fallback_counts", suffix))
  fc_c <- fc_c %>% mutate(across(all_of(cohort_models), ~ coalesce(.x, climatology)))
  skill_c <- bind_rows(
    skill(fc_c, cohort_models) %>% mutate(series = "All beaches"),
    fc_c %>% group_by(series) %>% group_modify(~ skill(.x, cohort_models)) %>% ungroup())
  write_tab(skill_c, paste0("forecast_skill_cohort_framework", suffix))
  write_tab(fc_c %>% select(series, year, obs, climatology, honest_scan, honest_var, honest_window, leaky_var, leaky_window),
            paste0("forecast_skill_cohort_selections", suffix))

  # Stability of the exploratory choice: how often each series (and window) is
  # selected across training origins (one selection per origin, shared by beaches),
  # plus the series selected on all years (leaky) for reference.
  sel_by_origin <- fc_c %>% distinct(year, honest_var, honest_window) %>% filter(!is.na(honest_var))
  stability <- sel_by_origin %>% count(honest_var, name = "n_origins_selected") %>%
    mutate(share = n_origins_selected / nrow(sel_by_origin)) %>% arrange(desc(n_origins_selected)) %>%
    rename(var = honest_var) %>%
    mutate(selected_on_all_years = var == cat_pre$meta$var[leaky_j],
           windows_selected = map_chr(var, ~ paste(unique(sel_by_origin$honest_window[sel_by_origin$honest_var == .x]), collapse = "; ")))
  write_tab(stability, paste0("forecast_selection_stability", suffix))

  # Cohort framework: skill of the exploratory selection against the baselines
  lab_c <- c(persistence = "Persistence", trend = "Trend", trend_spawn_doy = "Trend + spawners + survey date",
             trend_beuti = "Trend + BEUTI (a priori)", leaky_scan = "Scan selection on all years (leaky)",
             honest_scan = "Scan selection inside training window (honest)")
  p2 <- skill_c %>% filter(model %in% names(lab_c)) %>%
    mutate(beach = ifelse(series == "All beaches", "All beaches", str_split_fixed(series, "\\|", 2)[, 1]),
           beach = factor(beach, c("All beaches", BEACHES)), model = factor(lab_c[model], levels = lab_c)) %>%
    ggplot(aes(skill_vs_climatology, beach, colour = model)) +
    geom_vline(xintercept = 0, linetype = 2) +
    geom_point(position = position_dodge(width = 0.6), size = 2) +
    scale_colour_manual(values = c("grey50", "#999999", "#009E73", "#0072B2", "#E69F00", "#D55E00"), name = NULL) +
    coord_cartesian(xlim = c(-1.5, 1)) +
    labs(x = "Out-of-sample skill vs climatology (1 - MSE/MSE_clim); >0 beats the mean", y = NULL,
         title = paste0(title_lab, ": skill of the exploratory predictor search"),
         subtitle = paste0("Honest = best of ", ncol(cat_pre$X), " (series x window) candidates re-chosen in each training window; leaky = chosen once")) +
    theme_ms(10) + guides(colour = guide_legend(nrow = 3))
  save_fig(p2, paste0("fig_forecast_skill_cohort", suffix), 9, 5.5)
  invisible(list(skill = skill_c, stability = stability))
}

cf <- cohort_framework("log_pre_next")
skill_cohort <- cf$skill
if ("log_yc1_next" %in% names(cohort) && any(!is.na(cohort$log_yc1_next))) {
  cf_lb <- cohort_framework("log_yc1_next", suffix = "_lengthbased", series_tag = "Age1YC",
                            title_lab = "Year-old cohort (length-based)")
  message("06: honest-selection skill, all beaches: pre-recruits ",
          sprintf("%.2f", cf$skill$skill_vs_climatology[cf$skill$series == "All beaches" & cf$skill$model == "honest_scan"]),
          "; year-old cohort (length-based) ",
          sprintf("%.2f", cf_lb$skill$skill_vs_climatology[cf_lb$skill$series == "All beaches" & cf_lb$skill$model == "honest_scan"]))
} else message("06: length-based response not in cohort_table.csv (run 01b first); cohort framework run for pre-recruits only")

# ── In-sample vs out-of-sample comparison figure ────────────────────────────
lab <- c(persistence = "Persistence", carryover = "Carry-over: pre(t-1) + rec(t-1)", leaky_1 = "Leaky selection, 1 predictor",
         leaky_2 = "Leaky selection, 2 predictors", honest_1 = "Honest selection, 1 predictor",
         honest_2 = "Honest selection, 2 predictors")
p <- skill_series %>%
  mutate(beach = factor(str_split_fixed(series, "\\|", 2)[, 1], BEACHES),
         resp = recode(str_split_fixed(series, "\\|", 2)[, 2], Pre = "Pre-recruits", Rec = "Recruits"),
         model = factor(lab[model], levels = lab)) %>%
  ggplot(aes(skill_vs_climatology, beach, colour = model)) +
  geom_vline(xintercept = 0, linetype = 2) +
  geom_point(position = position_dodge(width = 0.6), size = 2) +
  facet_wrap(~ resp) +
  scale_colour_manual(values = c("grey50", "#009E73", "#E69F00", "#D55E00", "#56B4E9", "#0072B2"), name = NULL) +
  coord_cartesian(xlim = c(-2, 1)) +
  labs(x = "Out-of-sample skill vs climatology (1 - MSE/MSE_clim); >0 beats the mean",
       y = NULL, title = "Rolling-origin forecast skill, survey years 2011-2024",
       subtitle = "Leaky = predictors chosen using all years (original notebook); honest = chosen within each training window") +
  theme_ms(10) + guides(colour = guide_legend(nrow = 2))
save_fig(p, "fig_forecast_skill", 9, 5)

message("06_forecast_skill: done")

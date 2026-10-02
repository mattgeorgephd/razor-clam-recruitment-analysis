# ═══════════════════════════════════════════════════════════════════════════════
# 05_window_scan.R — exploratory climate-window scan with family-wise calibration
# ═══════════════════════════════════════════════════════════════════════════════
# A transparent, climwin-style search (van de Pol et al. 2016) over every window
# of 1-4 consecutive months from January of the year BEFORE spawning (Y-1)
# through June of the response survey year, for five environmental series.
# Response: coastwide year-class index = mean across beaches of standardised
# residuals of log abundance on (beach-centred) log spawners and survey date.
# Both response and predictor are linearly detrended (partial correlation on
# year class). Family-wise error is controlled by comparing every |r| with the
# distribution of the MAXIMUM |r| over the whole scan obtained from
# phase-randomised surrogates of the response.
# Outputs: tables/window_scan_*.csv, figures/fig_window_scan_*.png

source(here::here("01_code", "R", "00_config.R"))
set.seed(SEED + 5)

env <- read_csv(file.path(DERIVED, "env_monthly.csv"), show_col_types = FALSE) %>%
  transmute(year, month, BEUTI = beuti_47N, CUTI = cuti_47N, `SST anomaly` = sst_anom,
            PDO = pdo, `Columbia discharge` = q_cms)
VARS <- c("BEUTI", "CUTI", "SST anomaly", "PDO", "Columbia discharge")
survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE)
cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE) %>%
  left_join(survey %>% transmute(beach, year_class = survey_year - 2L, doy_next2 = survey_doy),
            by = c("beach", "year_class"))

make_index <- function(resp, doy) {
  cohort %>% filter(!is.na(.data[[resp]]), !is.na(log_spawners), !is.na(.data[[doy]])) %>%
    group_by(beach) %>%
    mutate(res = zs(resid(lm(as.formula(paste(resp, "~ log_spawners +", doy)))))) %>%
    group_by(year_class) %>% summarise(index = mean(res), n_beach = n(), .groups = "drop")
}
indices <- list(
  pre = list(idx = make_index("log_pre_next", "doy_next"), last_offset = 1,
             label = "Pre-recruits of year class Y at survey Y+1"),
  rec = list(idx = make_index("log_rec_next2", "doy_next2"), last_offset = 2,
             label = "Recruits of year class Y at survey Y+2"))

# window catalogue: relative month k = 12*offset + month, offset -1 … last_offset
scan_windows <- function(last_offset) {
  ks <- seq(12 * -1 + 1, 12 * last_offset + 6)          # Jan(Y-1) … Jun(Y+last_offset)
  expand_grid(start = ks, dur = 1:4) %>% mutate(end = start + dur - 1) %>% filter(end <= max(ks))
}
k_to_label <- function(k) {
  off <- floor((k - 1) / 12); m <- k - 12 * off
  paste0(month.abb[m], " ", ifelse(off == 0, "Y", ifelse(off > 0, paste0("Y+", off), paste0("Y", off))))
}

# Window means as contiguous slices of a vector indexed by absolute month
# (12 * year + month): relative month k of year class Y is element 12*Y + k.
# Returns a [year classes x windows] matrix; windows with fewer than 75% of
# their months present are NA. (Vectorised 2026-10-02: identical results to the
# earlier per-window join, ~100x faster.)
window_matrix <- function(v, yc, win) {
  a <- rep(NA_real_, 12L * (max(env$year) + 2L))
  a[12L * env$year + env$month] <- env[[v]]
  sapply(seq_len(nrow(win)), function(i) {
    ks <- win$start[i]:win$end[i]; need <- ceiling(0.75 * length(ks))
    vapply(yc, function(Y) {
      x <- a[12L * Y + ks]
      if (sum(!is.na(x)) < need) NA_real_ else mean(x, na.rm = TRUE)
    }, numeric(1))
  })
}

detr <- function(x, t) { ok <- !is.na(x); out <- rep(NA_real_, length(x)); out[ok] <- resid(lm(x[ok] ~ t[ok])); out }

phase_surr <- function(y, nsurr) {
  n <- length(y); half <- floor((n - 1) / 2); f <- fft(y - mean(y))
  replicate(nsurr, {
    ph <- runif(half, 0, 2 * pi); rot <- rep(1 + 0i, n)
    rot[2:(half + 1)] <- exp(1i * ph); rot[n:(n - half + 1)] <- exp(-1i * ph)
    s <- Re(fft(f * rot, inverse = TRUE)) / n
    sort(y)[rank(s, ties.method = "first")]
  })
}

results <- list()
for (nm in names(indices)) {
  idx <- indices[[nm]]$idx
  yc <- idx$year_class
  y_dt <- detr(idx$index, yc)
  win <- scan_windows(indices[[nm]]$last_offset)
  Xw <- map(set_names(VARS), ~ window_matrix(.x, yc, win))
  obs <- map_dfr(VARS, function(v) {
    Xd <- apply(Xw[[v]], 2, detr, t = yc)
    r <- suppressWarnings(cor(Xd, y_dt, use = "pairwise.complete.obs"))[, 1]
    win %>% mutate(var = v, r = r, n = colSums(!is.na(Xd)))
  })
  S <- phase_surr(y_dt, N_SURROGATES)
  Xd_all <- do.call(cbind, map(VARS, ~ apply(Xw[[.x]], 2, detr, t = yc)))
  null_max <- apply(abs(suppressWarnings(cor(Xd_all, S, use = "pairwise.complete.obs"))), 2, max, na.rm = TRUE)
  obs <- obs %>%
    mutate(p_naive = 2 * pt(-abs(r * sqrt((n - 2) / (1 - r^2))), n - 2),
           p_fwer = map_dbl(abs(r), ~ mean(null_max >= .x)),
           q_bh = p.adjust(p_naive, "BH"),
           response = nm, window = paste(k_to_label(start), "-", k_to_label(end)))
  results[[nm]] <- list(obs = obs, null_max = null_max)

  p <- obs %>%
    mutate(var = factor(var, VARS), mid = (start + end) / 2) %>%
    ggplot(aes(start, factor(dur), fill = r)) +
    geom_tile() +
    geom_tile(data = ~ filter(.x, p_fwer < 0.05), fill = NA, colour = "black", linewidth = 0.6) +
    geom_vline(xintercept = Filter(function(v) v < max(win$end), c(0.5, 12.5, 24.5)), linetype = 3) +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", limits = c(-0.8, 0.8)) +
    scale_x_continuous(breaks = seq(-11, 12 * indices[[nm]]$last_offset + 6, by = 3),
                       labels = function(k) k_to_label(k)) +
    facet_wrap(~ var, ncol = 1) +
    labs(x = "Window start month (Y = spawning year)", y = "Window length (months)", fill = "Detrended r",
         title = paste("Exploratory window scan:", indices[[nm]]$label),
         subtitle = paste0(nrow(obs), " windows tested; outlined cells: family-wise p < 0.05 (",
                           N_SURROGATES, " phase-randomised surrogates). 95th pct of null max|r| = ",
                           round(quantile(null_max, .95), 2))) +
    theme_ms(9) + theme(axis.text.x = element_text(angle = 45, hjust = 1))
  save_fig(p, paste0("fig_window_scan_", nm), 10, 9)
}

scan_all <- map_dfr(results, "obs")
write_tab(scan_all %>% arrange(p_naive), "window_scan_all")
write_tab(scan_all %>% group_by(response, var) %>% slice_max(abs(r), n = 1) %>% ungroup() %>%
            select(response, var, window, dur, r, n, p_naive, q_bh, p_fwer), "window_scan_best_per_variable")
write_tab(map_dfr(names(results), ~ tibble(response = .x, n_windows = nrow(results[[.x]]$obs),
                                           null_max_abs_r_95 = quantile(results[[.x]]$null_max, .95),
                                           n_fwer_sig = sum(results[[.x]]$obs$p_fwer < 0.05),
                                           n_naive_sig = sum(results[[.x]]$obs$p_naive < 0.05))),
          "window_scan_summary")

message("05_window_scan: done")

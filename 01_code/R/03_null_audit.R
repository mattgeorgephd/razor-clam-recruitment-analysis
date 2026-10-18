# ═══════════════════════════════════════════════════════════════════════════════
# 03_null_audit.R — are the original notebook's "best" correlations beyond chance?
# ═══════════════════════════════════════════════════════════════════════════════
# 1. Re-implements the original monthly-resolution screening grid
#    (Max temp [IDW], BEUTI, Columbia discharge x 5 seasonal windows x lags 0-5
#     x 5 beaches x {pre-recruits, recruits}) and checks it reproduces
#    03_analyses/20260322-recruitment-analysis/excel/correlation_matrix_monthly.xlsx.
# 2. Builds a null distribution by multivariate Fourier phase randomisation of
#    the 10 response series (Prichard & Theiler 1994): each surrogate keeps every
#    series' power spectrum (trend + autocorrelation) and the cross-beach
#    correlation, but is independent of the environment by construction.
# 3. Reports family-wise p-values for max|r| per beach x response, the null
#    distribution of the number of p<0.05 cells, BH-FDR q-values, and how the
#    20 predictors chosen for the original predictive models fare after
#    detrending and an effective-sample-size correction.
# Outputs: tables/null_audit_*.csv, figures/fig_null_audit.png

source(here::here("01_code", "R", "00_config.R"))
set.seed(SEED)

# ── 1. Rebuild original predictors (shared with 06_forecast_skill.R) ─────────
source(here::here("01_code", "R", "lib_original_grid.R"))

# ── Reproduction check against the committed notebook output ────────────────
committed <- file.path(ROOT, "03_analyses", "20260322-recruitment-analysis", "excel",
                       "correlation_matrix_monthly.xlsx")
if (file.exists(committed)) {
  cm <- read_excel(committed, sheet = "All_Beaches") %>%
    select(beach, lag, window, metric, r_pre, r_rec) %>%
    pivot_longer(c(r_pre, r_rec), names_to = "resp", values_to = "r_committed") %>%
    mutate(resp = recode(resp, r_pre = "Pre", r_rec = "Rec"))
  chk <- obs_long %>% inner_join(cm, by = c("beach", "resp", "lag", "window", "metric"))
  max_diff <- max(abs(chk$r - chk$r_committed), na.rm = TRUE)
  message("Reproduction check: ", nrow(chk), " cells matched; max |Δr| = ", signif(max_diff, 3))
  write_tab(tibble(cells_matched = nrow(chk), max_abs_diff_r = max_diff), "null_audit_reproduction_check")
}

# ── 2. Multivariate phase-randomised surrogates ─────────────────────────────
phase_surrogates <- function(Ym, nsurr) {
  n <- nrow(Ym); half <- floor((n - 1) / 2)
  mu <- colMeans(Ym); Z <- sweep(Ym, 2, mu)
  Fz <- mvfft(Z)
  map(seq_len(nsurr), function(i) {
    ph <- runif(half, 0, 2 * pi)
    rot <- rep(1 + 0i, n)
    rot[2:(half + 1)] <- exp(1i * ph)
    rot[n:(n - half + 1)] <- exp(-1i * ph)       # conjugate symmetry → real output
    S <- Re(mvfft(Fz * rot, inverse = TRUE)) / n  # same phase shift for every series
    # amplitude adjustment: restore each series' empirical distribution by ranks
    for (j in seq_len(ncol(S))) S[, j] <- sort(Ym[, j])[rank(S[, j], ties.method = "first")]
    S
  })
}
surr <- phase_surrogates(Ymat, N_SURROGATES)

null_stats <- map_dfr(seq_along(surr), function(i) {
  g <- grid_cor(surr[[i]])
  maxabs <- apply(abs(g), 1, max, na.rm = TRUE)
  nsig <- sapply(dimnames(g)[[1]], function(s) {
    pp <- r_to_p(g[s, , ], grid_n[[s]]); sum(pp < 0.05, na.rm = TRUE)
  })
  tibble(iter = i, series = names(maxabs), max_abs_r = maxabs, n_sig = nsig[names(maxabs)])
})

obs_series <- obs_long %>% group_by(series, beach, resp) %>%
  summarise(cells = sum(!is.na(r)), obs_max_abs_r = max(abs(r), na.rm = TRUE),
            obs_n_sig = sum(p < 0.05, na.rm = TRUE), .groups = "drop")

audit_series <- obs_series %>%
  left_join(null_stats %>% group_by(series) %>%
              summarise(null_max_abs_r_median = median(max_abs_r),
                        null_max_abs_r_95 = quantile(max_abs_r, .95),
                        null_n_sig_median = median(n_sig),
                        null_n_sig_95 = quantile(n_sig, .95), .groups = "drop"),
            by = "series") %>%
  rowwise() %>%
  mutate(fwer_p_max_abs_r = mean(null_stats$max_abs_r[null_stats$series == series] >= obs_max_abs_r),
         p_n_sig = mean(null_stats$n_sig[null_stats$series == series] >= obs_n_sig)) %>%
  ungroup() %>% arrange(factor(beach, BEACHES), resp)
write_tab(audit_series, "null_audit_by_series")

tot_null <- null_stats %>% group_by(iter) %>% summarise(total_sig = sum(n_sig), .groups = "drop")
audit_global <- tibble(
  cells = sum(!is.na(obs_long$r)),
  observed_sig_p05 = sum(obs_long$p < 0.05, na.rm = TRUE),
  naive_expected = 0.05 * sum(!is.na(obs_long$r)),
  null_median = median(tot_null$total_sig),
  null_95 = quantile(tot_null$total_sig, .95),
  p_global = mean(tot_null$total_sig >= sum(obs_long$p < 0.05, na.rm = TRUE)),
  bh_q05 = sum(p.adjust(obs_long$p, "BH") < 0.05, na.rm = TRUE),
  bh_q10 = sum(p.adjust(obs_long$p, "BH") < 0.10, na.rm = TRUE))
write_tab(audit_global, "null_audit_global")
write_tab(obs_long %>% mutate(q_bh = p.adjust(p, "BH")) %>% arrange(p), "null_audit_all_cells")

p_null <- null_stats %>%
  separate(series, c("beach", "resp"), sep = "\\|") %>%
  mutate(beach = factor(beach, BEACHES), resp = recode(resp, Pre = "Pre-recruits", Rec = "Recruits")) %>%
  ggplot(aes(max_abs_r)) +
  geom_histogram(binwidth = 0.02, fill = "grey70", colour = NA) +
  geom_vline(data = audit_series %>% mutate(beach = factor(beach, BEACHES),
                                            resp = recode(resp, Pre = "Pre-recruits", Rec = "Recruits")),
             aes(xintercept = obs_max_abs_r), colour = "firebrick", linewidth = 0.8) +
  facet_grid(resp ~ beach) +
  labs(x = "Largest |r| across the 90-cell screening grid (3 predictors x 5 windows x 6 lags)",
       y = "Surrogates",
       title = "Strongest correlations from the original screen versus chance",
       subtitle = paste0("Grey: ", N_SURROGATES, " phase-randomised response surrogates (same autocorrelation, ",
                         "no link to environment). Red: observed.")) +
  theme_ms(10)
save_fig(p_null, "fig_null_audit", 11, 5)

# ── 3. The 20 predictors chosen for the original predictive models ──────────
sel_file <- file.path(ROOT, "03_analyses", "20260322-recruitment-analysis", "models", "predictive_models.xlsx")
if (file.exists(sel_file)) {
  sel <- read_excel(sel_file, sheet = "Predictor_Selection") %>%
    mutate(resp = recode(recruit_type, `Pre-recruits` = "Pre", Recruits = "Rec")) %>%
    select(beach, recruit_type, resp, rank, pred_id, metric, window, lag)
  metric_map <- c(Max = "Max", BEUTI = "BEUTI", Discharge = "Discharge")
  # effective n for correlation between two AR(1)-like series (Pyper & Peterman 1998)
  n_eff <- function(x, y, n, kmax = floor(n / 5)) {
    ax <- acf(x, lag.max = kmax, plot = FALSE, na.action = na.pass)$acf[-1]
    ay <- acf(y, lag.max = kmax, plot = FALSE, na.action = na.pass)$acf[-1]
    inv <- 1 / n + (2 / n) * sum(((n - seq_len(kmax)) / n) * ax * ay)
    max(3, min(n, 1 / inv))
  }
  sel_eval <- sel %>% rowwise() %>% mutate(eval = list({
    s <- paste(beach, resp, sep = "|")
    x <- X[[beach]][[lag + 1]][, paste(metric_map[[metric]], window, sep = "_")]
    y <- Ymat[, s]; ok <- !is.na(x) & !is.na(y)
    xx <- x[ok]; yy <- y[ok]; tt <- years[ok]
    r_raw <- cor(xx, yy)
    rx <- resid(lm(xx ~ tt)); ry <- resid(lm(yy ~ tt))
    r_dt <- cor(rx, ry)
    ne <- n_eff(rx, ry, length(rx))
    tibble(n = length(xx), r_raw = r_raw, p_raw = r_to_p(r_raw, length(xx)),
           r_detrended = r_dt, p_detrended = r_to_p(r_dt, length(xx)),
           n_eff = ne, p_detrended_neff = r_to_p(r_dt, ne),
           fwer_p_series = audit_series$fwer_p_max_abs_r[audit_series$series == s])
  })) %>% ungroup() %>% unnest(eval) %>%
    select(beach, recruit_type, rank, pred_id, n, r_raw, p_raw, r_detrended, p_detrended,
           n_eff, p_detrended_neff, fwer_p_series)
  write_tab(sel_eval, "null_audit_selected_predictors")
}

message("03_null_audit: done")

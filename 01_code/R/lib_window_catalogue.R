# ═══════════════════════════════════════════════════════════════════════════════
# lib_window_catalogue.R — the environmental series and window catalogue shared
# by the exploratory scan (05) and the honest selection in the skill test (06)
# ═══════════════════════════════════════════════════════════════════════════════
# Sourced after 00_config.R. Builds, from 02_data/derived/env_monthly.csv, one
# monthly table of every candidate series (original indices plus the external
# products when fetched) and the catalogue of 1-4 month windows from January
# of the year before spawning (Y-1) to June of the response survey year. Both
# scripts must search the same catalogue, otherwise the skill test would not
# score the scan it claims to score.

catalogue_env <- function() {
  env_raw <- readr::read_csv(file.path(DERIVED, "env_monthly.csv"), show_col_types = FALSE)
  beach_keys <- gsub(" ", "_", tolower(BEACHES))
  col_or_na <- function(col) if (col %in% names(env_raw)) env_raw[[col]] else NA_real_   # (dplyr::pick exists)
  env <- env_raw %>%
    transmute(year, month,
              BEUTI = beuti_47N, CUTI = cuti_47N, `SST anomaly (buoys)` = sst_anom, PDO = pdo,
              `Columbia discharge, The Dalles` = q_cms,
              `Columbia discharge, Beaver` = col_or_na("columbia_lower_q_beaver_cms"),
              `Willamette discharge` = col_or_na("columbia_lower_q_willamette_cms"),
              `SST anomaly (OISST)` = col_or_na("oisst_anom_regional"),
              `SST anomaly (MUR, 5-beach mean)` = if (all(paste0("mur_anom_", beach_keys) %in% names(env_raw)))
                rowMeans(env_raw[paste0("mur_anom_", beach_keys)], na.rm = TRUE) else NA_real_,
              `Wind stress, alongshore (buoys)` = col_or_na("ndbc_met_tau_along_anom"),
              `Wave energy Hs^2 (buoys)` = col_or_na("ndbc_met_hs2_anom"),
              `Storm hours Hs > 4 m (buoys)` = col_or_na("ndbc_met_storm_anom")) %>%
    mutate(across(-c(year, month), ~ ifelse(is.nan(.x), NA_real_, .x)))
  vars <- names(env)[-(1:2)]
  env[, c("year", "month", vars[sapply(vars, function(v) sum(!is.na(env[[v]])) > 0)])]
}

# window catalogue: relative month k = 12*offset + month, offset -1 … last_offset
scan_windows <- function(last_offset) {
  ks <- seq(12 * -1 + 1, 12 * last_offset + 6)          # Jan(Y-1) … Jun(Y+last_offset)
  tidyr::expand_grid(start = ks, dur = 1:4) %>% mutate(end = start + dur - 1) %>% filter(end <= max(ks))
}
k_to_label <- function(k) {
  off <- floor((k - 1) / 12); m <- k - 12 * off
  paste0(month.abb[m], " ", ifelse(off == 0, "Y", ifelse(off > 0, paste0("Y+", off), paste0("Y", off))))
}

# Window means as contiguous slices of a vector indexed by absolute month
# (12 * year + month): relative month k of year class Y is element 12*Y + k.
# Returns a [year classes x windows] matrix; windows with fewer than 75% of
# their months present are NA.
window_matrix <- function(env, v, yc, win) {
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

# Every (series, window) candidate as one matrix [year classes x candidates]
window_catalogue <- function(yc, last_offset, env = catalogue_env()) {
  vars <- names(env)[-(1:2)]
  win <- scan_windows(last_offset)
  X <- do.call(cbind, lapply(vars, function(v) window_matrix(env, v, yc, win)))
  meta <- tidyr::expand_grid(var = vars, i = seq_len(nrow(win))) %>%
    mutate(start = win$start[i], end = win$end[i], dur = win$dur[i],
           window = paste(k_to_label(start), "-", k_to_label(end))) %>% select(-i)
  list(X = X, meta = meta, win = win, vars = vars)
}

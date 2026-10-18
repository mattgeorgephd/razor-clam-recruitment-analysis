# ═══════════════════════════════════════════════════════════════════════════════
# lib_env_homogenize.R — one regional anomaly series from many patchy stations
# ═══════════════════════════════════════════════════════════════════════════════
# Problem. Buoy and shore-station records on this coast start and stop at
# different times (02_data/Environmental Data/README.md). Averaging raw
# temperatures across whatever reports in a given month produces steps whenever
# the station mix changes, and even averaging *anomalies* is biased when a
# station's climatology comes from a short, non-representative period (a buoy
# deployed in 2016 "sees" only warm years, so its anomalies are biased cold).
#
# Model. For station s, year y, month m:
#     T[s,y,m] = C[s,m] + g[s] * R[y,m] + e[s,y,m],   e ~ N(0, sigma[s]^2)
# C   station-specific climatology (12 values per station)
# R   regional anomaly common to all stations (one value per year-month),
#     centred so that its mean over `clim_years` is zero within each month
# g   optional station gain (shallow estuary gauges amplify or damp regional
#     anomalies); fixed to 1 unless gain = TRUE, in which case the mean gain
#     over `ref_stations` is normalised to 1 for identifiability
#
# Estimation: alternating least squares. Given C and g, R is the (weighted)
# mean of station anomalies; given R and g, C is the station-month mean of
# T - g*R; repeat to convergence. Missing station-months are simply absent, so
# stations with partial records are handled without bias. This is the standard
# two-way additive model used for climate-station homogenisation.
#
# Weighting. Station error variances sigma^2 are estimated ONCE, from an
# unweighted first pass, using leave-one-out-corrected residuals
# (res / (1 - 1/n_month)); they are then held fixed in a second, precision-
# weighted pass (weights g^2 / sigma^2). Re-estimating sigma inside the
# weighted loop is degenerate: the best-weighted station absorbs R, its
# residuals shrink, and its weight diverges.
#
# Uncertainty. se[y,m] = 1 / sqrt(sum_s g^2 / sigma^2) over stations reporting
# in that month (climatology uncertainty ignored; optimistic when one station
# reports).
#
# Returns a list:
#   regional  tibble(year, month, anom, se, n_stations)
#   station   tibble(station, n_months, first_year, last_year, gain, sigma)
#   clim      tibble(station, month, clim)
#   iterations (of the final pass), converged

homogenize_stations <- function(x, clim_years, stations = NULL, ref_stations = NULL,
                                weighted = TRUE, gain = FALSE,
                                min_station_months = 24, max_iter = 300, tol = 1e-4) {
  stopifnot(all(c("station", "year", "month", "value") %in% names(x)))
  x <- x[!is.na(x$value), c("station", "year", "month", "value")]
  if (!is.null(stations)) x <- x[x$station %in% stations, ]
  keep <- names(which(table(x$station) >= min_station_months))
  x <- x[x$station %in% keep, ]
  if (nrow(x) == 0) stop("homogenize_stations: no station data left after filtering")
  st <- sort(unique(x$station))
  ref_stations <- if (is.null(ref_stations)) st else intersect(ref_stations, st)
  if (length(ref_stations) == 0) ref_stations <- st

  # One ALS pass with station error sd held fixed -----------------------------
  fit_pass <- function(sigma_fixed) {
    clim <- x %>% group_by(station, month) %>% summarise(clim = mean(value), .groups = "drop")
    pars <- tibble(station = st, gain = 1) %>% inner_join(sigma_fixed, by = "station")
    R <- NULL; converged <- FALSE
    for (iter in seq_len(max_iter)) {
      a <- x %>%
        inner_join(clim, by = c("station", "month")) %>%
        inner_join(pars, by = "station") %>%
        mutate(anom = (value - clim) / gain, w = if (weighted) gain^2 / sigma^2 else 1)
      R_new <- a %>%
        group_by(year, month) %>%
        summarise(R = sum(w * anom) / sum(w), n_stations = n(), .groups = "drop") %>%
        group_by(month) %>%
        mutate(R = R - mean(R[year %in% clim_years])) %>%
        ungroup()
      if (anyNA(R_new$R)) stop("homogenize_stations: a calendar month has no data in clim_years")
      f <- x %>% inner_join(R_new, by = c("year", "month")) %>% inner_join(pars, by = "station")
      clim_new <- f %>% group_by(station, month) %>%
        summarise(clim = mean(value - gain * R), .groups = "drop")
      if (gain) {
        f <- f %>% select(-gain) %>% inner_join(clim_new, by = c("station", "month")) %>%
          mutate(dev = value - clim)
        g <- f %>% group_by(station) %>% summarise(gain = sum(dev * R) / sum(R^2), .groups = "drop")
        g$gain <- g$gain / mean(g$gain[g$station %in% ref_stations])
        pars <- pars %>% select(-gain) %>% inner_join(g, by = "station")
      }
      delta <- max(abs(clim_new$clim - clim$clim))
      if (!is.null(R)) delta <- max(delta, max(abs(R_new$R - R$R)))
      clim <- clim_new; R <- R_new
      if (delta < tol) { converged <- TRUE; break }
    }
    list(clim = clim, pars = pars, R = R, iterations = iter, converged = converged)
  }

  # Pass 1: unweighted; estimate sigma from leave-one-out-corrected residuals --
  p1 <- fit_pass(tibble(station = st, sigma = 1))
  res <- x %>%
    inner_join(p1$clim, by = c("station", "month")) %>%
    inner_join(p1$pars %>% select(station, gain), by = "station") %>%
    inner_join(p1$R, by = c("year", "month")) %>%
    mutate(res = (value - clim - gain * R) / (1 - 1 / n_stations)) %>%
    filter(n_stations > 1) %>%
    group_by(station) %>% summarise(sigma = sd(res), n_res = n(), .groups = "drop")
  sigma_hat <- tibble(station = st) %>% left_join(res, by = "station") %>%
    mutate(sigma = ifelse(is.na(sigma) | n_res < 12, median(res$sigma, na.rm = TRUE), sigma),
           sigma = pmax(sigma, 0.05)) %>% select(station, sigma)

  # Pass 2: precision-weighted with sigma fixed ------------------------------
  p2 <- if (weighted) fit_pass(sigma_hat) else p1
  pars <- p2$pars %>% select(-sigma) %>% inner_join(sigma_hat, by = "station")

  se <- x %>% inner_join(pars, by = "station") %>%
    group_by(year, month) %>%
    summarise(se = 1 / sqrt(sum(gain^2 / sigma^2)), .groups = "drop")
  regional <- p2$R %>% rename(anom = R) %>% left_join(se, by = c("year", "month")) %>%
    arrange(year, month)
  station <- x %>% group_by(station) %>%
    summarise(n_months = n(), first_year = min(year), last_year = max(year), .groups = "drop") %>%
    inner_join(pars, by = "station")

  list(regional = regional, station = station, clim = p2$clim,
       iterations = p2$iterations, converged = p2$converged && p1$converged)
}

# Leave-one-station-out check: how well does the regional series built WITHOUT
# station s reproduce that station's own anomalies? One row per station with
# the correlation, a post-hoc gain, and the RMSE.
loo_station_check <- function(x, clim_years, stations, ...) {
  purrr::map_dfr(stations, function(s) {
    others <- setdiff(stations, s)
    fit <- tryCatch(homogenize_stations(x, clim_years, stations = others, ...),
                    error = function(e) NULL)
    own <- x %>% filter(station == s) %>%
      group_by(month) %>%
      mutate(clim = mean(value[year %in% clim_years])) %>% ungroup() %>%
      mutate(anom_own = value - clim)
    if (is.null(fit)) return(tibble(station = s, n = nrow(own), r_loo = NA_real_,
                                    gain_loo = NA_real_, rmse_loo = NA_real_))
    own <- own %>% inner_join(fit$regional, by = c("year", "month"))
    if (nrow(own) < 12 || anyNA(own$anom_own)) return(tibble(station = s, n = nrow(own), r_loo = NA_real_,
                                            gain_loo = NA_real_, rmse_loo = NA_real_))
    g <- sum(own$anom_own * own$anom) / sum(own$anom^2)
    tibble(station = s, n = nrow(own), r_loo = cor(own$anom_own, own$anom),
           gain_loo = g, rmse_loo = sqrt(mean((own$anom_own - g * own$anom)^2)))
  })
}

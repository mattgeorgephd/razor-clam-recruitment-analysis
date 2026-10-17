# ═══════════════════════════════════════════════════════════════════════════════
# lib_cohort_mixture.R — separate a survey's shell lengths into year classes
# ═══════════════════════════════════════════════════════════════════════════════
# Sourced after 00_config.R. The 76 mm pre-recruit/recruit boundary is fixed
# while the surveys run from April to August, and the year-old cohort is wide:
# tracking length groups across consecutive surveys (02_cohort_diagnostics.R
# (g), tables/cohort_length_transitions.csv) shows that at the June and July
# surveys the 76-95 mm clams covary with the same survey's 25-75 mm clams
# (r = 0.73) and not with the previous survey's (r about 0.1), and that both
# groups reappear at 96-125 mm a year later (r = 0.78, 0.77) and at 126+ mm two
# years later: the year-old cohort spans about 20-95 mm, two-year-olds sit near
# 96-125 mm, and the fast part of the year-old cohort is above 76 mm at every
# beach (about half of it at the August surveys). Current-year settlers
# (10-25 mm) appear from July. This library fits, per beach-year, a normal
# mixture over the whole length range whose components are year classes, with
# the growth curve (00_config.R: MIX_K, MIX_T0, mix_length; the WDFW curve at
# the southern beaches, a slower curve estimated from year-class tracking at
# Kalaloch) as a prior on the component means: a MAP version of EM (Macdonald
# & Pitcher 1979 style mixture with growth-curve constraints). Components, with
# inc = the curve's annual increment of the year-old cohort at the survey date:
#   settler    current-year settlers (year class of the survey year); only when
#              the survey is on or after 1 July (DOY 182)
#   age1_late  late-settled or slow clams of year class Y-1 (a 20-30 mm group is
#              present at June surveys, where it cannot be current-year),
#              prior 0.45 inc below the curve
#   age1       the main year-old cohort (year class Y-1), prior at the curve
#   age1_fast  the fast-growing part of year class Y-1, prior 0.62 inc above the
#              curve (the 76-95 mm group at June surveys); only where
#              MIX_FAST_TAIL is TRUE (not at Kalaloch, where the 76-95 mm
#              clams are two-year-olds)
#   age2       two-year-olds (year class Y-2), prior at the curve, held closer
#   age3plus   three years and older, one component (the curve has flattened)
# The age-1 cohort is settler-free and equals age1_late + age1 (+ age1_fast).
# Shares of the mixture are applied to total abundance (pre-recruits +
# recruits) in 01b_cohort_separation.R, which is consistent because the
# measured clams are the census behind the abundance estimates (the measured
# share below 76 mm matches the abundance-based share at r >= 0.996).

# Normal mixture by EM with Gaussian priors on the means (MAP), means kept
# within +/- bound of the prior, and bounded SDs. The hard bound matters when a
# survey holds many thousands of lengths, where the Gaussian prior alone no
# longer restrains a component from wandering to another year class.
#   x: lengths; prior: tibble(group, mu0, tau, bound, sd0, sd_min, sd_max, w0)
mixture_map_em <- function(x, prior, iter = 400, tol = 1e-5) {
  K <- nrow(prior); n <- length(x)
  mu <- prior$mu0; sd <- prior$sd0; w <- prior$w0 / sum(prior$w0)
  ll_old <- -Inf
  for (it in seq_len(iter)) {
    dens <- sapply(seq_len(K), function(k) w[k] * dnorm(x, mu[k], sd[k]))
    dens[dens < 1e-300] <- 1e-300
    tot <- rowSums(dens); r <- dens / tot
    nk <- colSums(r)
    w <- nk / n
    # MAP update of the means: data precision nk/sd^2 against prior precision 1/tau^2
    mu <- (colSums(r * x) / sd^2 + prior$mu0 / prior$tau^2) / (nk / sd^2 + 1 / prior$tau^2)
    mu <- pmin(pmax(mu, prior$mu0 - prior$bound, 5), prior$mu0 + prior$bound)
    sd <- sqrt(colSums(r * (x - rep(mu, each = n))^2) / pmax(nk, 1e-8))
    sd <- pmin(pmax(sd, prior$sd_min), prior$sd_max)
    ll <- sum(log(tot))
    if (abs(ll - ll_old) < tol) break
    ll_old <- ll
  }
  dens <- sapply(seq_len(K), function(k) w[k] * dnorm(x, mu[k], sd[k])); dens[dens < 1e-300] <- 1e-300
  r <- dens / rowSums(dens)
  list(components = tibble::tibble(group = prior$group, mu0 = prior$mu0, mu = mu, sd = sd, w = w, n_eff = colSums(r)),
       resp = r, loglik = sum(log(rowSums(dens))), iterations = it)
}

# Prior table for one survey, from the growth curve at the survey date
cohort_prior <- function(beach, doy) {
  age1 <- 1 + (doy - SETTLE_DOY) / 365.25
  m1 <- mix_length(beach, age1); m2 <- mix_length(beach, age1 + 1); m3 <- mix_length(beach, age1 + 2.3)
  inc <- m2 - m1
  pr <- tibble::tribble(
    ~group,      ~mu0,                       ~tau, ~bound, ~sd0, ~sd_min, ~sd_max, ~w0,
    "age1_late", max(m1 - 0.45 * inc, 20),    8,    16,     6,    3,       10,      0.10,
    "age1",      m1,                          8,    16,     9,    5,       14,      0.30,
    "age1_fast", m1 + 0.62 * inc,             8,    16,     7,    4,       12,      0.15,
    "age2",      m2,                          6,    12,    10,    5,       13,      0.25,
    "age3plus",  m3,                          6,    12,     9,    5,       14,      0.20)
  if (!MIX_FAST_TAIL[[beach]]) pr <- pr[pr$group != "age1_fast", ]
  # current-year settlers: 10-27 mm at any survey from July to early September
  # (settlement continues through the summer, so the mode does not move with
  # the survey date; fitted means of the component regress on date with a slope
  # of -0.06 mm/day). Prior 18 mm, kept within 9-27 mm.
  if (doy >= 182) pr <- dplyr::bind_rows(tibble::tibble(group = "settler", mu0 = 18, tau = 4, bound = 9, sd0 = 4,
                                                        sd_min = 2.5, sd_max = 7, w0 = 0.10), pr)
  pr
}

group_of <- function(g) ifelse(g %in% c("age1", "age1_late", "age1_fast"), "age1", g)

# Fit one survey. Returns a one-row tibble of shares, boundaries, contamination
# of the 76 mm classes, fit statistics, and the component table as a list column.
cohort_mixture <- function(x, beach, doy, min_n = 80) {
  x <- x[!is.na(x) & x >= 5 & x <= 180]
  n <- length(x)
  empty <- tibble::tibble(n_lengths = n, fitted = FALSE)
  if (n < min_n || is.na(doy)) return(empty)
  pr <- cohort_prior(beach, doy)
  fit <- mixture_map_em(x, pr)
  comp <- fit$components %>% dplyr::mutate(cohort = group_of(group))
  R <- fit$resp; colnames(R) <- comp$group
  # posterior responsibility of each cohort for each clam
  P <- sapply(c("settler", "age1", "age2", "age3plus"), function(g) {
    cols <- which(comp$cohort == g); if (length(cols) == 0) rep(0, n) else rowSums(R[, cols, drop = FALSE]) })
  shares <- colMeans(P)
  pre <- x <= 75.5
  # where does one cohort hand over to the next? first length (1 mm grid) above
  # the lower cohort's mean at which the upper cohort's posterior exceeds it
  grid <- seq(5, 180, by = 1)
  dg <- sapply(seq_len(nrow(comp)), function(k) comp$w[k] * dnorm(grid, comp$mu[k], comp$sd[k]))
  Pg <- sapply(c("settler", "age1", "age2", "age3plus"), function(g) {
    cols <- which(comp$cohort == g); if (length(cols) == 0) rep(0, length(grid)) else rowSums(dg[, cols, drop = FALSE]) })
  Pg <- Pg / pmax(rowSums(Pg), 1e-300)
  boundary <- function(lower, upper, from) {
    i <- which(grid >= from & Pg[, upper] > Pg[, lower])
    if (length(i) == 0) NA_real_ else grid[min(i)]
  }
  getc <- function(g, what) if (any(comp$group == g)) comp[[what]][comp$group == g] else NA_real_
  mu_age1 <- getc("age1", "mu"); mu_age2 <- getc("age2", "mu")
  b01 <- if (shares[["settler"]] > 0.005) boundary("settler", "age1", from = getc("settler", "mu")) else NA_real_
  b12 <- boundary("age1", "age2", from = if (any(comp$group == "age1_fast")) getc("age1_fast", "mu") else mu_age1)
  b23 <- boundary("age2", "age3plus", from = mu_age2)
  # goodness of fit: Kolmogorov distance between the empirical and fitted CDFs
  xs <- sort(x); F_emp <- seq_len(n) / n
  F_fit <- rowSums(sapply(seq_len(nrow(comp)), function(k) comp$w[k] * pnorm(xs, comp$mu[k], comp$sd[k])))
  ks <- max(abs(F_emp - F_fit))
  tibble::tibble(
    n_lengths = n, fitted = TRUE, settler_component = any(comp$group == "settler"),
    w_settler = shares[["settler"]], w_age1 = shares[["age1"]], w_age2 = shares[["age2"]], w_age3plus = shares[["age3plus"]],
    growth_K = unname(MIX_K[beach]), growth_t0 = unname(MIX_T0[beach]), fast_tail = unname(MIX_FAST_TAIL[beach]),
    mu_settler = getc("settler", "mu"),
    mu_age1_late = getc("age1_late", "mu"), w_age1_late = getc("age1_late", "w"),
    mu_age1_fast = getc("age1_fast", "mu"), w_age1_fast = getc("age1_fast", "w"),
    mu_age1 = mu_age1, sd_age1 = getc("age1", "sd"), mu_age2 = mu_age2, sd_age2 = getc("age2", "sd"),
    mu_age3plus = getc("age3plus", "mu"),
    prior_mu_age1 = pr$mu0[pr$group == "age1"], prior_mu_age2 = pr$mu0[pr$group == "age2"],
    boundary_settler_age1 = b01, boundary_age1_age2 = b12, boundary_age2_age3 = b23,
    # contamination of the fixed 76 mm classes
    share_age1_above_76 = sum(P[!pre, "age1"]) / max(sum(P[, "age1"]), 1e-9),
    share_age2_below_76 = sum(P[pre, "age2"]) / max(sum(P[, "age2"]), 1e-9),
    share_pre_class_settlers = sum(P[pre, "settler"]) / max(sum(pre), 1),
    share_pre_class_age1 = sum(P[pre, "age1"]) / max(sum(pre), 1),
    share_rec_class_age1 = sum(P[!pre, "age1"]) / max(sum(!pre), 1),
    share_rec_class_age2 = sum(P[!pre, "age2"]) / max(sum(!pre), 1),
    share_measured_pre = mean(pre),
    loglik = fit$loglik, ks = ks, iterations = fit$iterations,
    components = list(comp))
}

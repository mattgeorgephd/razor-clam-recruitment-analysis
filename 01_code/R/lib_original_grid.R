# ═══════════════════════════════════════════════════════════════════════════════
# lib_original_grid.R — re-implementation of the original notebook's monthly
# screening grid (used by 03_null_audit.R and 06_forecast_skill.R)
# ═══════════════════════════════════════════════════════════════════════════════
# Reproduces Sections 4a, 7 and 8 of the v7 notebook for the active metrics
# (Max temp, BEUTI, Discharge) at monthly resolution, INCLUDING its quirks
# (IDW of raw temperatures across changing stations; BEUTI/discharge left-joined
# onto the temperature table). 03_null_audit.R verifies |Δr| < 0.001 against
# the committed correlation_matrix_monthly.xlsx.
# Creates in the calling environment: X (beach → list of lag matrices),
# Ymat (years x 10 response series), years, preds, LAGS, grid_cor(), grid_n,
# r_to_p(), obs_long.

# ── 1. Rebuild original predictors (monthly timescale) ──────────────────────
hav <- function(lat1, lon1, lat2, lon2) {
  p1 <- lat1 * pi / 180; p2 <- lat2 * pi / 180
  a <- sin((lat2 - lat1) * pi / 360)^2 + cos(p1) * cos(p2) * sin((lon2 - lon1) * pi / 360)^2
  2 * 6371 * asin(sqrt(a))
}
bc <- tibble(beach = c("Long Beach", "Twin Harbors", "Copalis", "Mocrocks", "Kalaloch"),
             blat  = c(46.361592, 46.855477, 47.133586, 47.238914, 47.606156),
             blon  = c(-124.069805, -124.118770, -124.195585, -124.219583, -124.380790))
stations <- read_excel(file.path(ENV_DIR, "Station Names.xlsx"), sheet = "data")
wm <- read_excel(file.path(ENV_DIR, "monthly_wtmp_summary.xlsx"), sheet = "data") %>%
  mutate(year = as.numeric(year), month = as.numeric(month)) %>%
  left_join(stations, by = "station")

dist <- bc %>% cross_join(wm %>% filter(!is.na(latitude)) %>% distinct(station, latitude, longitude)) %>%
  mutate(d = hav(blat, blon, latitude, longitude)) %>% select(beach, station, d)

wi <- wm %>% select(station, year, month, wtmp_mean, wtmp_max) %>%
  inner_join(dist, by = "station", relationship = "many-to-many") %>%
  filter(!is.na(wtmp_mean), d <= 50) %>%
  mutate(w = 1 / d^3) %>%
  group_by(beach, year, month) %>%
  summarise(at_max = weighted.mean(wtmp_max, w), .groups = "drop")

beuti_m <- read_csv(file.path(ENV_DIR, "BEUTI_daily.csv"), show_col_types = FALSE) %>%
  pivot_longer(c(`46N`, `47N`), names_to = "lat_bin", values_to = "beuti") %>%
  group_by(lat_bin, year, month) %>% summarise(beuti = mean(beuti, na.rm = TRUE), .groups = "drop") %>%
  inner_join(tibble(beach = names(BEACH_LAT_BIN), lat_bin = unname(BEACH_LAT_BIN)),
             by = "lat_bin", relationship = "many-to-many")

q_m <- read_csv(file.path(ENV_DIR, "columbia_discharge.csv"), show_col_types = FALSE) %>%
  group_by(year, month) %>%
  summarise(q_mean = mean(discharge_cms, na.rm = TRUE), n = n(), .groups = "drop") %>%
  filter(n >= 15) %>% select(-n)

windows <- list(Spring = 3:5, Spawn = 5:6, Larval = 6:7, Settle = 7:8, Growth = 9:10)
# NOTE: the original notebook's merge_all_predictors() LEFT-joins BEUTI and
# discharge onto the IDW temperature table, so BEUTI/discharge are silently
# dropped for every beach-month without buoy temperature (task.md, bug B3).
# We replicate that here so the audit evaluates exactly the original grid.
long_env <- wi %>% left_join(beuti_m %>% select(beach, year, month, beuti), by = c("beach", "year", "month")) %>%
  left_join(q_m, by = c("year", "month"))

ti <- map_dfr(names(windows), function(w) {
  long_env %>% filter(month %in% windows[[w]]) %>%
    group_by(beach, year) %>%
    summarise(Max = mean(at_max, na.rm = TRUE), BEUTI = mean(beuti, na.rm = TRUE),
              Discharge = mean(q_mean, na.rm = TRUE), .groups = "drop") %>%
    mutate(window = w)
}) %>%
  mutate(across(c(Max, BEUTI, Discharge), ~ ifelse(is.nan(.x), NA_real_, .x))) %>%
  pivot_longer(c(Max, BEUTI, Discharge), names_to = "metric") %>%
  mutate(pred = paste(metric, window, sep = "_"))

survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE) %>%
  filter(!is.na(pre_recruits)) %>%
  transmute(beach, sy = survey_year, Pre = log1p(pre_recruits), Rec = log1p(recruits))
years <- sort(unique(survey$sy))
preds <- sort(unique(ti$pred))
LAGS <- 0:5

# X[[beach]][[lag+1]] = years x predictors matrix aligned to survey years
X <- map(set_names(BEACHES), function(b) {
  map(LAGS, function(lg) {
    ti %>% filter(beach == b) %>% mutate(sy = year + lg) %>%
      select(sy, pred, value) %>%
      pivot_wider(names_from = pred, values_from = value) %>%
      right_join(tibble(sy = years), by = "sy") %>% arrange(sy) %>%
      select(all_of(preds)) %>% as.matrix()
  })
})
Y <- survey %>% pivot_longer(c(Pre, Rec), names_to = "resp") %>%
  mutate(series = paste(beach, resp, sep = "|")) %>%
  select(sy, series, value) %>% pivot_wider(names_from = series, values_from = value) %>%
  arrange(sy)
stopifnot(identical(Y$sy, years))
Ymat <- as.matrix(Y[, -1])

# Correlation grid for a full response matrix → array [series, lag, predictor]
grid_cor <- function(Ym) {
  out <- array(NA_real_, c(ncol(Ym), length(LAGS), length(preds)),
               dimnames = list(colnames(Ym), LAGS, preds))
  for (s in colnames(Ym)) {
    b <- str_split_fixed(s, "\\|", 2)[1]
    for (li in seq_along(LAGS)) {
      Xb <- X[[b]][[li]]
      ok <- colSums(!is.na(Xb)) > 4
      out[s, li, ok] <- suppressWarnings(cor(Xb[, ok, drop = FALSE], Ym[, s], use = "pairwise.complete.obs"))
    }
  }
  out
}
grid_n <- map(set_names(colnames(Ymat)), function(s) {
  b <- str_split_fixed(s, "\\|", 2)[1]
  t(sapply(seq_along(LAGS), function(li) colSums(!is.na(X[[b]][[li]]))))
})
r_to_p <- function(r, n) { t <- r * sqrt((n - 2) / (1 - r^2)); 2 * pt(-abs(t), n - 2) }

obs <- grid_cor(Ymat)
obs_long <- as.data.frame.table(obs, responseName = "r") %>%
  as_tibble() %>%
  rename(series = Var1, lag = Var2, pred = Var3) %>%
  mutate(lag = as.integer(as.character(lag)), series = as.character(series), pred = as.character(pred)) %>%
  separate(series, c("beach", "resp"), sep = "\\|", remove = FALSE) %>%
  separate(pred, c("metric", "window"), sep = "_", remove = FALSE) %>%
  rowwise() %>% mutate(n = grid_n[[series]][lag + 1, pred]) %>% ungroup() %>%
  mutate(p = r_to_p(r, n))


# ═══════════════════════════════════════════════════════════════════════════════
# fetch_ndbc_met.R — buoy winds, waves and pressure: local upwelling and storm indices
# ═══════════════════════════════════════════════════════════════════════════════
# The dataset (cwwcNDBCMet on the CoastWatch ERDDAP) is the one
# 02_data/Environmental Data/Wtmp_salt.R already uses for water temperature.
# Field names are upper case on the server (WD, WSPD, WVHT, DPD, BAR); they are
# renamed to lower case after download.
#
# Why: (1) an upwelling index computed from measured winds at 46-47N is
# independent of the ROMS-derived BEUTI/CUTI product and tests its trend;
# (2) winter wave energy and storm hours address the first-winter washout
# hypothesis (small clams displaced by surf) with a direct measurement.
# Stations are combined with the same homogenisation model as temperature
# (lib_env_homogenize.R), so station switches do not create steps.
#
# Output: 02_data/Environmental Data/external/ndbc_met_monthly.csv with
#   year, month,
#   tau_along_anom      alongshore wind-stress anomaly (N m-2; + = equatorward = upwelling-favourable)
#   <var>_clim          station-mean monthly climatology of each variable (same units), so that
#                       anomaly + clim is an absolute value
#   ekman_anom          offshore Ekman transport anomaly (m2 s-1), tau_along / (rho_w f)
#   hs_anom             significant-wave-height anomaly (m)
#   hs2_mean            mean of Hs^2 (energy proxy), station-homogenised anomaly
#   storm_hours_anom    anomaly of the share of hours with Hs > 4 m
#   n_stations_wind, n_stations_wave

suppressPackageStartupMessages({ library(tidyverse); library(rerddap); library(here) })
source(here("01_code", "R", "00_config.R"))
source(here("01_code", "R", "lib_env_homogenize.R"))

ERDDAP  <- "https://coastwatch.pfeg.noaa.gov/erddap/"
DATASET <- "cwwcNDBCMet"
EXT_DIR <- file.path(ENV_DIR, "external"); RAW_DIR <- file.path(EXT_DIR, "raw")
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)
STATIONS <- c("46029", "46041", "46211", "46099", "46100", "46248")   # open-coast set
COAST_ANGLE_DEG <- 10     # coastline orientation clockwise from north (WA coast runs ~NNE-SSW); verify
CLIM_YEARS <- 1991:2024

info <- rerddap::info(DATASET, url = ERDDAP)
raw <- map_dfr(STATIONS, function(s) {
  f <- file.path(RAW_DIR, sprintf("ndbc_met_%s.rds", s))
  if (file.exists(f)) return(readRDS(f))
  d <- tryCatch(rerddap::tabledap(info, fields = c("station", "time", "WD", "WSPD", "WVHT", "DPD", "BAR"),
                                  sprintf('station="%s"', s), "time>=1990-01-01"),
                error = function(e) { message("  ", s, ": ", conditionMessage(e)); NULL })
  if (is.null(d)) { message("  ", s, ": download failed"); return(NULL) }
  d <- as_tibble(d) %>% rename(wd = WD, wspd = WSPD, wvht = WVHT, dpd = DPD, pres = BAR) %>%
    mutate(across(c(wd, wspd, wvht, dpd, pres), as.numeric),
           time = as.POSIXct(time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  saveRDS(d, f); message("  ", s, ": ", nrow(d), " records"); d
})

# ── Wind stress (Large & Pond 1981 drag) and Ekman transport ────────────────
rho_air <- 1.22; rho_w <- 1025
cd <- function(u) ifelse(u < 11, 1.2e-3, (0.49 + 0.065 * u) * 1e-3)
f_cor <- 2 * 7.2921e-5 * sin(46.9 * pi / 180)
theta <- COAST_ANGLE_DEG * pi / 180
hourly <- raw %>% filter(!is.na(wspd), !is.na(wd)) %>%
  mutate(u = -wspd * sin(wd * pi / 180), v = -wspd * cos(wd * pi / 180),   # wd = direction FROM
         tau_x = rho_air * cd(wspd) * wspd * u, tau_y = rho_air * cd(wspd) * wspd * v,
         # alongshore axis pointing equatorward (south) rotated by the coast angle
         tau_along = -(tau_y * cos(theta) + tau_x * sin(theta)),
         ekman_offshore = tau_along / (rho_w * f_cor),
         year = year(time), month = month(time))
wind_m <- hourly %>% group_by(station, year, month) %>%
  summarise(tau_along = mean(tau_along), ekman = mean(ekman_offshore), n = n(), .groups = "drop") %>%
  filter(n >= 240)
wave_m <- raw %>% filter(!is.na(wvht), wvht < 30) %>% mutate(year = year(time), month = month(time)) %>%
  group_by(station, year, month) %>%
  summarise(hs = mean(wvht), hs2 = mean(wvht^2), storm = mean(wvht > 4), n = n(), .groups = "drop") %>%
  filter(n >= 240)

homog <- function(d, col) {
  fit <- homogenize_stations(d %>% transmute(station, year, month, value = .data[[col]]), CLIM_YEARS,
                             min_station_months = SST_MIN_STATION_MONTHS)
  # station-mean climatology is kept so that anomalies and trends can be read
  # relative to the seasonal mean (e.g. a trend as a share of the May-Aug mean)
  clim <- fit$clim %>% group_by(month) %>% summarise(clim = mean(clim), .groups = "drop")
  fit$regional %>% left_join(clim, by = "month") %>%
    transmute(year, month, !!paste0(col, "_anom") := anom, !!paste0(col, "_clim") := clim,
              !!paste0("n_", col) := n_stations)
}
out <- homog(wind_m, "tau_along") %>%
  full_join(homog(wind_m, "ekman"), by = c("year", "month")) %>%
  full_join(homog(wave_m, "hs"), by = c("year", "month")) %>%
  full_join(homog(wave_m, "hs2"), by = c("year", "month")) %>%
  full_join(homog(wave_m, "storm"), by = c("year", "month")) %>%
  arrange(year, month)
write_csv(out, file.path(EXT_DIR, "ndbc_met_monthly.csv"))
write_csv(bind_rows(wind_m %>% mutate(kind = "wind"), wave_m %>% mutate(kind = "wave")) %>%
            group_by(kind, station) %>% summarise(first = min(year), last = max(year), months = n(), .groups = "drop"),
          file.path(EXT_DIR, "ndbc_met_stations.csv"))
writeLines(c(paste("NDBC standard met via", ERDDAP, "dataset", DATASET), paste("stations", paste(STATIONS, collapse = ", ")),
             paste("downloaded", Sys.Date()), paste("coast angle deg", COAST_ANGLE_DEG),
             paste("rerddap", as.character(packageVersion("rerddap"))),
             paste("md5 ndbc_met_monthly.csv", tools::md5sum(file.path(EXT_DIR, "ndbc_met_monthly.csv")))),
           file.path(EXT_DIR, "ndbc_met_provenance.txt"))
message("fetch_ndbc_met: wrote ", nrow(out), " rows")

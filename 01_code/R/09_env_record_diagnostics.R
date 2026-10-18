# ═══════════════════════════════════════════════════════════════════════════════
# 09_env_record_diagnostics.R — how patchy is the environmental record, and
# does the patchwork matter?
# ═══════════════════════════════════════════════════════════════════════════════
# Companion to docs/environmental-record-options.md. Everything here uses the
# cached inputs in 02_data/Environmental Data (and, for F-H, the external
# products already fetched there); nothing is downloaded.
#
# (A) Coverage of every environmental source by year-month (fig_env_coverage,
#     env_coverage_by_station, env_coverage_by_year)
# (B) The legacy notebook's IDW beach temperature series, rebuilt, versus the
#     homogenised regional anomaly: step changes at station switches
#     (fig_legacy_idw_vs_homogenized, env_legacy_idw_station_eras)
# (C) Alternative constructions of the regional SST anomaly and their effect on
#     the pre-specified SST test (fig_sst_homogenization, env_sst_variants,
#     env_sst_variant_effects)
# (D) Station parameters of the all-station model with leave-one-station-out
#     checks (env_sst_station_parameters)
# (E) BEUTI / CUTI homogeneity: level shift at the 2010/2011 reanalysis boundary,
#     best single breakpoint, latitude x period means, cross-index correlations
#     (fig_beuti_homogeneity, env_beuti_step_tests, env_beuti_latitude_periods,
#     env_index_annual_correlations)
# Sections F-H run only when the corresponding external products exist in
# 02_data/Environmental Data/external/ (fetched by 01_code/R/acquire/):
# (F) Index vintages: the cached BEUTI/CUTI/PDO snapshots against the current
#     server files, and the pre-specified BEUTI and PDO tests refitted under each
#     (fig_index_vintages, env_index_vintages, env_index_vintage_effects)
# (G) Satellite SST (OISST, MUR) against the buoy constructions: added to the
#     variant table of (C), per-beach agreement, north-south coherence, and
#     beach-specific SST effects (env_satellite_vs_buoy)
# (H) Buoy-measured wind stress and waves against BEUTI/CUTI (trend and
#     interannual agreement), and lower-Columbia gauges against The Dalles
#     (fig_wind_vs_upwelling, env_wind_vs_upwelling, env_discharge_gauges)

source(here::here("01_code", "R", "00_config.R"))
source(here::here("01_code", "R", "lib_env_homogenize.R"))
suppressPackageStartupMessages(library(lme4))

env      <- read_csv(file.path(DERIVED, "env_monthly.csv"), show_col_types = FALSE)
stations <- read_excel(file.path(ENV_DIR, "Station Names.xlsx"), sheet = "data") %>%
  mutate(station = as.character(station))
wm_all   <- read_excel(file.path(ENV_DIR, "monthly_wtmp_summary.xlsx"), sheet = "data") %>%
  mutate(station = as.character(station), year = as.integer(year), month = as.integer(month))
sst_station <- wm_all %>% filter(n_obs >= SST_MIN_HOURLY_OBS) %>%
  transmute(station, year, month, value = wtmp_mean)
ym_date <- function(y, m) as.Date(sprintf("%d-%02d-15", y, m))

bc <- tibble(beach = c("Long Beach", "Twin Harbors", "Copalis", "Mocrocks", "Kalaloch"),
             blat  = c(46.361592, 46.855477, 47.133586, 47.238914, 47.606156),
             blon  = c(-124.069805, -124.118770, -124.195585, -124.219583, -124.380790))
hav <- function(lat1, lon1, lat2, lon2) {
  p1 <- lat1 * pi / 180; p2 <- lat2 * pi / 180
  a <- sin((lat2 - lat1) * pi / 360)^2 + cos(p1) * cos(p2) * sin((lon2 - lon1) * pi / 360)^2
  2 * 6371 * asin(sqrt(a))
}
st_coords <- stations %>% filter(!is.na(latitude)) %>% select(station, short_name, latitude, longitude)
dist <- cross_join(bc, st_coords) %>%
  mutate(d = hav(blat, blon, latitude, longitude)) %>% select(beach, station, d)
nearest <- dist %>% group_by(station) %>% slice_min(d, n = 1, with_ties = FALSE) %>%
  ungroup() %>% rename(nearest_beach = beach, nearest_km = d)

# ═══ (A) Coverage ════════════════════════════════════════════════════════════
class_of <- function(s) { cl <- STATION_CLASS[s]; ifelse(is.na(cl), "other", cl) }
label_of <- function(s) {
  nm <- st_coords$short_name[match(s, st_coords$station)]
  ifelse(is.na(nm), s, paste0(s, " ", nm))
}
cov_temp <- wm_all %>%
  transmute(series = label_of(station), station, class = paste("temperature:", class_of(station)),
            year, month, status = ifelse(n_obs >= SST_MIN_HOURLY_OBS, "full month", "partial month"))
cov_salt <- read_excel(file.path(ENV_DIR, "DailySalt.xlsx"), sheet = "data") %>%
  mutate(date = as.Date(Date), year = year(date), month = month(date)) %>%
  count(station, year, month) %>%
  transmute(series = station, station, class = "salinity (OOI moorings)", year, month,
            status = ifelse(n >= 10, "full month", "partial month"))
cov_idx <- env %>% select(year, month, beuti_47N, cuti_47N, q_cms, pdo) %>%
  pivot_longer(-c(year, month)) %>% filter(!is.na(value)) %>%
  transmute(series = recode(name, beuti_47N = "BEUTI 47N", cuti_47N = "CUTI 47N",
                            q_cms = "Columbia discharge", pdo = "PDO"),
            station = series, class = "indices", year, month, status = "full month")
# external products (acquire/): shown when present
EXT_SERIES <- c(oisst_anom_regional = "OISST regional (satellite)", mur_anom_copalis = "MUR Copalis (satellite)",
                ndbc_met_tau_along_anom = "NDBC wind stress (buoys)", ndbc_met_hs_anom = "NDBC wave height (buoys)",
                columbia_lower_q_beaver_cms = "Columbia at Beaver (USGS)", upwelling_beuti_47N = "BEUTI 47N, current vintage")
ext_present <- intersect(names(EXT_SERIES), names(env))
cov_ext <- if (length(ext_present)) env %>% select(year, month, all_of(ext_present)) %>%
  pivot_longer(-c(year, month)) %>% filter(!is.na(value)) %>%
  transmute(series = EXT_SERIES[name], station = series, class = "external products", year, month,
            status = "full month") else NULL
cov <- bind_rows(cov_idx, cov_ext, cov_temp, cov_salt) %>%
  mutate(date = ym_date(year, month),
         class = factor(class, levels = c("indices", "external products", "temperature: open coast",
                                          "temperature: river mouth", "temperature: estuary/harbor",
                                          "temperature: other", "salinity (OOI moorings)")))
series_order <- cov %>% group_by(class, series) %>% summarise(first = min(date), .groups = "drop") %>%
  arrange(class, first) %>% pull(series)
cov <- cov %>% mutate(series = factor(series, levels = rev(unique(series_order))))

p_cov <- ggplot(cov, aes(date, series, fill = class, alpha = status)) +
  geom_tile(height = 0.8) +
  annotate("rect", xmin = as.Date("1997-01-01"), xmax = as.Date("2024-12-31"),
           ymin = -Inf, ymax = Inf, fill = NA, colour = "grey30", linetype = 2) +
  scale_alpha_manual(values = c(`full month` = 1, `partial month` = 0.35), name = NULL) +
  scale_fill_brewer(palette = "Dark2", guide = "none") +
  scale_x_date(date_breaks = "5 years", date_labels = "%Y", limits = as.Date(c("1988-01-01", "2026-06-30"))) +
  facet_grid(class ~ ., scales = "free_y", space = "free_y", switch = "y") +
  labs(x = NULL, y = NULL, title = "Coverage of the environmental record by month",
       subtitle = paste0("Full month = >= ", SST_MIN_HOURLY_OBS, " hourly obs (temperature) or >= 10 days (salinity).\n",
                         "Dashed box = clam survey period 1997-2024.")) +
  theme_ms(9) + theme(strip.text.y.left = element_text(angle = 0, hjust = 1, size = 8),
                      strip.placement = "outside", legend.position = "bottom",
                      axis.text.y = element_text(size = 7))
save_fig(p_cov, "fig_env_coverage", 11, 8)

months_1997_2024 <- 28 * 12
cov_station <- cov %>% filter(!class %in% c("indices", "external products")) %>%
  group_by(series, station, class) %>%
  summarise(first_year = min(year), last_year = max(year),
            months_full = sum(status == "full month"), months_partial = sum(status == "partial month"),
            share_1997_2024_full = sum(status == "full month" & year %in% 1997:2024) / months_1997_2024,
            .groups = "drop") %>%
  left_join(st_coords %>% select(station, latitude, longitude), by = "station") %>%
  left_join(nearest, by = "station") %>%
  mutate(in_regional_sst = station %in% SST_OPEN_COAST & months_full >= SST_MIN_STATION_MONTHS,
         nearest_km = round(nearest_km, 1)) %>%
  arrange(class, first_year)
write_tab(cov_station, "env_coverage_by_station")

cov_year <- env %>% filter(year %in% 1988:2025) %>% group_by(year) %>%
  summarise(beuti = sum(!is.na(beuti_47N)), cuti = sum(!is.na(cuti_47N)),
            discharge = sum(!is.na(q_cms)), pdo = sum(!is.na(pdo)),
            sst_homogenised = sum(!is.na(sst_anom)), sst_naive3 = sum(!is.na(sst_anom_naive3)),
            mean_sst_stations = mean(n_sst_stations), mean_sst_se = mean(sst_anom_se, na.rm = TRUE),
            across(any_of(c(oisst = "oisst_anom_regional", mur = "mur_anom_copalis",
                            ndbc_wind = "ndbc_met_tau_along_anom", ndbc_wave = "ndbc_met_hs_anom",
                            columbia_beaver = "columbia_lower_q_beaver_cms")), ~ sum(!is.na(.x))),
            .groups = "drop")
write_tab(cov_year, "env_coverage_by_year")

# ═══ (B) Legacy IDW beach series vs homogenised anomaly ══════════════════════
# Exactly as the notebook's Section 4a: IDW (power 3) of raw monthly means from
# all stations within 50 km, no minimum number of hourly observations.
legacy <- wm_all %>% select(station, year, month, wtmp_mean) %>%
  inner_join(dist, by = "station", relationship = "many-to-many") %>%
  filter(!is.na(wtmp_mean), d <= 50) %>%
  mutate(w = 1 / d^3) %>%
  group_by(beach, year, month) %>%
  summarise(idw = weighted.mean(wtmp_mean, w), dom_stn = station[which.max(w)], n_stn = n(),
            .groups = "drop") %>%
  group_by(beach, month) %>% mutate(idw_anom = idw - mean(idw)) %>% ungroup() %>%
  left_join(env %>% select(year, month, sst_anom), by = c("year", "month")) %>%
  mutate(beach = factor(beach, BEACHES), date = ym_date(year, month),
         dom_label = label_of(dom_stn))

eras <- legacy %>% filter(!is.na(sst_anom)) %>%
  group_by(beach, dom_stn, dom_label) %>%
  summarise(n_months = n(), first_year = min(year), last_year = max(year),
            mean_diff_legacy_minus_homog = mean(idw_anom - sst_anom),
            sd_diff = sd(idw_anom - sst_anom),
            p_ttest = if (n() > 2) t.test(idw_anom - sst_anom)$p.value else NA_real_,
            .groups = "drop") %>%
  mutate(class = class_of(dom_stn)) %>% arrange(beach, first_year)
write_tab(eras, "env_legacy_idw_station_eras")

p_legacy <- ggplot(legacy, aes(date)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_line(aes(y = sst_anom), colour = "black", linewidth = 0.4, na.rm = TRUE) +
  geom_point(aes(y = idw_anom, colour = dom_label), size = 0.7) +
  facet_wrap(~ beach, ncol = 1) +
  scale_colour_brewer(palette = "Set1", name = "Dominant station in the legacy IDW blend") +
  scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
  labs(x = NULL, y = "Monthly temperature anomaly (deg C)",
       title = "Legacy station-blended beach temperature (points) vs homogenised regional anomaly (line)",
       subtitle = "Legacy anomaly = IDW blend minus its own monthly mean. Colour changes mark station switches.") +
  theme_ms(9) + guides(colour = guide_legend(nrow = 3, override.aes = list(size = 2)))
save_fig(p_legacy, "fig_legacy_idw_vs_homogenized", 10, 10)

# ═══ (C) Alternative constructions of the regional anomaly ═══════════════════
all_st <- names(which(table(sst_station$station) >= SST_MIN_STATION_MONTHS))
fit_open <- homogenize_stations(sst_station, SST_CLIM_YEARS, stations = SST_OPEN_COAST,
                                min_station_months = SST_MIN_STATION_MONTHS)
fit_all  <- homogenize_stations(sst_station, SST_CLIM_YEARS, stations = all_st, gain = TRUE,
                                ref_stations = SST_OPEN_COAST, min_station_months = SST_MIN_STATION_MONTHS)
fit_open_unw <- homogenize_stations(sst_station, SST_CLIM_YEARS, stations = SST_OPEN_COAST,
                                    weighted = FALSE, min_station_months = SST_MIN_STATION_MONTHS)

# V3: beach-local IDW of homogenised station anomalies (all stations, gain-adjusted)
st_anom <- sst_station %>% filter(station %in% fit_all$station$station) %>%
  inner_join(fit_all$clim, by = c("station", "month")) %>%
  inner_join(fit_all$station %>% select(station, gain, sigma), by = "station") %>%
  mutate(anom = (value - clim) / gain)
beach_local <- st_anom %>% inner_join(dist, by = "station", relationship = "many-to-many") %>%
  filter(d <= 100) %>%
  mutate(w = 1 / d^2 / sigma^2) %>%
  group_by(beach, year, month) %>%
  summarise(anom_local = sum(w * anom) / sum(w), n_stn = n(), .groups = "drop")

variants <- env %>% transmute(year, month, date = ym_date(year, month),
                              `V0 naive 3 buoys` = sst_anom_naive3,
                              `V1 homogenised open coast (pipeline)` = sst_anom, se_v1 = sst_anom_se) %>%
  left_join(fit_all$regional %>% transmute(year, month, `V2 homogenised all stations + gain` = anom),
            by = c("year", "month")) %>%
  left_join(fit_open_unw$regional %>% transmute(year, month, `V1u open coast unweighted` = anom),
            by = c("year", "month")) %>%
  left_join(beach_local %>% group_by(year, month) %>%
              summarise(`V3 beach-local IDW of station anomalies (mean of 5)` = mean(anom_local), .groups = "drop"),
            by = c("year", "month")) %>%
  filter(year %in% 1990:2025)
# Satellite products, when fetched (acquire/fetch_oisst.R, fetch_mur.R). Their
# anomalies are relative to their own climatologies (OISST 1991-2020, MUR
# 2003-2020), so the comparison is about variability, not level.
beach_keys <- gsub(" ", "_", tolower(BEACHES))
if ("oisst_anom_regional" %in% names(env)) {
  oi <- env %>% transmute(year, month, `V4 OISST regional, 0.25 deg satellite` = oisst_anom_regional,
                          oisst_beach_mean = rowMeans(across(any_of(paste0("oisst_anom_", beach_keys))), na.rm = TRUE))
  variants <- variants %>% left_join(oi, by = c("year", "month"))
}
if (any(grepl("^mur_anom_", names(env)))) {
  mu <- env %>% transmute(year, month, `V5 MUR nearshore 1 km satellite, mean of 5 beaches` =
                            rowMeans(across(all_of(paste0("mur_anom_", beach_keys))), na.rm = TRUE)) %>%
    mutate(across(-c(year, month), ~ ifelse(is.nan(.x), NA_real_, .x)))
  variants <- variants %>% left_join(mu, by = c("year", "month"))
}
vcols <- names(variants)[grepl("^V", names(variants))]

annual <- function(df, col, months = 5:9) df %>% filter(month %in% months) %>%
  group_by(year) %>% summarise(v = if (sum(!is.na(.data[[col]])) >= 4) mean(.data[[col]], na.rm = TRUE) else NA_real_,
                               .groups = "drop")
v1_month <- variants$`V1 homogenised open coast (pipeline)`
v1_ann   <- annual(variants, "V1 homogenised open coast (pipeline)")
var_tab <- map_dfr(vcols, function(v) {
  x <- variants[[v]]; ok <- !is.na(x) & !is.na(v1_month)
  a <- annual(variants, v) %>% inner_join(v1_ann, by = "year", suffix = c("", "_v1"))
  tibble(variant = v,
         months_available_1990_2025 = sum(!is.na(x)),
         months_available_1997_2024 = sum(!is.na(x) & variants$year %in% 1997:2024),
         r_vs_V1_monthly = cor(x[ok], v1_month[ok]),
         rmse_vs_V1_monthly = sqrt(mean((x[ok] - v1_month[ok])^2)),
         r_vs_V1_annual_MaySep = cor(a$v, a$v_v1, use = "complete.obs"))
})
write_tab(var_tab, "env_sst_variants")

# Effect of the May-Sep SST predictor on the pre-recruit year-class index under
# each construction (coastwide GLS-AR(1), as in 04_confirmatory_models.R).
cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE)
idx_pre <- cohort %>% filter(!is.na(log_pre_next), !is.na(log_spawners), !is.na(doy_next)) %>%
  group_by(beach) %>% mutate(res = zs(resid(lm(log_pre_next ~ log_spawners + doy_next)))) %>%
  ungroup() %>% group_by(year_class) %>% summarise(index = mean(res), .groups = "drop")
coast_effect <- function(pred) {   # pred: tibble(year, v)
  d <- idx_pre %>% inner_join(pred, by = c("year_class" = "year")) %>% drop_na() %>%
    mutate(x = zs(v), trend = (year_class - 2010) / 10)
  f <- tryCatch(gls(index ~ trend + x, data = d, correlation = corAR1(form = ~ year_class), method = "REML"),
                error = function(e) gls(index ~ trend + x, data = d, method = "REML"))
  tt <- summary(f)$tTable
  tibble(n_year_classes = nrow(d), estimate = tt["x", 1], se = tt["x", 2], p = tt["x", 4])
}
eff_tab <- map_dfr(vcols, function(v) bind_cols(tibble(variant = v), coast_effect(annual(variants, v))))
# beach-specific V3 in the pooled mixed model (beach-level predictor)
bl <- beach_local %>% filter(month %in% 5:9) %>% group_by(beach, year) %>%
  summarise(v = if (n() >= 4) mean(anom_local) else NA_real_, .groups = "drop")
d_bl <- cohort %>% inner_join(bl, by = c("beach", "year_class" = "year")) %>%
  filter(!is.na(log_pre_next), !is.na(log_spawners), !is.na(doy_next), !is.na(v)) %>%
  group_by(beach) %>% mutate(spawn_c = log_spawners - mean(log_spawners), doy_c = doy_next - mean(doy_next)) %>%
  ungroup() %>% mutate(x = zs(v), trend = (year_class - 2010) / 10, yc = factor(year_class),
                       beach = factor(beach, BEACHES))
m0 <- lmer(log_pre_next ~ beach + trend + spawn_c + doy_c + (1 | yc), data = d_bl, REML = FALSE)
m1 <- update(m0, . ~ . + x)
co <- summary(m1)$coefficients["x", ]
eff_tab <- bind_rows(eff_tab, tibble(variant = "V3 beach-specific, pooled LMM (beach + trend + spawners + doy + (1|year class))",
                                     n_year_classes = n_distinct(d_bl$yc), estimate = co[["Estimate"]],
                                     se = co[["Std. Error"]], p = anova(m0, m1)$`Pr(>Chisq)`[2]))
write_tab(eff_tab, "env_sst_variant_effects")

p_var_m <- variants %>% select(date, all_of(vcols[!grepl("V1u", vcols)])) %>%
  pivot_longer(-date, names_to = "variant") %>% filter(!is.na(value)) %>%
  ggplot(aes(date, value, colour = variant)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_ribbon(data = variants %>% filter(!is.na(v1_month)),
              aes(x = date, ymin = `V1 homogenised open coast (pipeline)` - 2 * se_v1,
                  ymax = `V1 homogenised open coast (pipeline)` + 2 * se_v1),
              inherit.aes = FALSE, fill = "grey80", alpha = 0.6) +
  geom_line(linewidth = 0.4) +
  scale_colour_manual(values = c("#D55E00", "black", "#0072B2", "#009E73", "#CC79A7", "#E69F00"), name = NULL) +
  scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
  labs(x = NULL, y = "Regional SST anomaly (deg C)",
       title = paste0("Regional SST anomaly under ", sum(!grepl("V1u", vcols)), " constructions"),
       subtitle = "Grey band: +/- 2 SE of the pipeline series (V1). Series overlap closely except where few stations report.") +
  theme_ms(9) + guides(colour = guide_legend(nrow = 3))
save_fig(p_var_m, "fig_sst_homogenization", 11, 5.5)

# ═══ (D) Station parameters and leave-one-station-out check ═════════════════
loo <- loo_station_check(sst_station, SST_CLIM_YEARS, stations = all_st, gain = TRUE,
                         ref_stations = SST_OPEN_COAST, min_station_months = SST_MIN_STATION_MONTHS)
st_par <- fit_all$station %>%
  mutate(class = class_of(station), name = st_coords$short_name[match(station, st_coords$station)],
         in_regional_sst = station %in% fit_open$station$station) %>%
  left_join(nearest, by = "station") %>%
  left_join(loo %>% select(-n), by = "station") %>%
  mutate(across(c(gain, sigma, nearest_km, r_loo, gain_loo, rmse_loo), ~ round(.x, 3))) %>%
  select(station, name, class, in_regional_sst, nearest_beach, nearest_km, n_months, first_year, last_year,
         gain, sigma, r_loo, gain_loo, rmse_loo) %>%
  arrange(class, first_year)
write_tab(st_par, "env_sst_station_parameters")

# ═══ (E) BEUTI / CUTI homogeneity ════════════════════════════════════════════
# (E) uses the pipeline's vintage (INDEX_VINTAGE, as 01_build_datasets.R); the
# cached snapshot enters only in (F), where the two are compared.
primary_index_file <- function(idx) {
  if (INDEX_VINTAGE == "cached") return(file.path(ENV_DIR, paste0(idx, "_daily.csv")))
  tail(sort(list.files(file.path(ENV_DIR, "external"), sprintf("^%s_daily_\\d{4}-\\d{2}-\\d{2}\\.csv$", idx), full.names = TRUE)), 1)
}
read_idx <- function(f) read_csv(f, show_col_types = FALSE) %>%
  filter(month %in% 5:8, year <= 2025) %>%
  pivot_longer(matches("^\\d+N$"), names_to = "lat") %>%
  group_by(year, lat) %>% summarise(v = mean(value, na.rm = TRUE), n = n(), .groups = "drop") %>%
  filter(n >= 100)
beuti_ann <- read_idx(primary_index_file("BEUTI")) %>% rename(beuti = v) %>% select(-n)
cuti_ann  <- read_idx(primary_index_file("CUTI"))  %>% rename(cuti = v)  %>% select(-n)
idx_ann <- beuti_ann %>% inner_join(cuti_ann, by = c("year", "lat")) %>%
  mutate(ratio = beuti / cuti, lat_num = as.numeric(sub("N", "", lat)))

step_test <- function(d, col) {
  d <- d %>% filter(!is.na(.data[[col]])) %>% mutate(y = .data[[col]], post = as.integer(year >= 2011))
  f <- lm(y ~ year + post, data = d); co <- summary(f)$coefficients
  sse0 <- deviance(lm(y ~ year, data = d))
  scan <- map_dfr(1993:2019, function(b) tibble(b = b, sse = deviance(lm(y ~ year + I(year >= b), data = d))))
  best <- scan %>% slice_min(sse, n = 1)
  tibble(series = col, n_years = nrow(d),
         trend_per_decade = co["year", 1] * 10, trend_p = co["year", 4],
         step_2011 = co["post", 1], step_2011_se = co["post", 2], step_2011_p = co["post", 4],
         step_2011_as_share_of_mean = co["post", 1] / mean(d$y),
         best_break_year = best$b,
         best_break_F = ((sse0 - best$sse) / 1) / (best$sse / (nrow(d) - 3)),
         resid_ar1 = { r <- resid(f); cor(r[-1], r[-length(r)]) })
}
step_tab <- map_dfr(c("46N", "47N"), function(L) {
  d <- idx_ann %>% filter(lat == L)
  bind_rows(step_test(d, "beuti"), step_test(d, "cuti"), step_test(d, "ratio")) %>% mutate(lat = L, .before = 1)
})
write_tab(step_tab, "env_beuti_step_tests")

lat_per <- idx_ann %>%
  mutate(period = case_when(year <= 1998 ~ "1988-1998", year <= 2010 ~ "1999-2010", TRUE ~ "2011-2024")) %>%
  filter(year <= 2024) %>%
  group_by(lat_num, period) %>% summarise(beuti = mean(beuti), cuti = mean(cuti), .groups = "drop") %>%
  pivot_wider(names_from = period, values_from = c(beuti, cuti)) %>%
  mutate(beuti_ratio_last_to_first = `beuti_2011-2024` / `beuti_1988-1998`,
         cuti_ratio_last_to_first = `cuti_2011-2024` / `cuti_1988-1998`) %>%
  arrange(desc(lat_num))
write_tab(lat_per, "env_beuti_latitude_periods")

p_beuti <- idx_ann %>% filter(lat %in% c("46N", "47N")) %>%
  select(year, lat, BEUTI = beuti, CUTI = cuti, `BEUTI / CUTI (nitrate proxy)` = ratio) %>%
  pivot_longer(-c(year, lat)) %>%
  mutate(name = factor(name, c("BEUTI", "CUTI", "BEUTI / CUTI (nitrate proxy)"))) %>%
  ggplot(aes(year, value, colour = lat)) +
  geom_vline(xintercept = 2010.5, linetype = 2, colour = "grey40") +
  geom_line() + geom_point(size = 1) +
  facet_wrap(~ name, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c(`46N` = "#0072B2", `47N` = "#D55E00"), name = NULL) +
  labs(x = NULL, y = "May-Aug mean",
       title = paste0("Upwelling indices at 46N and 47N (", INDEX_VINTAGE, " vintage): level shift at the 2010/2011 product boundary?"),
       subtitle = "Dashed line: end of the historical reanalysis period of the source model (to verify with the index authors).") +
  theme_ms(9)
save_fig(p_beuti, "fig_beuti_homogeneity", 8, 7.5)

# Cross-index annual correlations (raw and linearly detrended), 1991-2024
ann_tab <- env %>% filter(year %in% 1991:2024) %>% group_by(year) %>%
  summarise(`BEUTI May-Aug 47N` = mean(beuti_47N[month %in% 5:8]),      # pipeline vintage (INDEX_VINTAGE)
            `CUTI May-Aug 47N` = mean(cuti_47N[month %in% 5:8]),
            `SST anomaly May-Sep` = mean(sst_anom[month %in% 5:9], na.rm = TRUE),
            `PDO May-Sep` = mean(pdo[month %in% 5:9]),
            `Discharge Apr-Jun` = mean(q_cms[month %in% 4:6]), .groups = "drop")
raw_cor <- cor(ann_tab %>% select(-year), use = "pairwise.complete.obs")
dt <- ann_tab %>% mutate(across(-year, ~ { ok <- !is.na(.x); out <- .x; out[ok] <- resid(lm(.x[ok] ~ year[ok])); out }))
dt_cor <- cor(dt %>% select(-year), use = "pairwise.complete.obs")
write_tab(bind_rows(as_tibble(raw_cor, rownames = "series") %>% mutate(type = "raw", .before = 1),
                    as_tibble(dt_cor, rownames = "series") %>% mutate(type = "detrended", .before = 1)),
          "env_index_annual_correlations")


# ═══ Shared helpers for F-H ════════════════════════════════════════════════
# Pooled mixed model of 04_confirmatory_models.R for an arbitrary predictor
# given per beach and year class: y ~ beach + trend + spawners + doy + x + (1|yc).
survey_tab <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE)
cohort_full <- cohort %>%
  left_join(survey_tab %>% transmute(beach, year_class = survey_year - 2L, doy_next2 = survey_doy),
            by = c("beach", "year_class"))
# As in 04, the predictor is z-scored over every beach x year-class row of the
# predictor table (1988-2024) before the model data are selected, so estimates
# are per SD on the same scale as confirmatory_pooled.csv.
model_rows <- function(pred, resp, years = NULL) {   # pred: tibble(beach, year, v) over 1988-2024
  doy <- if (resp == "log_pre_next") "doy_next" else "doy_next2"
  d <- cohort_full %>% inner_join(pred %>% mutate(x = zs(v)), by = c("beach", "year_class" = "year"))
  if (!is.null(years)) d <- d %>% filter(year_class %in% years)
  d %>% filter(!is.na(.data[[resp]]), !is.na(log_spawners), !is.na(.data[[doy]]), !is.na(x)) %>%
    group_by(beach) %>%
    mutate(spawn_c = log_spawners - mean(log_spawners), doy_c = .data[[doy]] - mean(.data[[doy]])) %>%
    ungroup() %>%
    mutate(y = .data[[resp]], trend = (year_class - 2010) / 10, yc = factor(year_class),
           beach = factor(beach, BEACHES))
}
lmm_effect <- function(pred, resp = "log_pre_next", years = NULL) {
  d <- model_rows(pred, resp, years)
  m0 <- lmer(y ~ beach + trend + spawn_c + doy_c + (1 | yc), data = d, REML = FALSE)
  m1 <- update(m0, . ~ . + x)
  co <- summary(m1)$coefficients["x", ]
  tibble(response = resp, n_beach_years = nrow(d), n_year_classes = n_distinct(d$yc),
         year_classes = paste(range(d$year_class), collapse = "-"),
         estimate = co[["Estimate"]], se = co[["Std. Error"]], p_lrt = anova(m0, m1)$`Pr(>Chisq)`[2])
}
# Coastwide index with GLS-AR(1), exactly as 04 (sensitivity iii): beach-wise
# standardised residuals of y ~ spawners + survey date, averaged per year class,
# against the beach-mean of the z-scored predictor.
coast_effect_04 <- function(pred, resp = "log_pre_next", years = NULL) {
  d <- model_rows(pred, resp, years) %>%
    group_by(beach) %>% mutate(res = zs(resid(lm(y ~ spawn_c + doy_c)))) %>% ungroup() %>%
    group_by(year_class) %>% summarise(index = mean(res), x = mean(x), .groups = "drop") %>%
    mutate(trend = (year_class - 2010) / 10)
  f <- tryCatch(gls(index ~ trend + x, data = d, correlation = corAR1(form = ~ year_class), method = "REML"),
                error = function(e) gls(index ~ trend + x, data = d, method = "REML"))
  tt <- summary(f)$tTable
  tibble(response = paste(resp, "coastwide index, GLS-AR(1)"), n_beach_years = NA_integer_, n_year_classes = nrow(d),
         year_classes = paste(range(d$year_class), collapse = "-"),
         estimate = tt["x", 1], se = tt["x", 2], p_lrt = tt["x", 4])
}
# window mean per beach and year class from a monthly table (year, month, value cols)
beach_window <- function(df, cols_by_lat, months = 5:8, offsets = rep(0L, length(months)), min_months = 3) {
  map_dfr(BEACHES, function(b) {
    col <- cols_by_lat[[BEACH_LAT_BIN[[b]]]]
    map_dfr(1988:2024, function(Y) {
      v <- df %>% semi_join(tibble(year = Y + offsets, month = months), by = c("year", "month")) %>% pull(all_of(col))
      tibble(beach = b, year = Y, v = if (sum(!is.na(v)) >= min_months) mean(v, na.rm = TRUE) else NA_real_)
    })
  }) %>% filter(!is.na(v))
}
ann_cor <- function(x, y, year) {   # raw and detrended correlation of two annual series
  ok <- !is.na(x) & !is.na(y); x <- x[ok]; y <- y[ok]; year <- year[ok]
  c(n = length(x), r = cor(x, y), r_detrended = cor(resid(lm(x ~ year)), resid(lm(y ~ year))))
}
trend_of <- function(x, year) { ok <- !is.na(x); f <- summary(lm(x[ok] ~ year[ok]))$coefficients
  c(trend_per_decade = f[2, 1] * 10, trend_p = f[2, 4]) }

# ═══ (F) Index vintages ════════════════════════════════════════════════════════
ext_dir <- file.path(ENV_DIR, "external")
if (all(c("upwelling_beuti_47N", "pdo_ncei") %in% names(env))) {
  # (F1) daily and annual agreement between the cached snapshot and the current files
  cur_files <- c(BEUTI = tail(sort(list.files(ext_dir, "^BEUTI_daily_\\d{4}-\\d{2}-\\d{2}\\.csv$", full.names = TRUE)), 1),
                 CUTI  = tail(sort(list.files(ext_dir, "^CUTI_daily_\\d{4}-\\d{2}-\\d{2}\\.csv$", full.names = TRUE)), 1))
  vintage_date <- sub("^.*_(\\d{4}-\\d{2}-\\d{2})\\.csv$", "\\1", cur_files[["BEUTI"]])
  idx_pair <- map_dfr(c("BEUTI", "CUTI"), function(idx) {
    cached <- read_csv(file.path(ENV_DIR, paste0(idx, "_daily.csv")), show_col_types = FALSE)
    current <- read_csv(cur_files[[idx]], show_col_types = FALSE)
    j <- inner_join(cached, current, by = c("year", "month", "day"), suffix = c("_cached", "_current"))
    map_dfr(c("46N", "47N"), function(L) {
      xc <- j[[paste0(L, "_cached")]]; xn <- j[[paste0(L, "_current")]]
      a <- j %>% filter(month %in% 5:8) %>% group_by(year) %>%
        summarise(cached = mean(.data[[paste0(L, "_cached")]]), current = mean(.data[[paste0(L, "_current")]]),
                  n = n(), .groups = "drop") %>% filter(n >= 100, year <= 2024)
      tibble(index = idx, lat = L, daily_n = sum(!is.na(xc) & !is.na(xn)),
             daily_r = cor(xc, xn, use = "complete.obs"), daily_share_changed = mean(abs(xn - xc) > 1e-3, na.rm = TRUE),
             daily_rmse = sqrt(mean((xn - xc)^2, na.rm = TRUE)),
             MayAug_r = cor(a$cached, a$current), MayAug_r_detrended = ann_cor(a$cached, a$current, a$year)[["r_detrended"]],
             MayAug_mean_cached = mean(a$cached), MayAug_mean_current = mean(a$current),
             MayAug_trend_cached = trend_of(a$cached, a$year)[["trend_per_decade"]],
             MayAug_trend_current = trend_of(a$current, a$year)[["trend_per_decade"]],
             MayAug_max_abs_diff = max(abs(a$current - a$cached)), year_max_diff = a$year[which.max(abs(a$current - a$cached))])
    })
  })
  # step tests (as in E) on the current vintage
  step_cur <- map_dfr(c("BEUTI", "CUTI"), function(idx) {
    d <- read_csv(cur_files[[idx]], show_col_types = FALSE) %>% filter(month %in% 5:8) %>%
      pivot_longer(c(`46N`, `47N`), names_to = "lat") %>% group_by(year, lat) %>%
      summarise(v = mean(value, na.rm = TRUE), n = n(), .groups = "drop") %>% filter(n >= 100, year <= 2024)
    map_dfr(c("46N", "47N"), function(L) step_test(d %>% filter(lat == L), "v") %>%
              transmute(index = idx, lat = L, step_2011_current = step_2011, step_2011_p_current = step_2011_p,
                        best_break_year_current = best_break_year))
  })
  idx_pair <- idx_pair %>% left_join(step_cur, by = c("index", "lat"))
  # PDO: cached vs NCEI vs PSL
  pdo_m <- env %>% select(year, month, ncei = pdo_ncei, psl = pdo_psl) %>%
    inner_join(read_csv(file.path(ENV_DIR, "pdo_index.csv"), show_col_types = FALSE) %>%
                 transmute(year = as.integer(year), month = if (is.numeric(month)) as.integer(month) else match(month, month.abb),
                           cached = if_else(abs(pdo) > 90, NA_real_, pdo)), by = c("year", "month")) %>%
    filter(year %in% 1950:2025)
  pdo_a <- pdo_m %>% filter(month %in% 5:9, year %in% 1996:2024) %>% group_by(year) %>%
    summarise(across(c(cached, ncei, psl), mean), .groups = "drop")
  pdo_row <- map_dfr(c("ncei", "psl"), function(src) tibble(
    index = "PDO", lat = src, daily_n = sum(!is.na(pdo_m$cached) & !is.na(pdo_m[[src]])),
    daily_r = cor(pdo_m$cached, pdo_m[[src]], use = "complete.obs"),
    daily_share_changed = mean(abs(pdo_m[[src]] - pdo_m$cached) > 0.01, na.rm = TRUE),
    daily_rmse = sqrt(mean((pdo_m[[src]] - pdo_m$cached)^2, na.rm = TRUE)),
    MayAug_r = cor(pdo_a$cached, pdo_a[[src]]), MayAug_r_detrended = ann_cor(pdo_a$cached, pdo_a[[src]], pdo_a$year)[["r_detrended"]],
    MayAug_mean_cached = mean(pdo_a$cached), MayAug_mean_current = mean(pdo_a[[src]]),
    MayAug_trend_cached = trend_of(pdo_a$cached, pdo_a$year)[["trend_per_decade"]],
    MayAug_trend_current = trend_of(pdo_a[[src]], pdo_a$year)[["trend_per_decade"]],
    MayAug_max_abs_diff = max(abs(pdo_a[[src]] - pdo_a$cached)), year_max_diff = pdo_a$year[which.max(abs(pdo_a[[src]] - pdo_a$cached))]))
  vint_tab <- bind_rows(idx_pair, pdo_row) %>%
    mutate(current_vintage = ifelse(index == "PDO", "downloaded with the indices", vintage_date), .after = lat)
  # note: for the PDO rows, "daily_*" columns are monthly and "MayAug_*" columns are May-Sep (the pdo_larval window)
  write_tab(vint_tab, "env_index_vintages")

  # (F2) the pre-specified tests under each vintage (pooled LMM of 04 and the coastwide GLS of C)
  cur_monthly <- env %>% select(year, month, beuti_46N = upwelling_beuti_46N, beuti_47N = upwelling_beuti_47N,
                                cuti_46N = upwelling_cuti_46N, cuti_47N = upwelling_cuti_47N, pdo_ncei, pdo_psl)
  # the cached vintage is read from the snapshot files themselves, so this
  # comparison is the same whichever vintage the pipeline was run with
  monthly_cached <- function(idx, name) read_csv(file.path(ENV_DIR, paste0(idx, "_daily.csv")), show_col_types = FALSE) %>%
    group_by(year, month) %>% summarise(across(c(`46N`, `47N`), mean), n = n(), .groups = "drop") %>%
    filter(n >= 20) %>% transmute(year, month, !!paste0(name, "_46N") := `46N`, !!paste0(name, "_47N") := `47N`)
  pdo_cached <- read_csv(file.path(ENV_DIR, "pdo_index.csv"), show_col_types = FALSE) %>%
    transmute(year = as.integer(year), month = if (is.numeric(month)) as.integer(month) else match(month, month.abb),
              pdo = if_else(abs(pdo) > 90, NA_real_, pdo)) %>% filter(!is.na(month))
  cached_monthly <- monthly_cached("BEUTI", "beuti") %>%
    full_join(monthly_cached("CUTI", "cuti"), by = c("year", "month")) %>%
    full_join(pdo_cached, by = c("year", "month"))
  preds <- list(
    `beuti_larval, cached` = beach_window(cached_monthly, c(`46N` = "beuti_46N", `47N` = "beuti_47N")),
    `beuti_larval, current` = beach_window(cur_monthly, c(`46N` = "beuti_46N", `47N` = "beuti_47N")),
    `cuti_winter, cached` = beach_window(cached_monthly, c(`46N` = "cuti_46N", `47N` = "cuti_47N"),
                                         months = c(11, 12, 1, 2), offsets = c(0, 0, 1, 1)),
    `cuti_winter, current` = beach_window(cur_monthly, c(`46N` = "cuti_46N", `47N` = "cuti_47N"),
                                          months = c(11, 12, 1, 2), offsets = c(0, 0, 1, 1)),
    `pdo_larval, cached` = beach_window(cached_monthly, c(`46N` = "pdo", `47N` = "pdo"), months = 5:9, offsets = rep(0, 5)),
    `pdo_larval, NCEI` = beach_window(cur_monthly, c(`46N` = "pdo_ncei", `47N` = "pdo_ncei"), months = 5:9, offsets = rep(0, 5)),
    `pdo_larval, PSL` = beach_window(cur_monthly, c(`46N` = "pdo_psl", `47N` = "pdo_psl"), months = 5:9, offsets = rep(0, 5)))
  # restrict every variant to the same year classes so vintages, not coverage, drive differences
  common_years <- reduce(purrr::map(preds, ~ unique(.x$year[.x$year %in% 1996:2024])), intersect)
  vint_eff <- imap_dfr(preds, function(pr, nm) {
    bind_rows(lmm_effect(pr, "log_pre_next", common_years), lmm_effect(pr, "log_rec_next2", common_years)) %>%
      mutate(predictor = nm, .before = 1)
  })
  vint_gls <- imap_dfr(preds, function(pr, nm) {
    coast_effect_04(pr, "log_pre_next", common_years) %>% mutate(predictor = nm, .before = 1)
  })
  write_tab(bind_rows(vint_eff, vint_gls), "env_index_vintage_effects")

  # figure: annual windows under each vintage
  f_ann <- bind_rows(
    preds[["beuti_larval, cached"]] %>% filter(beach == "Copalis") %>% transmute(year, series = "BEUTI 47N, May-Aug", vintage = "cached snapshot", v),
    preds[["beuti_larval, current"]] %>% filter(beach == "Copalis") %>% transmute(year, series = "BEUTI 47N, May-Aug", vintage = paste("server", vintage_date), v),
    preds[["cuti_winter, cached"]] %>% filter(beach == "Copalis") %>% transmute(year, series = "CUTI 47N, Nov-Feb", vintage = "cached snapshot", v),
    preds[["cuti_winter, current"]] %>% filter(beach == "Copalis") %>% transmute(year, series = "CUTI 47N, Nov-Feb", vintage = paste("server", vintage_date), v),
    preds[["pdo_larval, cached"]] %>% filter(beach == "Copalis") %>% transmute(year, series = "PDO, May-Sep", vintage = "cached snapshot", v),
    preds[["pdo_larval, NCEI"]] %>% filter(beach == "Copalis") %>% transmute(year, series = "PDO, May-Sep", vintage = "NCEI current", v),
    preds[["pdo_larval, PSL"]] %>% filter(beach == "Copalis") %>% transmute(year, series = "PDO, May-Sep", vintage = "PSL current", v)) %>%
    filter(year %in% 1988:2024)
  p_vint <- ggplot(f_ann, aes(year, v, colour = vintage)) +
    geom_line() + geom_point(size = 1) +
    facet_wrap(~ series, ncol = 1, scales = "free_y") +
    scale_colour_manual(values = c("black", "#D55E00", "#0072B2", "#009E73"), name = NULL) +
    labs(x = NULL, y = "Window mean (predictor units)",
         title = "Pre-specified predictor windows under the cached and current index vintages",
         subtitle = "BEUTI/CUTI are regenerated by their authors from an updated reanalysis; the PDO is recomputed from revised ERSST.") +
    theme_ms(9)
  save_fig(p_vint, "fig_index_vintages", 8, 8)
  message("09 (F): index vintages compared; BEUTI 47N May-Aug r(cached, current) = ",
          round(idx_pair$MayAug_r[idx_pair$index == "BEUTI" & idx_pair$lat == "47N"], 3))
} else message("09 (F): skipped (run acquire/fetch_climate_indices.R to compare index vintages)")

# ═══ (G) Satellite SST against the buoy constructions ═══════════════════════
has_oisst <- "oisst_anom_regional" %in% names(env); has_mur <- any(grepl("^mur_anom_", names(env)))
if (has_oisst || has_mur) {
  bl_m <- beach_local %>% select(beach, year, month, v3 = anom_local)
  sat_long <- map_dfr(seq_along(BEACHES), function(i) {
    b <- BEACHES[i]; k <- beach_keys[i]
    env %>% transmute(year, month, beach = b,
                      oisst = if (has_oisst && paste0("oisst_anom_", k) %in% names(env)) .data[[paste0("oisst_anom_", k)]] else NA_real_,
                      mur   = if (has_mur) .data[[paste0("mur_anom_", k)]] else NA_real_) %>%
      left_join(bl_m %>% filter(beach == b) %>% select(-beach), by = c("year", "month")) %>%
      left_join(env %>% select(year, month, v1 = sst_anom), by = c("year", "month"))
  }) %>% filter(year %in% 1990:2025)
  rr <- function(x, y) if (sum(!is.na(x) & !is.na(y)) >= 24) cor(x, y, use = "complete.obs") else NA_real_
  sat_ann <- sat_long %>% filter(month %in% 5:9) %>% group_by(beach, year) %>%
    summarise(oisst = mean(oisst), mur = mean(mur), v1 = mean(v1), .groups = "drop") %>%
    group_by(beach) %>% summarise(r_oisst_vs_V1_MaySep = rr(oisst, v1), r_mur_vs_V1_MaySep = rr(mur, v1), .groups = "drop")
  sat_beach <- sat_long %>% group_by(beach) %>%
    summarise(n_oisst = sum(!is.na(oisst)), n_mur = sum(!is.na(mur)),
              r_oisst_vs_regional_buoy_V1 = rr(oisst, v1), r_mur_vs_regional_buoy_V1 = rr(mur, v1),
              r_oisst_vs_beach_local_V3 = rr(oisst, v3), r_mur_vs_beach_local_V3 = rr(mur, v3),
              r_oisst_vs_mur = rr(oisst, mur), .groups = "drop") %>%
    left_join(sat_ann, by = "beach")
  # north-south coherence (Long Beach vs Kalaloch) in each product: is one regional SST predictor adequate?
  ns <- function(col) { w <- sat_long %>% select(year, month, beach, all_of(col)) %>%
    pivot_wider(names_from = beach, values_from = all_of(col)); rr(w$`Long Beach`, w$Kalaloch) }
  sat_beach <- bind_rows(sat_beach, tibble(beach = "Long Beach vs Kalaloch (north-south coherence)",
                                           r_oisst_vs_beach_local_V3 = ns("v3"), r_oisst_vs_mur = NA_real_,
                                           r_oisst_vs_regional_buoy_V1 = ns("oisst"), r_mur_vs_regional_buoy_V1 = ns("mur")))
  write_tab(sat_beach, "env_satellite_vs_buoy")
  # beach-specific SST effects (May-Sep of year class Y) in the pooled LMM
  sat_eff <- map_dfr(c(oisst = "oisst", mur = "mur"), function(col) {
    pr <- sat_long %>% filter(month %in% 5:9) %>% group_by(beach, year) %>%
      summarise(v = if (sum(!is.na(.data[[col]])) >= 4) mean(.data[[col]], na.rm = TRUE) else NA_real_, .groups = "drop") %>%
      filter(!is.na(v))
    if (nrow(pr) < 30) return(NULL)
    lmm_effect(pr, "log_pre_next") %>% mutate(variant = paste0(toupper(col), " beach-specific, pooled LMM (beach + trend + spawners + doy + (1|year class))"), .before = 1)
  })
  if (nrow(sat_eff)) write_tab(bind_rows(read_csv(file.path(TAB_DIR, "env_sst_variant_effects.csv"), show_col_types = FALSE),
                                         sat_eff %>% select(variant, n_year_classes, estimate, se, p = p_lrt)),
                               "env_sst_variant_effects")
  message("09 (G): satellite SST compared with buoys; MUR 5-beach mean vs V1 monthly r = ",
          round(var_tab$r_vs_V1_monthly[grepl("MUR", var_tab$variant)], 3))
} else message("09 (G): skipped (run acquire/fetch_oisst.R and fetch_mur.R)")

# ═══ (H) Buoy winds and waves vs the upwelling indices; lower-river gauges ══
if ("ndbc_met_tau_along_anom" %in% names(env)) {
  # NDBC series as absolute values (anomaly + station-mean climatology) so that
  # trends can be expressed as a share of the seasonal mean, like the indices
  w_ann <- env %>% filter(year %in% 1991:2024) %>%
    mutate(tau_abs = ndbc_met_tau_along_anom + ndbc_met_tau_along_clim, ek_abs = ndbc_met_ekman_anom + ndbc_met_ekman_clim) %>%
    group_by(year) %>%
    summarise(`wind stress, alongshore (NDBC)` = if (sum(!is.na(tau_abs[month %in% 5:8])) >= 3) mean(tau_abs[month %in% 5:8], na.rm = TRUE) else NA_real_,
              `Ekman transport (NDBC)` = if (sum(!is.na(ek_abs[month %in% 5:8])) >= 3) mean(ek_abs[month %in% 5:8], na.rm = TRUE) else NA_real_,
              `CUTI 47N, current` = if ("upwelling_cuti_47N" %in% names(env)) mean(upwelling_cuti_47N[month %in% 5:8]) else NA_real_,
              `BEUTI 47N, current` = if ("upwelling_beuti_47N" %in% names(env)) mean(upwelling_beuti_47N[month %in% 5:8]) else NA_real_,
              `SST anomaly (V1)` = mean(sst_anom[month %in% 5:8], na.rm = TRUE), .groups = "drop") %>%
    # cached vintage from the snapshot files (section E), independent of the pipeline's vintage
    left_join(idx_ann %>% filter(lat == "47N") %>% transmute(year, `CUTI 47N, cached` = cuti, `BEUTI 47N, cached` = beuti), by = "year")
  wv_ann <- env %>% mutate(wy = ifelse(month >= 11, year, year - 1L)) %>% filter(wy %in% 1991:2023, month %in% c(11, 12, 1, 2)) %>%
    mutate(hs2_abs = ndbc_met_hs2_anom + ndbc_met_hs2_clim, storm_abs = ndbc_met_storm_anom + ndbc_met_storm_clim) %>%
    group_by(year = wy) %>%
    summarise(`wave energy Hs^2, Nov-Feb (NDBC)` = if (sum(!is.na(hs2_abs)) >= 3) mean(hs2_abs, na.rm = TRUE) else NA_real_,
              `storm hours Hs > 4 m, Nov-Feb (NDBC)` = if (sum(!is.na(storm_abs)) >= 3) mean(storm_abs, na.rm = TRUE) else NA_real_,
              .groups = "drop") %>%
    left_join(read_csv(file.path(ENV_DIR, "CUTI_daily.csv"), show_col_types = FALSE) %>%
                mutate(wy = ifelse(month >= 11, year, year - 1L)) %>% filter(month %in% c(11, 12, 1, 2)) %>%
                group_by(year = wy) %>% summarise(`CUTI 47N, Nov-Feb, cached` = mean(`47N`), n = n(), .groups = "drop") %>%
                filter(n >= 100) %>% select(-n), by = "year")
  pairs <- list(c("wind stress, alongshore (NDBC)", "CUTI 47N, cached"), c("wind stress, alongshore (NDBC)", "BEUTI 47N, cached"),
                c("wind stress, alongshore (NDBC)", "CUTI 47N, current"), c("wind stress, alongshore (NDBC)", "BEUTI 47N, current"),
                c("Ekman transport (NDBC)", "CUTI 47N, cached"), c("wind stress, alongshore (NDBC)", "SST anomaly (V1)"),
                c("CUTI 47N, cached", "SST anomaly (V1)"), c("BEUTI 47N, cached", "SST anomaly (V1)"))
  wind_tab <- bind_rows(
    map_dfr(pairs, function(p) { a <- ann_cor(w_ann[[p[1]]], w_ann[[p[2]]], w_ann$year)
      tibble(season = "May-Aug", x = p[1], y = p[2], n = a[["n"]], r = a[["r"]], r_detrended = a[["r_detrended"]],
             trend_x_per_decade = trend_of(w_ann[[p[1]]], w_ann$year)[["trend_per_decade"]],
             trend_x_p = trend_of(w_ann[[p[1]]], w_ann$year)[["trend_p"]],
             trend_y_per_decade = trend_of(w_ann[[p[2]]], w_ann$year)[["trend_per_decade"]],
             trend_y_p = trend_of(w_ann[[p[2]]], w_ann$year)[["trend_p"]]) }),
    map_dfr(list(c("wave energy Hs^2, Nov-Feb (NDBC)", "CUTI 47N, Nov-Feb, cached"),
                 c("storm hours Hs > 4 m, Nov-Feb (NDBC)", "CUTI 47N, Nov-Feb, cached")), function(p) {
      a <- ann_cor(wv_ann[[p[1]]], wv_ann[[p[2]]], wv_ann$year)
      tibble(season = "Nov-Feb (winter after year class)", x = p[1], y = p[2], n = a[["n"]], r = a[["r"]], r_detrended = a[["r_detrended"]],
             trend_x_per_decade = trend_of(wv_ann[[p[1]]], wv_ann$year)[["trend_per_decade"]],
             trend_x_p = trend_of(wv_ann[[p[1]]], wv_ann$year)[["trend_p"]],
             trend_y_per_decade = trend_of(wv_ann[[p[2]]], wv_ann$year)[["trend_per_decade"]],
             trend_y_p = trend_of(wv_ann[[p[2]]], wv_ann$year)[["trend_p"]]) }))
  series_mean <- function(nm) { a <- if (nm %in% names(w_ann)) w_ann[[nm]] else wv_ann[[nm]]; mean(a, na.rm = TRUE) }
  wind_tab <- wind_tab %>% rowwise() %>%
    mutate(mean_x = series_mean(x), mean_y = series_mean(y),
           # share of the mean per decade; not meaningful for anomaly series (SST), left NA there
           trend_x_share_of_mean = ifelse(grepl("anomaly", x), NA_real_, trend_x_per_decade / mean_x),
           trend_y_share_of_mean = ifelse(grepl("anomaly", y), NA_real_, trend_y_per_decade / mean_y)) %>% ungroup()
  write_tab(wind_tab, "env_wind_vs_upwelling")
  p_wind <- w_ann %>% select(year, `wind stress, alongshore (NDBC)`, `CUTI 47N, cached`, `BEUTI 47N, cached`,
                             any_of("BEUTI 47N, current")) %>%
    pivot_longer(-year) %>% filter(!is.na(value)) %>% group_by(name) %>% mutate(z = zs(value)) %>% ungroup() %>%
    ggplot(aes(year, z, colour = name)) + geom_hline(yintercept = 0, colour = "grey70") +
    geom_line() + geom_point(size = 1) +
    scale_colour_manual(values = c("#D55E00", "#E69F00", "black", "#0072B2"), name = NULL) +
    labs(x = NULL, y = "May-Aug mean (z-score)",
         title = "Buoy-measured alongshore wind stress against the model-derived upwelling indices",
         subtitle = "Measured winds carry CUTI's interannual signal; whether they carry BEUTI's trend tests its homogeneity (env_wind_vs_upwelling.csv).") +
    theme_ms(9) + guides(colour = guide_legend(nrow = 2))
  save_fig(p_wind, "fig_wind_vs_upwelling", 9, 5)
  message("09 (H): wind stress vs CUTI 47N (cached) May-Aug r = ",
          round(wind_tab$r[wind_tab$x == "wind stress, alongshore (NDBC)" & wind_tab$y == "CUTI 47N, cached"], 3))
} else message("09 (H): skipped (run acquire/fetch_ndbc_met.R)")

if ("columbia_lower_q_beaver_cms" %in% names(env)) {
  q_ann <- env %>% filter(month %in% 4:6, year %in% 1992:2024) %>% group_by(year) %>%
    summarise(dalles_cached = mean(q_cms), dalles = mean(columbia_lower_q_dalles_cms),
              beaver = mean(columbia_lower_q_beaver_cms), willamette = mean(columbia_lower_q_willamette_cms), .groups = "drop")
  gauge_tab <- tibble(
    comparison = c("Beaver (lowest main-stem gauge) vs The Dalles, Apr-Jun", "Beaver vs The Dalles + Willamette, Apr-Jun",
                   "Willamette vs The Dalles, Apr-Jun", "The Dalles: fresh download vs cached file, Apr-Jun"),
    n_years = c(sum(!is.na(q_ann$beaver)), sum(!is.na(q_ann$beaver)), nrow(q_ann), nrow(q_ann)),
    r = c(cor(q_ann$beaver, q_ann$dalles, use = "complete.obs"), cor(q_ann$beaver, q_ann$dalles + q_ann$willamette, use = "complete.obs"),
          cor(q_ann$willamette, q_ann$dalles), cor(q_ann$dalles, q_ann$dalles_cached)),
    r_detrended = c(ann_cor(q_ann$beaver, q_ann$dalles, q_ann$year)[["r_detrended"]],
                    ann_cor(q_ann$beaver, q_ann$dalles + q_ann$willamette, q_ann$year)[["r_detrended"]],
                    ann_cor(q_ann$willamette, q_ann$dalles, q_ann$year)[["r_detrended"]],
                    ann_cor(q_ann$dalles, q_ann$dalles_cached, q_ann$year)[["r_detrended"]]),
    mean_ratio = c(mean(q_ann$beaver / q_ann$dalles, na.rm = TRUE), mean(q_ann$beaver / (q_ann$dalles + q_ann$willamette), na.rm = TRUE),
                   mean(q_ann$willamette / q_ann$dalles), mean(q_ann$dalles / q_ann$dalles_cached)))
  write_tab(gauge_tab, "env_discharge_gauges")
  message("09 (H): Beaver vs The Dalles Apr-Jun r = ", round(gauge_tab$r[1], 3))
}

message("09_env_record_diagnostics: done (open-coast fit ", fit_open$iterations, " iterations; all-station fit ",
        fit_all$iterations, " iterations, converged = ", fit_all$converged, ")")

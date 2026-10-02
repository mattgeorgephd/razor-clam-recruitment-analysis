# ═══════════════════════════════════════════════════════════════════════════════
# 09_env_record_diagnostics.R — how patchy is the environmental record, and
# does the patchwork matter?
# ═══════════════════════════════════════════════════════════════════════════════
# Companion to docs/environmental-record-options.md. Everything here uses the
# cached inputs in 02_data/Environmental Data; nothing is downloaded.
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
cov <- bind_rows(cov_idx, cov_temp, cov_salt) %>%
  mutate(date = ym_date(year, month),
         class = factor(class, levels = c("indices", "temperature: open coast",
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
cov_station <- cov %>% filter(class != "indices") %>%
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
  scale_colour_manual(values = c("#D55E00", "black", "#0072B2", "#009E73"), name = NULL) +
  scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
  labs(x = NULL, y = "Regional SST anomaly (deg C)",
       title = "Regional SST anomaly under four constructions",
       subtitle = "Grey band: +/- 2 SE of the pipeline series (V1). Series overlap closely except where few stations report.") +
  theme_ms(9) + guides(colour = guide_legend(nrow = 2))
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
read_idx <- function(f) read_csv(file.path(ENV_DIR, f), show_col_types = FALSE) %>%
  filter(month %in% 5:8) %>%
  pivot_longer(matches("^\\d+N$"), names_to = "lat") %>%
  group_by(year, lat) %>% summarise(v = mean(value, na.rm = TRUE), n = n(), .groups = "drop") %>%
  filter(n >= 100)
beuti_ann <- read_idx("BEUTI_daily.csv") %>% rename(beuti = v) %>% select(-n)
cuti_ann  <- read_idx("CUTI_daily.csv")  %>% rename(cuti = v)  %>% select(-n)
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
       title = "Upwelling indices at 46N and 47N: level shift at the 2010/2011 product boundary?",
       subtitle = "Dashed line: end of the historical reanalysis period of the source model (to verify with the index authors).") +
  theme_ms(9)
save_fig(p_beuti, "fig_beuti_homogeneity", 8, 7.5)

# Cross-index annual correlations (raw and linearly detrended), 1991-2024
ann_tab <- env %>% filter(year %in% 1991:2024) %>% group_by(year) %>%
  summarise(`BEUTI May-Aug 47N` = mean(beuti_47N[month %in% 5:8]),
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

message("09_env_record_diagnostics: done (open-coast fit ", fit_open$iterations, " iterations; all-station fit ",
        fit_all$iterations, " iterations, converged = ", fit_all$converged, ")")

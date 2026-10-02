# ═══════════════════════════════════════════════════════════════════════════════
# 01_build_datasets.R — tidy, documented analysis datasets
# ═══════════════════════════════════════════════════════════════════════════════
# Outputs (02_data/derived/):
#   survey_beach_year.csv  one row per beach x survey year: abundance estimates,
#                          survey timing, length composition
#   env_monthly.csv        one row per year x month: BEUTI/CUTI (46N, 47N),
#                          Columbia discharge, PDO, regional SST anomaly
#   cohort_table.csv       one row per beach x year class (spawning year Y),
#                          cohort-aligned responses and pre-specified predictors
#
# Key conventions (see docs/methodology-review.md §3-5):
#   * survey_year = first year of the season label ("2003-04" → 2003). The
#     stock-assessment survey happens April-August of that year.
#   * A year class Y is spawned/settles in summer Y. At a June-July survey its
#     members are pre-recruits (<76 mm) in survey Y+1 and mostly recruits in
#     survey Y+2. Lag-0 summer predictors therefore post-date the survey that
#     the original notebook paired them with.

source(here::here("01_code", "R", "00_config.R"))

# ── 1. Season summary (WDFW abundance estimates) ────────────────────────────
season <- read_excel(file.path(DATA_DIR, "razor-clam-season-summary-1997-2025.xlsx"),
                     sheet = "data") %>%
  transmute(beach, season,
            survey_year  = as.integer(str_sub(season, 1, 4)),
            habitat_m2, pre_recruits, recruits,
            harvest_total, exploitation_rate = ER, TAC)

stopifnot(!anyDuplicated(season[c("beach", "survey_year")]))

# ── 2. Shell lengths: survey timing and size composition ────────────────────
sl <- read_excel(file.path(DATA_DIR, "shell_length_data-summary",
                           "All_Beaches_shell_lengths_1997-2025.xlsx"),
                 sheet = "All_Clams_Raw", col_types = "text") %>%
  mutate(survey_year = as.integer(survey_year),
         length_mm   = as.numeric(length_mm),
         # Three date encodings occur: ISO text, Excel serials, "11-Aug-2011"
         date = case_when(
           str_detect(date, "^\\d{4}-\\d{2}-\\d{2}$") ~ as.Date(date),
           str_detect(date, "^\\d{5}$") ~ as.Date(as.numeric(date), origin = "1899-12-30"),
           str_detect(date, "^\\d{1,2}-[A-Za-z]{3}-\\d{4}$") ~ as.Date(date, format = "%d-%b-%Y"),
           TRUE ~ as.Date(NA)),
         doy = yday(date))

date_check <- sl %>% filter(!is.na(date), year(date) != survey_year)
if (nrow(date_check) > 0) {
  message("NOTE: ", nrow(date_check), " clams have date-year != survey_year; ",
          "dates kept as recorded.")
}

sl_by_year <- sl %>%
  group_by(beach, survey_year) %>%
  summarise(
    survey_date_first = suppressWarnings(min(date, na.rm = TRUE)),
    survey_date_last  = suppressWarnings(max(date, na.rm = TRUE)),
    survey_doy        = median(doy, na.rm = TRUE),
    n_measured        = n(),
    n_dated           = sum(!is.na(date)),
    p_pre             = mean(length_mm <= PRE_RECRUIT_MAX_MM),
    p_76_100          = mean(length_mm > 75 & length_mm <= 100),
    p_101_120         = mean(length_mm > 100 & length_mm <= 120),
    p_gt120           = mean(length_mm > 120),
    # share of pre-recruits < 30 mm: proxy for current-year settlers at late surveys
    p_pre_lt30        = mean(length_mm[length_mm <= PRE_RECRUIT_MAX_MM] < 30),
    median_length_mm  = median(length_mm),
    .groups = "drop") %>%
  mutate(across(c(survey_date_first, survey_date_last),
                ~ if_else(is.infinite(.x), as.Date(NA), .x)),
         survey_doy = if_else(is.nan(survey_doy), NA_real_, survey_doy))

survey <- season %>%
  full_join(sl_by_year, by = c("beach", "survey_year")) %>%
  # Beach-years without usable dates (Kalaloch 2001: no dates; Copalis 2003: no
  # length records at all) get that beach's median survey day of year.
  group_by(beach) %>%
  mutate(survey_doy_imputed = is.na(survey_doy),
         survey_doy = if_else(is.na(survey_doy), median(survey_doy, na.rm = TRUE), survey_doy)) %>%
  ungroup() %>%
  mutate(beach = factor(beach, levels = BEACHES)) %>%
  arrange(beach, survey_year) %>%
  mutate(pre_density = pre_recruits / habitat_m2,
         rec_density = recruits / habitat_m2)

write_csv(survey, file.path(DERIVED, "survey_beach_year.csv"))

# ── 3. Environmental monthly table ──────────────────────────────────────────
# INDEX_VINTAGE (00_config.R) selects the cached snapshots or the current files
# in external/ (acquire/fetch_climate_indices.R); the vintages differ through
# the whole record, so this is recorded in env_monthly.csv as `index_vintage`.
index_file <- function(idx) {
  if (INDEX_VINTAGE == "cached") return(file.path(ENV_DIR, paste0(idx, "_daily.csv")))
  f <- sort(list.files(file.path(ENV_DIR, "external"),
                       pattern = sprintf("^%s_daily_\\d{4}-\\d{2}-\\d{2}\\.csv$", idx), full.names = TRUE))
  if (length(f) == 0) stop("INDEX_VINTAGE = current but no external/", idx, "_daily_<date>.csv; run acquire/fetch_climate_indices.R")
  tail(f, 1)
}
upw <- function(file, name) {
  read_csv(file, show_col_types = FALSE) %>%
    select(year, month, `46N`, `47N`) %>%
    group_by(year, month) %>%
    summarise(across(c(`46N`, `47N`), ~ mean(.x, na.rm = TRUE)), n_days = n(), .groups = "drop") %>%
    filter(n_days >= 20) %>%
    rename_with(~ paste0(name, "_", .x), c(`46N`, `47N`)) %>%
    select(-n_days)
}
beuti <- upw(index_file("BEUTI"), "beuti")
cuti  <- upw(index_file("CUTI"),  "cuti")
message("01: upwelling indices from ", basename(index_file("BEUTI")), " (vintage: ", INDEX_VINTAGE, ")")

discharge <- read_csv(file.path(ENV_DIR, "columbia_discharge.csv"), show_col_types = FALSE) %>%
  group_by(year, month) %>%
  summarise(q_cms = mean(discharge_cms, na.rm = TRUE), n_days = n(), .groups = "drop") %>%
  filter(n_days >= 20) %>% select(-n_days)

# PDO cache stores month names ("Jan"); the original notebook's as.numeric()
# turns these into NA (see task.md). Parse explicitly.
pdo <- read_csv(file.path(ENV_DIR, "pdo_index.csv"), show_col_types = FALSE) %>%
  mutate(month = if (is.numeric(month)) month else match(month, month.abb),
         pdo = if_else(abs(pdo) > 90, NA_real_, pdo)) %>%
  filter(!is.na(month)) %>%
  select(year, month, pdo)
if (INDEX_VINTAGE == "current") {   # NCEI ERSST v5 PDO as fetched by acquire/fetch_climate_indices.R
  pdo <- read_csv(file.path(ENV_DIR, "external", "pdo_monthly.csv"), show_col_types = FALSE) %>%
    transmute(year = as.integer(year), month = as.integer(month), pdo = ncei)
}

# Regional SST anomaly from open-coast buoys and moorings, homogenised with the
# two-way station model in lib_env_homogenize.R (station climatology + common
# regional anomaly, estimated jointly so that stations with short or partial
# records do not bias the series; see docs/environmental-record-options.md).
# Estuary/harbor gauges are excluded (STATION_CLASS in 00_config.R).
source(here::here("01_code", "R", "lib_env_homogenize.R"))
sst_station <- read_excel(file.path(ENV_DIR, "monthly_wtmp_summary.xlsx"), sheet = "data") %>%
  mutate(year = as.integer(year), month = as.integer(month)) %>%
  filter(n_obs >= SST_MIN_HOURLY_OBS) %>%
  transmute(station, year, month, value = wtmp_mean)

sst_fit <- homogenize_stations(sst_station, SST_CLIM_YEARS, stations = SST_OPEN_COAST,
                               min_station_months = SST_MIN_STATION_MONTHS)
if (!sst_fit$converged) warning("SST homogenisation did not converge; check lib_env_homogenize.R")
sst <- sst_fit$regional %>%
  transmute(year, month, sst_anom = anom, sst_anom_se = se, n_sst_stations = n_stations)
write_csv(sst_fit$station, file.path(DERIVED, "sst_station_parameters.csv"))

# The earlier construction (naive anomalies from three buoys, each relative to
# its own climatology) is kept as a comparison column for 09_env_record_diagnostics.R.
sst_naive <- sst_station %>%
  filter(station %in% SST_STATIONS) %>%
  group_by(station, month) %>%
  mutate(anom = value - mean(value[year %in% SST_CLIM_YEARS], na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(year, month) %>%
  summarise(sst_anom_naive3 = mean(anom, na.rm = TRUE), .groups = "drop")

# Optional external products (satellite SST, buoy wind and waves, a lower-river
# gauge): any 02_data/Environmental Data/external/*_monthly.csv with `year` and
# `month` columns is joined as extra columns prefixed by its file stem. Nothing
# downstream requires them; see 01_code/R/acquire/README.md.
ext_files <- list.files(file.path(ENV_DIR, "external"), pattern = "_monthly\\.csv$", full.names = TRUE)
ext <- map(ext_files, function(f) {
  d <- read_csv(f, show_col_types = FALSE)
  if (!all(c("year", "month") %in% names(d))) return(NULL)
  stem <- sub("_monthly\\.csv$", "", basename(f))
  d %>% mutate(year = as.integer(year), month = as.integer(month)) %>%
    rename_with(~ paste0(stem, "_", .x), -c(year, month))
}) %>% compact()

env_monthly <- expand_grid(year = 1988:2026, month = 1:12) %>%
  left_join(beuti, by = c("year", "month")) %>%
  left_join(cuti,  by = c("year", "month")) %>%
  left_join(discharge, by = c("year", "month")) %>%
  left_join(pdo, by = c("year", "month")) %>%
  left_join(sst, by = c("year", "month")) %>%
  left_join(sst_naive, by = c("year", "month")) %>%
  mutate(n_sst_stations = replace_na(n_sst_stations, 0L))
for (e in ext) env_monthly <- env_monthly %>% left_join(e, by = c("year", "month"))
env_monthly <- env_monthly %>% mutate(index_vintage = INDEX_VINTAGE)

write_csv(env_monthly, file.path(DERIVED, "env_monthly.csv"))

# ── 4. Cohort-aligned predictors ────────────────────────────────────────────
# Window means over a sequence of (year offset, month) pairs relative to year
# class Y. offset 0 = spawning year Y, offset 1 = year Y+1.
window_mean <- function(env, var, Y, offsets, months, min_frac = 0.75) {
  key <- tibble(year = Y + offsets, month = months)
  v <- env %>% semi_join(key, by = c("year", "month")) %>% pull(all_of(var))
  if (length(v) == 0 || mean(!is.na(v)) * length(v) < min_frac * nrow(key)) return(NA_real_)
  mean(v, na.rm = TRUE)
}

# Pre-specified confirmatory predictors (fixed BEFORE looking at correlations
# with clam data; rationale in docs/methodology-review.md §5.2):
#   beuti_larval  BEUTI May-Aug Y           nutrient supply during larval period
#   sst_larval    SST anomaly May-Sep Y      thermal conditions for spawning/larvae
#   pdo_larval    PDO May-Sep Y              basin-scale regime
#   q_freshet     Columbia discharge Apr-Jun Y  plume extent / retention
#   cuti_winter   CUTI Nov Y - Feb Y+1       winter downwelling/storm intensity
#                                            (negative = downwelling) during the
#                                            first winter, when small clams are
#                                            washed out of the beach (WDF 1988, p.131)
predictor_specs <- list(
  beuti_larval = list(var = "beuti", offsets = rep(0, 4), months = 5:8,  lat = TRUE),
  sst_larval   = list(var = "sst_anom", offsets = rep(0, 5), months = 5:9, lat = FALSE),
  pdo_larval   = list(var = "pdo", offsets = rep(0, 5), months = 5:9,    lat = FALSE),
  q_freshet    = list(var = "q_cms", offsets = rep(0, 3), months = 4:6,  lat = FALSE),
  cuti_winter  = list(var = "cuti", offsets = c(0, 0, 1, 1), months = c(11, 12, 1, 2), lat = TRUE)
)

cohort_predictors <- expand_grid(beach = BEACHES, year_class = 1988:2024) %>%
  rowwise() %>%
  mutate(preds = list(map_dbl(predictor_specs, function(s) {
    v <- if (s$lat) paste0(s$var, "_", BEACH_LAT_BIN[[beach]]) else s$var
    window_mean(env_monthly, v, year_class, s$offsets, s$months)
  }))) %>%
  ungroup() %>%
  unnest_wider(preds)

# ── 5. Cohort table ─────────────────────────────────────────────────────────
sv <- survey %>% mutate(beach = as.character(beach)) %>%
  select(beach, survey_year, pre_recruits, recruits, survey_doy, p_pre_lt30, habitat_m2)

cohort <- cohort_predictors %>%
  # pre-recruits of year class Y are counted at survey Y+1
  left_join(sv %>% transmute(beach, year_class = survey_year - 1L,
                             pre_next = pre_recruits, doy_next = survey_doy,
                             p_lt30_next = p_pre_lt30),
            by = c("beach", "year_class")) %>%
  # the same year class is mostly recruited by survey Y+2
  left_join(sv %>% transmute(beach, year_class = survey_year - 2L, rec_next2 = recruits),
            by = c("beach", "year_class")) %>%
  # spawning stock: recruits present at survey Y
  left_join(sv %>% transmute(beach, year_class = survey_year, spawners = recruits),
            by = c("beach", "year_class")) %>%
  mutate(beach = factor(beach, levels = BEACHES),
         log_pre_next  = log(pre_next),
         log_rec_next2 = log(rec_next2),
         log_spawners  = log(spawners)) %>%
  arrange(beach, year_class)

write_csv(cohort, file.path(DERIVED, "cohort_table.csv"))

message("01_build_datasets: wrote survey_beach_year.csv (", nrow(survey), " rows), ",
        "env_monthly.csv (", nrow(env_monthly), "), cohort_table.csv (", nrow(cohort), ")")

# ═══════════════════════════════════════════════════════════════════════════════
# fetch_climate_indices.R — current vintages of BEUTI, CUTI and the PDO
# ═══════════════════════════════════════════════════════════════════════════════
# Why: the cached copies in 02_data/Environmental Data (BEUTI_daily.csv,
# CUTI_daily.csv, pdo_index.csv) are snapshots. The index authors regenerate
# BEUTI/CUTI from an updated ocean reanalysis, and NCEI recomputes the PDO
# when ERSST is revised, so values in the whole record change between
# vintages, not just the latest months. This script downloads the current
# files, keeps them under a dated name, writes monthly tables the pipeline
# joins automatically, and prints how far they differ from the cache.
# 09_env_record_diagnostics.R (section F) tests whether the pre-specified
# BEUTI result depends on the vintage; 01_build_datasets.R can be switched to
# the current vintage with RC_INDEX_VINTAGE=current (run_all.R --vintage=current).
#
# Outputs (02_data/Environmental Data/external/):
#   BEUTI_daily_<creation date>.csv, CUTI_daily_<creation date>.csv   full daily files
#   upwelling_monthly.csv   year, month, beuti_45N..47N, cuti_45N..47N (monthly means of
#                           the current daily files; >= 20 days per month)
#   pdo_monthly.csv         year, month, ncei (ERSST v5 PDO from NCEI), psl (NOAA PSL)
#   climate_indices_provenance.txt

suppressPackageStartupMessages({ library(tidyverse); library(here); library(ncdf4) })
source(here("01_code", "R", "00_config.R"))
EXT_DIR <- file.path(ENV_DIR, "external"); RAW_DIR <- file.path(EXT_DIR, "raw")
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)

URLS <- c(BEUTI_daily.csv = "https://mjacox.com/wp-content/uploads/BEUTI_daily.csv",
          BEUTI_daily.nc  = "https://mjacox.com/wp-content/uploads/BEUTI_daily.nc",
          CUTI_daily.csv  = "https://mjacox.com/wp-content/uploads/CUTI_daily.csv",
          CUTI_daily.nc   = "https://mjacox.com/wp-content/uploads/CUTI_daily.nc",
          pdo_ncei.dat    = "https://www.ncei.noaa.gov/pub/data/cmb/ersst/v5/index/ersst.v5.pdo.dat",
          pdo_psl.csv     = "https://psl.noaa.gov/pdo/data/pdo.timeseries.ersstv5.csv")
dl <- function(name) {
  f <- file.path(RAW_DIR, name)
  ok <- tryCatch(download.file(URLS[[name]], f, quiet = TRUE, mode = "wb") == 0, error = function(e) FALSE)
  if (!ok) stop("download failed: ", URLS[[name]])
  f
}
files <- set_names(map_chr(names(URLS), dl), names(URLS))

# ── BEUTI / CUTI: the NetCDF global attribute carries the creation date ─────
creation_date <- function(nc_file) {
  nc <- nc_open(nc_file); on.exit(nc_close(nc))
  d <- ncatt_get(nc, 0)[["Creation Date"]]
  if (is.null(d)) return(format(Sys.Date()))
  format(as.Date(d, format = "%d-%b-%Y"))
}
vintage <- c(BEUTI = creation_date(files[["BEUTI_daily.nc"]]), CUTI = creation_date(files[["CUTI_daily.nc"]]))
message("Index creation dates on the server: BEUTI ", vintage[["BEUTI"]], ", CUTI ", vintage[["CUTI"]])
for (idx in c("BEUTI", "CUTI")) {
  # remove older dated copies so only one current vintage is kept beside the cache
  old <- list.files(EXT_DIR, pattern = sprintf("^%s_daily_\\d{4}-\\d{2}-\\d{2}\\.csv$", idx), full.names = TRUE)
  file.remove(old)
  file.copy(files[[paste0(idx, "_daily.csv")]], file.path(EXT_DIR, sprintf("%s_daily_%s.csv", idx, vintage[[idx]])),
            overwrite = TRUE)
}
monthly_idx <- function(f, name) read_csv(f, show_col_types = FALSE) %>%
  select(year, month, `45N`, `46N`, `47N`) %>%
  group_by(year, month) %>%
  summarise(across(c(`45N`, `46N`, `47N`), ~ mean(.x, na.rm = TRUE)), n = n(), .groups = "drop") %>%
  filter(n >= 20) %>% select(-n) %>% rename_with(~ paste0(name, "_", .x), -c(year, month))
upw <- monthly_idx(files[["BEUTI_daily.csv"]], "beuti") %>%
  full_join(monthly_idx(files[["CUTI_daily.csv"]], "cuti"), by = c("year", "month")) %>% arrange(year, month)
write_csv(upw, file.path(EXT_DIR, "upwelling_monthly.csv"))

# ── PDO: NCEI table (year x 12 months, 99.99 missing) and PSL csv (-9999 missing) ──
ncei_lines <- readLines(files[["pdo_ncei.dat"]])
ncei <- read_table(I(ncei_lines[-1]), col_names = TRUE, show_col_types = FALSE) %>%
  pivot_longer(-Year, names_to = "mon", values_to = "ncei") %>%
  transmute(year = as.integer(Year), month = match(mon, month.abb), ncei = if_else(ncei > 99, NA_real_, ncei))
psl <- read_csv(files[["pdo_psl.csv"]], skip = 1, col_names = c("date", "psl"), show_col_types = FALSE) %>%
  transmute(year = as.integer(year(date)), month = as.integer(month(date)), psl = if_else(psl < -90, NA_real_, psl))
pdo <- full_join(ncei, psl, by = c("year", "month")) %>% filter(!is.na(month)) %>% arrange(year, month)
write_csv(pdo, file.path(EXT_DIR, "pdo_monthly.csv"))

# ── Compare with the cached copies ──────────────────────────────────────────
cmp <- function(cached, current, cols) {
  j <- inner_join(cached, current, by = c("year", "month", "day"), suffix = c(".c", ".n"))
  map_dfr(cols, function(k) { d <- j[[paste0(k, ".n")]] - j[[paste0(k, ".c")]]
    tibble(col = k, n = sum(!is.na(d)), max_abs_diff = max(abs(d), na.rm = TRUE),
           share_changed = mean(abs(d) > 1e-3, na.rm = TRUE),
           r = cor(j[[paste0(k, ".n")]], j[[paste0(k, ".c")]], use = "complete.obs")) })
}
for (idx in c("BEUTI", "CUTI")) {
  cached <- read_csv(file.path(ENV_DIR, paste0(idx, "_daily.csv")), show_col_types = FALSE)
  current <- read_csv(files[[paste0(idx, "_daily.csv")]], show_col_types = FALSE)
  message(idx, ": cached ends ", max(cached$year), "-", max(cached$month[cached$year == max(cached$year)]),
          "; current ends ", max(current$year), "-", max(current$month[current$year == max(current$year)]))
  print(as.data.frame(cmp(cached, current, c("45N", "46N", "47N"))))
}
pdo_c <- read_csv(file.path(ENV_DIR, "pdo_index.csv"), show_col_types = FALSE) %>%
  mutate(month = if (is.numeric(month)) month else match(month, month.abb)) %>% filter(abs(pdo) < 90)
jp <- inner_join(pdo_c, pdo, by = c("year", "month"))
message(sprintf("PDO cached vs NCEI: r = %.4f, max|diff| = %.2f; cached vs PSL: r = %.4f, max|diff| = %.2f",
                cor(jp$pdo, jp$ncei, use = "complete.obs"), max(abs(jp$pdo - jp$ncei), na.rm = TRUE),
                cor(jp$pdo, jp$psl, use = "complete.obs"), max(abs(jp$pdo - jp$psl), na.rm = TRUE)))

writeLines(c("Current vintages of the upwelling indices and the PDO",
             paste("downloaded", Sys.Date()),
             paste("BEUTI/CUTI from", dirname(URLS[["BEUTI_daily.csv"]]), "; creation dates (NetCDF attribute): BEUTI",
                   vintage[["BEUTI"]], ", CUTI", vintage[["CUTI"]]),
             "Jacox MG, Edwards CA, Hazen EL, Bograd SJ (2018) J. Geophys. Res. Oceans 123(10): 7332-7350",
             paste("PDO (NCEI, ERSST v5):", URLS[["pdo_ncei.dat"]]),
             paste("PDO (PSL, ERSST v5, EOF 1920-2014):", URLS[["pdo_psl.csv"]]),
             paste("md5", basename(names(files)), tools::md5sum(files)),
             paste("md5 upwelling_monthly.csv", tools::md5sum(file.path(EXT_DIR, "upwelling_monthly.csv"))),
             paste("md5 pdo_monthly.csv", tools::md5sum(file.path(EXT_DIR, "pdo_monthly.csv")))),
           file.path(EXT_DIR, "climate_indices_provenance.txt"))
message("fetch_climate_indices: wrote upwelling_monthly.csv (", nrow(upw), " rows) and pdo_monthly.csv (", nrow(pdo), " rows)")

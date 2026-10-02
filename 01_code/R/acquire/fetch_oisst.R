# ═══════════════════════════════════════════════════════════════════════════════
# fetch_oisst.R — NOAA OISST v2.1 daily 0.25-degree SST near the five beaches
# ═══════════════════════════════════════════════════════════════════════════════
# STATUS: written without network access; not yet executed. Verify the dataset
# id with rerddap::ed_search(query = "OISST", url = ERDDAP) if the script stops.
#
# Why OISST: homogeneous, gap-free, daily, 1981-09 to present, so it covers the
# whole clam record with one product, unlike the station patchwork. Caveats:
# 0.25-degree pixels (~20 km); the nearest ocean pixel to a beach may be
# 10-30 km offshore, and coastal pixels can be land-contaminated. Use the
# per-pixel anomalies (climatology removed per pixel) and validate against the
# homogenised buoy anomaly in env_monthly.csv (expected monthly r > 0.9).
#
# Output: 02_data/Environmental Data/external/oisst_monthly.csv with columns
#   year, month, anom_regional, anom_<beach> (5 columns), sst_regional (deg C),
#   n_pixels_regional
# plus oisst_pixels.csv (which pixels were used) and oisst_provenance.txt.

suppressPackageStartupMessages({ library(tidyverse); library(rerddap); library(here) })
source(here("01_code", "R", "00_config.R"))

ERDDAP   <- "https://coastwatch.pfeg.noaa.gov/erddap/"
DATASET  <- "ncdcOisst21Agg_LonPM180"     # NOAA OISST v2.1 AVHRR-only, lon -180..180
EXT_DIR  <- file.path(ENV_DIR, "external"); RAW_DIR <- file.path(EXT_DIR, "raw")
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)
CLIM_YEARS <- 1991:2020                   # WMO standard normal period
BOX <- list(lat = c(45.9, 48.1), lon = c(-125.4, -123.6))
beaches <- tibble(beach = c("Long Beach", "Twin Harbors", "Copalis", "Mocrocks", "Kalaloch"),
                  lat = c(46.361592, 46.855477, 47.133586, 47.238914, 47.606156),
                  lon = c(-124.069805, -124.118770, -124.195585, -124.219583, -124.380790))

# ── 1. Confirm the dataset exists ───────────────────────────────────────────
info <- tryCatch(rerddap::info(DATASET, url = ERDDAP), error = function(e) NULL)
if (is.null(info)) {
  hits <- tryCatch(rerddap::ed_search(query = "OISST", url = ERDDAP), error = function(e) NULL)
  stop("Dataset '", DATASET, "' not found on ", ERDDAP, ". Candidates:\n",
       if (!is.null(hits)) paste(head(hits$info$dataset_id, 15), collapse = "\n") else "(search failed)")
}

# ── 2. Download year by year (keeps each request small), cache as RDS ───────
years <- 1981:year(Sys.Date())
daily <- map_dfr(years, function(y) {
  f <- file.path(RAW_DIR, sprintf("oisst_%d.rds", y))
  if (file.exists(f)) return(readRDS(f))
  t0 <- if (y == 1981) "1981-09-01" else sprintf("%d-01-01", y)
  t1 <- if (y == year(Sys.Date())) as.character(Sys.Date() - 2) else sprintf("%d-12-31", y)
  g <- tryCatch(rerddap::griddap(info, time = c(t0, t1), latitude = BOX$lat, longitude = BOX$lon,
                                 fields = "sst", fmt = "csv"), error = function(e) NULL)
  if (is.null(g)) { message("  ", y, ": download failed; skipped"); return(NULL) }
  d <- as_tibble(g) %>% transmute(date = as.Date(time), lat = latitude, lon = longitude, sst) %>%
    filter(!is.na(sst))
  saveRDS(d, f); message("  ", y, ": ", nrow(d), " pixel-days"); d
})

# ── 3. Pixel selection: ocean pixels within 40 km of each beach, and a regional set ──
hav <- function(lat1, lon1, lat2, lon2) {
  p1 <- lat1 * pi / 180; p2 <- lat2 * pi / 180
  a <- sin((lat2 - lat1) * pi / 360)^2 + cos(p1) * cos(p2) * sin((lon2 - lon1) * pi / 360)^2
  2 * 6371 * asin(sqrt(a))
}
pixels <- daily %>% count(lat, lon, name = "n_days")
pix_beach <- cross_join(beaches, pixels) %>% mutate(d_km = hav(lat.x, lon.x, lat.y, lon.y)) %>%
  filter(d_km <= 40) %>% group_by(beach) %>% slice_min(d_km, n = 3) %>% ungroup() %>%
  transmute(beach, lat = lat.y, lon = lon.y, d_km)
write_csv(pix_beach, file.path(EXT_DIR, "oisst_pixels.csv"))

# ── 4. Monthly means, per-pixel climatology, anomalies ──────────────────────
monthly <- daily %>% mutate(year = year(date), month = month(date)) %>%
  group_by(lat, lon, year, month) %>% summarise(sst = mean(sst), n = n(), .groups = "drop") %>%
  filter(n >= 20) %>%
  group_by(lat, lon, month) %>% mutate(anom = sst - mean(sst[year %in% CLIM_YEARS])) %>% ungroup()
regional <- monthly %>% group_by(year, month) %>%
  summarise(anom_regional = mean(anom), sst_regional = mean(sst), n_pixels_regional = n(), .groups = "drop")
by_beach <- monthly %>% inner_join(pix_beach, by = c("lat", "lon"), relationship = "many-to-many") %>%
  group_by(beach, year, month) %>% summarise(anom = mean(anom), .groups = "drop") %>%
  mutate(beach = paste0("anom_", gsub(" ", "_", tolower(beach)))) %>%
  pivot_wider(names_from = beach, values_from = anom)
out <- regional %>% left_join(by_beach, by = c("year", "month")) %>% arrange(year, month)
write_csv(out, file.path(EXT_DIR, "oisst_monthly.csv"))

writeLines(c(paste("OISST v2.1 via", ERDDAP, "dataset", DATASET), paste("downloaded", Sys.Date()),
             paste("box lat", paste(BOX$lat, collapse = "-"), "lon", paste(BOX$lon, collapse = "-")),
             paste("climatology", min(CLIM_YEARS), "-", max(CLIM_YEARS)),
             paste("rerddap", as.character(packageVersion("rerddap"))),
             paste("md5 oisst_monthly.csv", tools::md5sum(file.path(EXT_DIR, "oisst_monthly.csv")))),
           file.path(EXT_DIR, "oisst_provenance.txt"))
print(out %>% group_by(year) %>% summarise(months = n()) %>% as.data.frame())
message("fetch_oisst: wrote ", nrow(out), " rows. Now rerun ./run_pipeline.sh")

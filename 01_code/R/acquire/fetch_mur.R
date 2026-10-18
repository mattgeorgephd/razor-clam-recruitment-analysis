# ═══════════════════════════════════════════════════════════════════════════════
# fetch_mur.R — JPL MUR 1 km SST, monthly, at nearshore pixels off each beach
# ═══════════════════════════════════════════════════════════════════════════════
# Dataset id confirmed on the server 2026-10-02 (monthly composites from
# 2002-06; 0.01-degree grid).
#
# Why MUR: 1 km resolution resolves the surf-zone-adjacent ocean, which OISST
# cannot; 2002-06 to present, so it validates and localises the longer OISST
# and buoy series rather than replacing them. Small boxes (0.1 x 0.1 deg) are
# requested per beach to keep downloads small.
#
# Output: 02_data/Environmental Data/external/mur_monthly.csv with columns
#   year, month, anom_<beach> (5), sst_<beach> (5)

suppressPackageStartupMessages({ library(tidyverse); library(rerddap); library(here) })
source(here("01_code", "R", "00_config.R"))

ERDDAP  <- "https://coastwatch.pfeg.noaa.gov/erddap/"
DATASET <- "jplMURSST41mday"              # MUR SST v4.1, monthly composite
EXT_DIR <- file.path(ENV_DIR, "external"); RAW_DIR <- file.path(EXT_DIR, "raw")
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)
CLIM_YEARS <- 2003:2020
beaches <- tibble(beach = c("Long Beach", "Twin Harbors", "Copalis", "Mocrocks", "Kalaloch"),
                  lat = c(46.361592, 46.855477, 47.133586, 47.238914, 47.606156),
                  lon = c(-124.069805, -124.118770, -124.195585, -124.219583, -124.380790))

info <- tryCatch(rerddap::info(DATASET, url = ERDDAP), error = function(e) NULL)
if (is.null(info)) {
  hits <- tryCatch(rerddap::ed_search(query = "MUR", url = ERDDAP), error = function(e) NULL)
  stop("Dataset '", DATASET, "' not found. Candidates:\n",
       if (!is.null(hits)) paste(head(hits$info$dataset_id, 15), collapse = "\n") else "(search failed)")
}

# ERDDAP rejects time bounds outside the dataset's coverage, so clamp to it.
# rerddap only accepts endpoints strictly inside the coverage unless the full
# ISO timestamps are passed, so use the dataset's own attribute strings.
t_start <- info$alldata$NC_GLOBAL %>% filter(attribute_name == "time_coverage_start") %>% pull(value)
t_end   <- info$alldata$NC_GLOBAL %>% filter(attribute_name == "time_coverage_end") %>% pull(value)
monthly <- map_dfr(seq_len(nrow(beaches)), function(i) {
  b <- beaches[i, ]
  f <- file.path(RAW_DIR, sprintf("mur_%s.rds", gsub(" ", "_", tolower(b$beach))))
  if (file.exists(f)) return(readRDS(f))
  # box extends 0.12 deg offshore (west) and 0.05 deg alongshore either side
  g <- tryCatch(rerddap::griddap(info, time = c(t_start, t_end),
                                 latitude = c(b$lat - 0.05, b$lat + 0.05),
                                 longitude = c(b$lon - 0.12, b$lon + 0.01),
                                 fields = "sst", fmt = "csv", read = TRUE),
                error = function(e) { message("  ", b$beach, ": ", conditionMessage(e)); NULL })
  if (is.null(g)) { message("  ", b$beach, ": download failed"); return(NULL) }
  d <- as_tibble(g) %>% filter(!is.na(sst)) %>%
    transmute(beach = b$beach, date = as.Date(time), year = year(date), month = month(date),
              lat = latitude, lon = longitude, sst) %>%
    group_by(beach, year, month) %>%
    summarise(sst = mean(sst), n_pixels = n(), .groups = "drop")   # average of ocean pixels in the box
  saveRDS(d, f); message("  ", b$beach, ": ", nrow(d), " months"); d
})

out <- monthly %>%
  group_by(beach, month) %>% mutate(anom = sst - mean(sst[year %in% CLIM_YEARS])) %>% ungroup() %>%
  mutate(key = gsub(" ", "_", tolower(beach))) %>%
  select(year, month, key, anom, sst) %>%
  pivot_wider(names_from = key, values_from = c(anom, sst), names_glue = "{.value}_{key}") %>%
  arrange(year, month)
write_csv(out, file.path(EXT_DIR, "mur_monthly.csv"))
writeLines(c(paste("MUR SST v4.1 monthly via", ERDDAP, "dataset", DATASET), paste("downloaded", Sys.Date()),
             paste("climatology", min(CLIM_YEARS), "-", max(CLIM_YEARS)),
             paste("rerddap", as.character(packageVersion("rerddap"))),
             paste("md5 mur_monthly.csv", tools::md5sum(file.path(EXT_DIR, "mur_monthly.csv")))),
           file.path(EXT_DIR, "mur_provenance.txt"))
message("fetch_mur: wrote ", nrow(out), " rows")

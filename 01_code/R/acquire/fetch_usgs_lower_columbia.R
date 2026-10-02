# ═══════════════════════════════════════════════════════════════════════════════
# fetch_usgs_lower_columbia.R — Columbia River discharge nearer the mouth
# ═══════════════════════════════════════════════════════════════════════════════
# Site numbers confirmed against the NWIS site service 2026-10-02:
# 14246900 "Columbia River at Port Westward, near Quincy, OR" (Beaver Army
# Terminal), 14211720 "Willamette River at Portland, OR", 14105700 The Dalles.
#
# Why: the cached series (02_data/Environmental Data/columbia_discharge.csv)
# is The Dalles (14105700), ~300 km upstream, which omits the Willamette and
# other lower-basin tributaries that matter for the plume reaching Long Beach.
# Beaver Army Terminal near Quincy, OR (14246900) is the lowest long-term gauge
# on the main stem; the Willamette at Portland (14211720) is the largest lower
# tributary. Both are written so either can be used.
#
# Uses the USGS Water Data API (dataRetrieval::read_waterdata_daily); the
# older NWIS service (readNWISdv) is being decommissioned and needs a recent
# httr2 to work at all.
#
# Output: 02_data/Environmental Data/external/columbia_lower_monthly.csv with
#   year, month, q_beaver_cms, q_willamette_cms, q_dalles_cms (for comparison)

suppressPackageStartupMessages({ library(tidyverse); library(dataRetrieval); library(here) })
# dataRetrieval's progress bar crashes on some cli versions ("invalid format '%2d'"); it is not needed.
options(cli.progress_show_after = Inf, cli.dynamic = FALSE)
source(here("01_code", "R", "00_config.R"))
EXT_DIR <- file.path(ENV_DIR, "external"); dir.create(EXT_DIR, recursive = TRUE, showWarnings = FALSE)
SITES <- c(beaver = "14246900", willamette = "14211720", dalles = "14105700")

monthly <- imap_dfr(SITES, function(site, name) {
  d <- tryCatch(dataRetrieval::read_waterdata_daily(
                  monitoring_location_id = paste0("USGS-", site), parameter_code = "00060",
                  statistic_id = "00003", time = c("1990-01-01", as.character(Sys.Date()))),
                error = function(e) { message("  ", name, " (", site, "): ", conditionMessage(e)); NULL })
  if (is.null(d) || nrow(d) == 0) return(NULL)
  message("  ", name, " (", site, "): ", nrow(d), " daily values, ",
          min(d$time), " to ", max(d$time))
  as_tibble(sf::st_drop_geometry(d)) %>%
    transmute(gauge = name, date = as.Date(time), cfs = as.numeric(value)) %>% filter(!is.na(cfs)) %>%
    mutate(year = year(date), month = month(date)) %>%
    group_by(gauge, year, month) %>% summarise(q_cms = mean(cfs) * 0.0283168, n = n(), .groups = "drop") %>%
    filter(n >= 20)
})
out <- monthly %>% select(-n) %>%
  pivot_wider(names_from = gauge, values_from = q_cms, names_glue = "q_{gauge}_cms") %>%
  arrange(year, month)
write_csv(out, file.path(EXT_DIR, "columbia_lower_monthly.csv"))
writeLines(c("USGS Water Data API daily mean discharge (00060, statistic 00003) via dataRetrieval::read_waterdata_daily",
             paste(names(SITES), SITES, collapse = "; "), paste("downloaded", Sys.Date()),
             paste("dataRetrieval", as.character(packageVersion("dataRetrieval"))),
             paste("md5 columbia_lower_monthly.csv", tools::md5sum(file.path(EXT_DIR, "columbia_lower_monthly.csv")))),
           file.path(EXT_DIR, "columbia_lower_provenance.txt"))
if (all(c("q_beaver_cms", "q_dalles_cms") %in% names(out))) {
  r <- out %>% filter(month %in% 4:6) %>% group_by(year) %>% summarise(across(c(q_beaver_cms, q_dalles_cms), mean))
  message("Apr-Jun Beaver vs The Dalles: r = ", round(cor(r$q_beaver_cms, r$q_dalles_cms, use = "complete.obs"), 3),
          "; mean ratio = ", round(mean(r$q_beaver_cms / r$q_dalles_cms, na.rm = TRUE), 2))
}
message("fetch_usgs_lower_columbia: wrote ", nrow(out), " rows")

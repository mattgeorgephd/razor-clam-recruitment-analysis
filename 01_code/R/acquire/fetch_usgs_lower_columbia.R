# ═══════════════════════════════════════════════════════════════════════════════
# fetch_usgs_lower_columbia.R — Columbia River discharge nearer the mouth
# ═══════════════════════════════════════════════════════════════════════════════
# STATUS: written without network access; not yet executed. Site numbers to
# confirm with dataRetrieval::readNWISsite(c("14246900", "14211720")).
#
# Why: the cached series (02_data/Environmental Data/columbia_discharge.csv)
# is The Dalles (14105700), ~300 km upstream, which omits the Willamette and
# other lower-basin tributaries that matter for the plume reaching Long Beach.
# Beaver Army Terminal near Quincy, OR (14246900) is the lowest long-term gauge
# on the main stem; the Willamette at Portland (14211720) is the largest lower
# tributary. Both are written so either can be used.
#
# Output: 02_data/Environmental Data/external/columbia_lower_monthly.csv with
#   year, month, q_beaver_cms, q_willamette_cms, q_dalles_cms (for comparison)

suppressPackageStartupMessages({ library(tidyverse); library(dataRetrieval); library(here) })
source(here("01_code", "R", "00_config.R"))
EXT_DIR <- file.path(ENV_DIR, "external"); dir.create(EXT_DIR, recursive = TRUE, showWarnings = FALSE)
SITES <- c(beaver = "14246900", willamette = "14211720", dalles = "14105700")

monthly <- imap_dfr(SITES, function(site, name) {
  d <- tryCatch(dataRetrieval::readNWISdv(site, parameterCd = "00060", startDate = "1990-01-01",
                                          endDate = as.character(Sys.Date())),
                error = function(e) { message("  ", name, " (", site, "): ", conditionMessage(e)); NULL })
  if (is.null(d) || nrow(d) == 0) return(NULL)
  d <- dataRetrieval::renameNWISColumns(d)
  d %>% transmute(gauge = name, date = Date, cfs = Flow) %>% filter(!is.na(cfs)) %>%
    mutate(year = year(date), month = month(date)) %>%
    group_by(gauge, year, month) %>% summarise(q_cms = mean(cfs) * 0.0283168, n = n(), .groups = "drop") %>%
    filter(n >= 20)
})
out <- monthly %>% select(-n) %>%
  pivot_wider(names_from = gauge, values_from = q_cms, names_glue = "q_{gauge}_cms") %>%
  arrange(year, month)
write_csv(out, file.path(EXT_DIR, "columbia_lower_monthly.csv"))
writeLines(c("USGS NWIS daily discharge (00060) via dataRetrieval::readNWISdv",
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

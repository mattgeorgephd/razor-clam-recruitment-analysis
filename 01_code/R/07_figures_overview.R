# ═══════════════════════════════════════════════════════════════════════════════
# 07_figures_overview.R — study-area map and abundance/predictor time series
# ═══════════════════════════════════════════════════════════════════════════════
# Outputs: figures/fig_study_area.png, fig_abundance_timeseries.png,
#          fig_predictor_timeseries.png

source(here::here("01_code", "R", "00_config.R"))
suppressPackageStartupMessages({ library(maps); library(mapdata) })

beaches <- tibble(name = c("Long Beach", "Twin Harbors", "Copalis", "Mocrocks", "Kalaloch"),
                  lat = c(46.361592, 46.855477, 47.133586, 47.238914, 47.606156),
                  lon = c(-124.069805, -124.118770, -124.195585, -124.219583, -124.380790))
buoys <- read_excel(file.path(ENV_DIR, "Station Names.xlsx"), sheet = "data") %>%
  filter(station %in% SST_STATIONS) %>% transmute(name = station, lat = latitude, lon = longitude)
gauge_note <- "Discharge: USGS 14105700, The Dalles (~300 km upstream)"

coast <- map_data("worldHires", c("USA", "Canada"))
p_map <- ggplot() +
  geom_polygon(data = coast, aes(long, lat, group = group), fill = "grey85", colour = "grey40", linewidth = 0.2) +
  annotate("rect", xmin = -125.5, xmax = -123.6, ymin = 45.5, ymax = 46.5, fill = NA, colour = "steelblue", linetype = 2) +
  annotate("rect", xmin = -125.5, xmax = -123.6, ymin = 46.5, ymax = 47.5, fill = NA, colour = "steelblue", linetype = 2) +
  annotate("text", x = -125.45, y = c(46.45, 47.45), label = c("BEUTI/CUTI 46N", "BEUTI/CUTI 47N"),
           hjust = 0, size = 2.6, colour = "steelblue") +
  geom_point(data = beaches, aes(lon, lat), colour = "firebrick", size = 2.5) +
  geom_text(data = beaches, aes(lon, lat, label = name), hjust = -0.15, size = 3) +
  geom_point(data = buoys, aes(lon, lat), shape = 17, size = 2.5) +
  geom_text(data = buoys, aes(lon, lat, label = paste("NDBC", name)), vjust = -0.9, size = 2.6) +
  coord_quickmap(xlim = c(-125.5, -123.3), ylim = c(45.9, 48.0)) +
  labs(x = NULL, y = NULL, title = "Study area",
       subtitle = paste("Red: management beaches. Triangles: open-coast buoys (SST anomaly).\n",
                        gauge_note)) +
  theme_ms(9)
save_fig(p_map, "fig_study_area", 6, 6.5)

survey <- read_csv(file.path(DERIVED, "survey_beach_year.csv"), show_col_types = FALSE) %>%
  filter(!is.na(pre_recruits)) %>% mutate(beach = factor(beach, BEACHES))
p_ts <- survey %>% pivot_longer(c(pre_recruits, recruits), names_to = "class") %>%
  mutate(class = recode(class, pre_recruits = "Pre-recruits (<76 mm)", recruits = "Recruits (>=76 mm)")) %>%
  ggplot(aes(survey_year, value / 1e6, colour = class)) +
  geom_line() + geom_point(size = 1) +
  scale_y_log10() + facet_wrap(~ beach, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c("steelblue", "firebrick"), name = NULL) +
  labs(x = "Survey year", y = "Estimated abundance (millions, log scale)",
       title = "WDFW stock-assessment abundance estimates, 1997-2024") +
  theme_ms(9)
save_fig(p_ts, "fig_abundance_timeseries", 6.5, 8)

cohort <- read_csv(file.path(DERIVED, "cohort_table.csv"), show_col_types = FALSE)
p_env <- cohort %>% filter(beach == "Copalis", year_class %in% 1990:2024) %>%
  select(year_class, beuti_larval:cuti_winter) %>%
  pivot_longer(-year_class) %>%
  mutate(name = recode(name, beuti_larval = "BEUTI May-Aug (47N)", sst_larval = "SST anomaly May-Sep (degC)",
                       pdo_larval = "PDO May-Sep", q_freshet = "Columbia discharge Apr-Jun (m3/s)",
                       cuti_winter = "CUTI Nov-Feb (47N)")) %>%
  ggplot(aes(year_class, value)) + geom_line() + geom_point(size = 1) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = "firebrick", linewidth = 0.5) +
  facet_wrap(~ name, ncol = 1, scales = "free_y") +
  labs(x = "Year class (spawning year Y)", y = NULL,
       title = "Pre-specified cohort-aligned predictors", subtitle = "Red: linear trend") +
  theme_ms(9)
save_fig(p_env, "fig_predictor_timeseries", 6.5, 8)

message("07_figures_overview: done")

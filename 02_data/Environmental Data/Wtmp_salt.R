## Water Temp and Salinity data from buoys on the West Coast 

# install.packages("rerddapXtracto", type = "binary")


## Load Packages
load.lib <- c("tidyverse","ncdf4", "rerddap", "openxlsx", "rerddapXtracto") # List of required packages, add ones you'd like to load
install.lib <- load.lib[!load.lib %in% installed.packages()] # Select missing packages
for(lib in install.lib) install.packages(lib,dependencies=TRUE) # Install missing packages + dependencies
sapply(load.lib,require,character=TRUE) # Load all packages.


# library(rerddapXtracto)
# library(ncdf4)
# library(rerddap)
# library(tidyverse)

theme_set(theme_light())


## Grabbing data from the NDBC buoys first
info('cwwcNDBCMet')
Wtmp <-tabledap(
  'cwwcNDBCMet', 
  fields=c('station', 'latitude',  'longitude', 'time', 'wtmp'), 
  'time>=1990-01-01',   'time<=2026-01-01', 
  'latitude>=46','latitude<=48.5', 'longitude>=-125','longitude<=-123.8'
)


## Getting list of stations with lat and long 
Wtmp_sts <- Wtmp |> distinct(latitude,longitude, station)
Wtmp_sts <- Wtmp_sts |> mutate(latitude=as.numeric(latitude), longitude=as.numeric(longitude))

ggplot()+ geom_text(data=Wtmp_sts, aes(longitude, latitude, label=station)) 
        # + geom_sf(data=WA_coast)


Wtmp <- as_tibble(Wtmp) %>%
  mutate(date = as.Date(time))

Wtmp$time <- as.POSIXct(Wtmp$time , format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")


daily_wtmp_summary <- Wtmp %>%
  mutate(wtmp = as.numeric(wtmp)) %>%
  group_by(date, station) %>%
  summarize(
    wtmp_max  = max(wtmp, na.rm = TRUE),
    wtmp_mean = mean(wtmp, na.rm = TRUE),
    wtmp_sd   = sd(wtmp, na.rm = TRUE),
    wtmp_min  = min(wtmp, na.rm = TRUE),
    n_obs     = sum(!is.na(wtmp)),
    .groups = "drop"
  ) %>%
  # Remove days with no valid observations
  filter(n_obs > 0)


write.xlsx(daily_wtmp_summary, "02_data/Environmental Data/daily_wtmp_summary.xlsx",sheetName = "data",append = TRUE)


wtmp_monthly <- Wtmp %>%
  mutate(
    wtmp = as.numeric(wtmp),
    year  = year(date),
    month = month(date)
  ) %>%
  group_by(year, month, station) %>%
  summarize(
    wtmp_max  = max(wtmp, na.rm = TRUE),
    wtmp_mean = mean(wtmp, na.rm = TRUE),
    wtmp_sd   = sd(wtmp, na.rm = TRUE),
    wtmp_min  = min(wtmp, na.rm = TRUE),
    n_obs     = sum(!is.na(wtmp)),
    .groups   = "drop"
  ) %>%
  filter(n_obs > 0)

write.xlsx(wtmp_monthly, "02_data/Environmental Data/monthly_wtmp_summary.xlsx",sheetName = "data",append = TRUE)


half_monthly_wtmp_summary <- Wtmp %>%
  mutate(
    wtmp = as.numeric(wtmp),
    year = year(date),
    month = month(date),
    # Create the half-month flag
    half = ifelse(day(date) <= 15, "H1", "H2")
  ) %>%
  group_by(year, month, half, station) %>%
  summarize(
    wtmp_max  = max(wtmp, na.rm = TRUE),
    wtmp_mean = mean(wtmp, na.rm = TRUE),
    wtmp_sd   = sd(wtmp, na.rm = TRUE),
    wtmp_min  = min(wtmp, na.rm = TRUE),
    n_obs     = sum(!is.na(wtmp)),
    .groups   = "drop"
  ) %>%
  filter(n_obs > 0)

write.xlsx(half_monthly_wtmp_summary, "02_data/Environmental Data/half_monthly_wtmp_summary.xlsx",sheetName = "data",append = TRUE)


Wtmp %>%
  group_by(station)



MonthlyWtmp <- Wtmp |>
  group_by(date, station) |>
  mutate(
    wtmp  = as.numeric(wtmp),          # coerce to numeric — non-numeric values become NA
    Month = month(time),
    Year  = year(time)
  ) |>
  group_by(station, latitude, longitude, Year, Month) |>
  reframe(
    AvgWtmp = mean(wtmp, na.rm = TRUE),
    SDwtmp  = sd(wtmp,   na.rm = TRUE),
    MaxWtmp = max(wtmp,  na.rm = TRUE),
    wtmp_min  = min(wtmp, na.rm = TRUE)
  )



library(rerddap)

# 1. Verify the dataset exists and get correct names
metadata <- info('backyardbuoys_quinault_north', url = "https://erddap.backyardbuoys.org/erddap/")

metadata

# 2. Attempt a pull with a more recent date
QinNorth <- tabledap(
  'backyardbuoys_quinault_north', 
  fields = c('buoy_id', 'latitude', 'longitude', 'time', 'sea_water_temperature'), 
  'time>=2024-01-01', # Using a recent date
  'latitude>=46', 'latitude<=48.5', 
  'longitude>=-125', 'longitude<=-123.8',
  url = "https://erddap.backyardbuoys.org/erddap/"
)

head(QinNorth)



## Can also get Wtmp from the "Backyard buoys" of Quiluete and Quinault 

QinNorth  <-tabledap(
  'backyardbuoys_quinault_north', 
  fields=c('buoy_id', 'latitude',  'longitude', 'time','sea_water_temperature'), 
  'time>=1997-01-01',   'time<=2025-12-18', 
  'latitude>=46','latitude<=48.5', 'longitude>=-125','longitude<=-123.8',
  url="https://erddap.backyardbuoys.org/erddap/"
)


QinSouth  <-tabledap(
  'backyardbuoys_quinault_south', 
  fields=c('buoy_id', 'latitude',  'longitude', 'time','sea_surface_temperature'), 
  'time>=1997-01-01',   'time<=2025-12-18', 
  'latitude>=46','latitude<=48.5', 'longitude>=-125','longitude<=-123.8',
  url="https://erddap.backyardbuoys.org/erddap/"
)


QinCentral  <-tabledap(
  'backyardbuoys_quinault_mid', 
  fields=c('buoy_id', 'latitude',  'longitude', 'time','sea_surface_temperature'), 
  'time>=1997-01-01',   'time<=2025-12-18', 
  'latitude>=46','latitude<=48.5', 'longitude>=-125','longitude<=-123.8',
  url="https://erddap.backyardbuoys.org/erddap/"
)


info('backyardbuoys_quileute_north', url="https://erddap.backyardbuoys.org/erddap/")
QuilNorth  <-tabledap(
  'backyardbuoys_quileute_north', 
  fields=c('buoy_id', 'latitude',  'longitude', 'time','sea_surface_temperature'), 
  'time>=1997-01-01',   'time<=2025-12-18', 
  'latitude>=46','latitude<=48.5', 'longitude>=-125','longitude<=-123.8',
  url="https://erddap.backyardbuoys.org/erddap/"
)


QuilCentral  <-tabledap(
  'backyardbuoys_quileute_center', 
  fields=c('buoy_id', 'latitude',  'longitude', 'time','sea_surface_temperature'), 
  'time>=1997-01-01',   'time<=2025-12-18', 
  'latitude>=46','latitude<=48.5', 'longitude>=-125','longitude<=-123.8',
  url="https://erddap.backyardbuoys.org/erddap/"
)

QuilSouth <-tabledap(
  'backyardbuoys_quileute_south', 
  fields=c('buoy_id', 'latitude',  'longitude', 'time','sea_surface_temperature'), 
  'time>=1997-01-01',   'time<=2025-12-18', 
  'latitude>=46','latitude<=48.5', 'longitude>=-125','longitude<=-123.8',
  url="https://erddap.backyardbuoys.org/erddap/"
)


## Now joining data sets
BbWtmp <- rbind(QinCentral,QinNorth, QinSouth, QuilCentral, QuilNorth, QuilSouth)
colnames(BbWtmp) <- c("station", "latitude", "longitude","time", "wtmp" )
AllWtmp  <- rbind(BbWtmp, Wtmp)

sts <- AllWtmp |> distinct(station)

### Salinity 
CE_WstPt_Inner_shelf <- tabledap(
  'ooi-ce06issm-mfd37-03-ctdbpc000', 
  fields=c('station', 'latitude',  'longitude', 'time', 'sea_water_temperature','sea_water_practical_salinity', 'z'), 
  'time>=1997-01-01',   'time<=2026-01-01', 
  'latitude>=45','latitude<=48.5', 'longitude>=-125','longitude<=-123', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/"
)
CE_WstPt_Inner_shelf$station <- "WsptInnerShelf"

info(datasetid='ooi-ce06issm-mfd37-03-ctdbpc000', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/")


CE_WstPt_shelf <- tabledap(
  'ooi-ce07shsm-mfd37-03-ctdbpc000', 
  fields=c('station', 'latitude',  'longitude', 'time', 'sea_water_temperature','sea_water_practical_salinity', 'z'), 
  'time>=1997-01-01',   'time<=2026-01-01', 
  'latitude>=45','latitude<=48.5', 'longitude>=-125','longitude<=-123', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/"
)
CE_WstPt_shelf$station <- "WsptShelf"
info(datasetid='ooi-ce07shsm-mfd37-03-ctdbpc000', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/")


CE_WstPt_Outer_shelf <- tabledap(
  'ooi-ce09ossm-mfd37-03-ctdbpe000', 
  fields=c('station', 'latitude',  'longitude', 'time', 'sea_water_temperature','sea_water_practical_salinity', 'z'), 
  'time>=1997-01-01',   'time<=2026-01-01', 
  'latitude>=45','latitude<=48.5', 'longitude>=-125','longitude<=-123', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/"
)
CE_WstPt_Outer_shelf$station <- "WsptOuterShelf"

info(datasetid='ooi-ce09ossm-mfd37-03-ctdbpe000', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/")



WsptAllSalt <- rbind(CE_WstPt_Inner_shelf, CE_WstPt_shelf, CE_WstPt_Outer_shelf)




## The tables below have depth profiles of CTD data 
## Inner shelf depth profile 
Inner_shelf_profile <- tabledap(
  'ooi-ce06issp-sp001-09-ctdpfj000', 
  fields=c('station', 'latitude',  'longitude', 'time', 'sea_water_temperature_profiler_depth_enabled','sea_water_practical_salinity_profiler_depth_enabled','z'), 
  'time>=1997-01-01',   'time<=2025-12-22', 
  'latitude>=45','latitude<=48.5', 'longitude>=-125','longitude<=-123', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/"
)
info('ooi-ce06issp-sp001-09-ctdpfj000',url="https://erddap.dataexplorer.oceanobservatories.org/erddap/")


## Shelf depth profile 
Shelf_profile <- tabledap(
  'ooi-ce07shsp-sp001-08-ctdpfj000', 
  fields=c('station', 'latitude',  'longitude', 'time', 'sea_water_temperature_profiler_depth_enabled','sea_water_practical_salinity_profiler_depth_enabled','z'), 
  'time>=1997-01-01',   'time<=2025-12-22', 
  'latitude>=45','latitude<=48.5', 'longitude>=-125','longitude<=-123', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/"
)
info('ooi-ce07shsp-sp001-08-ctdpfj000',url="https://erddap.dataexplorer.oceanobservatories.org/erddap/")

## Outer shelf depth profile 
Outer_shelf_profile <- tabledap(
  'ooi-ce09ospm-wfp01-03-ctdpfk000', 
  fields=c('station', 'latitude',  'longitude', 'time', 'sea_water_temperature_profiler_depth_enabled','sea_water_practical_salinity_profiler_depth_enabled','z'), 
  'time>=1997-01-01',   'time<=2025-12-22', 
  'latitude>=45','latitude<=48.5', 'longitude>=-125','longitude<=-123', url="https://erddap.dataexplorer.oceanobservatories.org/erddap/"
)
info('ooi-ce09ospm-wfp01-03-ctdpfk000',url="https://erddap.dataexplorer.oceanobservatories.org/erddap/")


## Some of the variables load as characters, so changing them to numeric 
AllWtmp <- AllWtmp |> mutate(latitude= as.numeric(latitude), 
                             longitude=as.numeric(longitude), 
                             Date=as_date(time), 
                             wtmp=as.numeric(wtmp))

## Getting Daily and Monthly Averages and SD
DailyWtmp <- AllWtmp |> group_by(station,latitude, longitude, Date)|> reframe(AvgWtmp = mean(wtmp, na.rm=T), SDwtmp= sd(wtmp, na.rm=T))
MonthlyWtmp <- AllWtmp |> mutate(Month=month(Date), Year=year(Date)) |> group_by(station,latitude, longitude, Year,Month) |> reframe(AvgWtmp=mean(wtmp, na.rm=T), SDwtmp=sd(wtmp, na.rm=T))



WsptAllSalt <- WsptAllSalt |> mutate(latitude=as.numeric(latitude),
                                     longitude=as.numeric(longitude),
                                     Date=as_date(time), 
                                     sea_water_temperature=as.numeric(sea_water_temperature),
                                     sea_water_practical_salinity=as.numeric(sea_water_practical_salinity),
                                     z=as.numeric(z))                                                                                                  


DailySalt <- WsptAllSalt |> group_by(station, latitude, longitude, Date) |> reframe(AvgWtmp= mean(sea_water_temperature, na.rm=T), 
                                                                                    SDwtmp = sd(sea_water_temperature),
                                                                                    minSal = min(sea_water_practical_salinity, na.rm=T),
                                                                                    maxSal = max(sea_water_practical_salinity, na.rm=T),
                                                                                    AvgSal = mean(sea_water_practical_salinity, na.rm=T), 
                                                                                    SDsal= sd(sea_water_practical_salinity, na.rm=T))

DailySalt <- DailySalt %>% filter(!minSal == 0)
DailySalt <- DailySalt %>% filter(!minSal == Inf)


MonthlySalt <- DailySalt |> mutate(Month=month(Date), Year=year(Date)) |> group_by(station, latitude, longitude, Year, Month) |> 
  reframe(AvgWtmp= mean(sea_water_temperature, na.rm=T), SDwtmp= sd(sea_water_temperature, na.rm=T), 
          AvgSal = mean(sea_water_practical_salinity, na.rm=T), SDsal = sd(sea_water_practical_salinity, na.rm=T))


write.xlsx(DailySalt, "02_data/Environmental Data/DailySalt.xlsx",sheetName = "data",append = TRUE)



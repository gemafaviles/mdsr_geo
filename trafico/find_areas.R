library(sf)
library(tidyverse)
library(rgdal)
CM = read_sf("distritos_mitma4326.shp")
CM3 <- readOGR(dsn="distritos_mitma4326.shp", layer="distritos_mitma4326", encoding = "ESRI Shapefile")
CM3_sf <- st_as_sf(CM3)
CM4 = read_sf(dsn = "distritos_mitma4326.shp", layer="distritos_mitma4326", drivers = "ESRI Shapefile")

interes <- read.csv("PUNTOSMUR.csv")
interes_sf3 <- st_as_sf(interes, coords = c('lat', 'lon'), crs = st_crs(CM3))
interes_sf4 <- st_as_sf(interes, coords = c('lat', 'lon'), crs = st_crs(CM4))

puntos3 <- interes_sf3 %>% mutate(
  ID = as.integer(st_intersects(geometry, CM3_sf))
  , SECCION = if_else(is.na(ID), '', CM$ID[ID])
) 

puntos3


puntos4 <- interes_sf4 %>% mutate(
  ID = as.integer(st_intersects(geometry, CM4))
  , SECCION = if_else(is.na(ID), '', CM$ID[ID])
) 

puntos4



# Download data

# install.packages("mapSpain", dependencies = TRUE)

# Libraries----
library(ggplot2)
library(giscoR)
library(dplyr)
library(sf)
library(raster)
library(terra)
library(styler)

# Shapefiles----

# Hospitales en Toledo segun Eurostat
hosp_toledo <- gisco_get_healthcare(country = "ES") %>%
  filter(city == "TOLEDO") %>%
  st_write("data/hosp_toledo.geojson",
    append = FALSE
  )

# Ciudad de Toledo
library(mapSpain)
library(sf)

toledo <- esp_get_munic(munic = "^Toledo$")
toledo %>% st_write("data/toledo_ciudad.gpkg", append = FALSE)


# Tajo
rios <- esp_get_rivers(name = "Tajo")
rios %>% st_write("data/tajo_toledo.shp", append = FALSE)

# Rasters ----
raster::getData("alt", country = "ESP", path = "data/", mask = FALSE)

elev <- raster("data/ESP_alt.grd")

# Corta al bbox de la provincia de Toledo
tol_prov <- esp_get_prov("Toledo") %>%
  st_transform(st_crs(elev))
elev_crop <- crop(elev, st_bbox(tol_prov))

tol_prov %>% st_write("data/Toledo_prov.gpkg", append = FALSE)

# Únicamente para visualización!

# Reduce la resolución para resaltar el efecto pixel
elev_agg <- aggregate(elev_crop, 4)

# To terra
terra_elev <- rast(elev_agg)

terra::writeRaster(terra_elev, "data/Toledo_DEM.tiff", overwrite = TRUE)

# Tile

tile <- esp_getTiles(tol_prov, "IGNBase.Todo", zoommin = 1)
tile2 <- subset(tile, c(1, 2, 3))
terra::writeRaster(tile2, "data/Toledo_multi_tile.tiff", overwrite = TRUE)

## ----include=FALSE-------------------------------------------------------------------------------
rm(list = ls(all = TRUE))

Sys.setenv(MAPSPAIN_CACHE_DIR = "cache_dir")

knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  warning = FALSE,
  message = FALSE,
  tidy = "styler",
  out.width = "60%",
  fig.align = "center",
  dev = "ragg_png",
  dpi = 300
)


## ----tmin_import---------------------------------------------------------------------------------

library(readr)

# cada uno debe seleccionar el directorio donde tiene los datos, de ahí
# que sea conveniente trabajar con proyectos
tmin <- read_csv("data/tempmin.csv")


## ----tmin-head, echo=FALSE-----------------------------------------------------------------------
knitr::kable(head(tmin), caption = "Detalle del objeto tmin")


## ----fig.cap="Objetos en geoR"-------------------------------------------------------------------
library(dplyr)
library(geoR)

tmin_geoR <- tmin %>%
  filter(fecha == "2021-01-08") %>%
  # Seleccionamos las columnas de interés
  dplyr::select(longitud, latitud, tmin) %>%
  # Y creamos el objeto geodata
  as.geodata(
    coords.col = 1:2,
    data.col = 3
  )


summary(tmin_geoR)
plot(tmin_geoR)


## ------------------------------------------------------------------------------------------------
library(sf)

tmin_sf <- st_as_sf(tmin,
  coords = c("longitud", "latitud"),
  crs = 4326
)

tmin_sf


## ----fig.cap="Mapa de España (Sin Canarias)"-----------------------------------------------------
library(mapSpain)
# sf object
esp <- esp_get_ccaa() %>%
  # No vamos a usar Canarias en este análisis
  filter(ine.ccaa.name != "Canarias")


plot(esp$geometry) # Dibujamo el mapa de España menos las Islas Canarias


## ----chek_crs------------------------------------------------------------------------------------
st_crs(tmin_sf) == st_crs(esp)


## ------------------------------------------------------------------------------------------------
esp2 <- st_transform(esp, st_crs(tmin_sf))

st_crs(tmin_sf) == st_crs(esp2)


## ----fig.cap="Estaciones de AEMET en la Península Ibérica"---------------------------------------
library(ggplot2)

ggplot(esp2) +
  # Para graficar objetos sf debemos usar geom_sf()
  geom_sf() +
  geom_sf(data = tmin_sf) +
  theme_light() +
  labs(
    title = "Estaciones de monitoreo AEMET en  España",
    subtitle = "excluyendo las Islas Canarias"
  ) +
  theme(
    plot.title = element_text(
      size = 12,
      face = "bold"
    ),
    plot.subtitle = element_text(
      size = 8,
      face = "italic"
    )
  )


## ----plot-base-tmin, fig.cap="Mapa de puntos con temperatura mínima"-----------------------------
tmin_8enero <- tmin_sf %>%
  # seleccionamos el día y la variable
  filter(fecha == "2021-01-08")


plot(tmin_8enero["tmin"],
  main = "Temperatura mínima (8-enero-2021)",
  pch = 8
)


## ----spatial-plots, echo=FALSE, fig.cap="Mapa completo con temperatura mínima"-------------------

# Especificamos la paleta de color a utilizar
cortes <- c(-Inf, seq(-20, 20, 2.5), Inf)
colores <- hcl.colors(15, "PuOr", rev = TRUE)


ggplot() +
  geom_sf(
    data = esp2,
    fill = "grey99"
  ) +
  geom_sf(
    data = tmin_8enero,
    aes(color = tmin),
    size = 4,
    alpha = .7
  ) +
  labs(color = "Temp. mín") +
  scale_color_gradientn(
    colours = colores,
    breaks = cortes,
    labels = function(x) {
      paste0(x, "º")
    },
    guide = "legend"
  ) +
  theme_light() +
  labs(
    title = "Temperatura mínima (8-enero-2021)"
  ) +
  theme(
    plot.title = element_text(
      size = 12,
      face = "bold"
    ),
    plot.subtitle = element_text(
      size = 8,
      face = "italic"
    )
  )


## ------------------------------------------------------------------------------------------------
library(crsuggest)

sugiere <- suggest_crs(tmin_8enero, units = "m", limit = 5)

# Usamos la sugerencia del paquete
crs_sugerido <- st_crs(sugiere[1, ]$crs_proj4)

esp3 <- st_transform(esp2, crs_sugerido)
tmin_8enero3 <- st_transform(tmin_8enero, crs_sugerido)


## ----create_grid2--------------------------------------------------------------------------------
set.seed(9876) # Con esto aseguramos que el grid generado siempre es igual

malla_sf <- st_make_grid(
  esp3,
  cellsize = 8000
)


## ----malla, fig.cap="Malla de puntos para interpolación"-----------------------------------------

ggplot(esp3) +
  geom_sf() +
  geom_sf(
    data = malla_sf,
    size = 0.1,
    col = "red", alpha = 1,
    fill = NA
  ) +
  geom_sf(
    data = tmin_8enero3,
    aes(fill = "AEMET Stations"), size = 4, shape = 21,
    color = "blue"
  ) +
  scale_fill_manual(values = adjustcolor("blue", alpha.f = 0.2)) +
  theme_void() +
  theme(legend.position = "bottom") +
  labs(
    title = "Cuadrícula espacial para interpolar",
    fill = ""
  )


## ------------------------------------------------------------------------------------------------
# Calculamos centroide
malla_sf_cent <- st_centroid(malla_sf, of_largest_polygon = TRUE)

library(gstat)
tmin_idw <- idw(
  # Indicamos la variable que queremos interpolar
  tmin ~ 1,
  # Indicamos el conjunto de datos donde está la variable
  tmin_8enero3,
  # Indicamos la malla de destino, en sf
  newdata = malla_sf_cent,
  idp = 2.0 # Especifica la potencia de la IDW
)
head(tmin_idw)


## ---- fig.cap="Mapa raster con lineas de nivel"--------------------------------------------------
# Convertimos de sf a SpatiaPixels
# Esto funciona porque nuestros puntos sf están espaciados regularmente

tmin_pixels <- tmin_idw %>%
  as("Spatial") %>%
  as("SpatialPixels")


library(raster)
# Creamos un raster de nuestros pixels
rast_esp <- raster(tmin_pixels)

# Transferimos valores del objeto sf al raster
rast_esp2 <- rasterize(
  tmin_idw,
  rast_esp,
  field = "var1.pred", ## valores de predicción
  fun = mean
)

# Además, podemos recortar el raster a la forma de España

rast_esp_mask <- mask(rast_esp2, esp3)

plot(rast_esp_mask, col = colores)
contour(rast_esp2, add = TRUE)


## ----fig.cap="Mapa con ggplot2 y lineas de nivel"------------------------------------------------

# Creo una tabla para geom contour
coordenadas <- st_coordinates(tmin_idw)
valor <- tmin_idw$var1.pred

idw_df <- data.frame(
  # Necesitamos redondear las coordenadas
  latitud = round(coordenadas[, 2], 6),
  longitud = round(coordenadas[, 1], 6),
  tmin = valor
)

ggplot() +
  geom_contour_filled(
    data = idw_df,
    aes(x = longitud, y = latitud, z = tmin),
    na.rm = TRUE,
    breaks = cortes
  ) +
  # Reajustamos la escala de colores
  scale_fill_manual(values = colores) +
  # CCAA
  geom_sf(data = esp3, fill = NA) +
  theme_minimal() +
  theme(axis.title = element_blank()) +
  labs(
    fill = "Temp. (º)",
    title = "Temperatura mínima interpolada",
    subtitle = "8 de Enero 2021",
    caption = "Datos: AEMET"
  )


## ----importa_renta-------------------------------------------------------------------------------
# Usaremos paquetes del tidyverse
library(dplyr)
library(readr)

renta <- read_csv("data/renta_municipio.csv", na = ".")


## ----importa_muni--------------------------------------------------------------------------------
library(sf)
munis <- st_read("data/municipios.gpkg", quiet = TRUE)


## ----importa_renta_tabla-------------------------------------------------------------------------
head(renta)


## ----importa_munis_tabla-------------------------------------------------------------------------
head(munis)


## ----noblejas------------------------------------------------------------------------------------
# Miro un municipio: Noblejas

renta[grep("Noblejas", renta$Unidad), ]

munis[grep("Noblejas", munis$name), c("name", "cpro", "cmun")]


## ----limpia_renta--------------------------------------------------------------------------------

# Creo una función y la aplico a toda la columna
extrae_codigo <- function(x) {
  unlist(strsplit(x, " "))[1]
}

renta$codigo_ine <- sapply(as.character(renta$Unidad), extrae_codigo)

head(renta[c("Unidad", "codigo_ine")])


## ----codigo_ine----------------------------------------------------------------------------------

munis$codigo_ine <- paste0(munis$cpro, munis$cmun)

head(munis[, c("name", "codigo_ine")])


## ----cruce_renta---------------------------------------------------------------------------------

munis_renta <- munis %>%
  left_join(renta) %>%
  dplyr::select(name, cpro, cmun, `2019`)


## ----cruces_espaciales---------------------------------------------------------------------------

# Miramos la clase de munis_renta

class(munis_renta)

# Es un sf, por tanto espacial

# ¿Que pasa si realizamos el cruce de la otra manera?
renta %>%
  left_join(munis) %>%
  dplyr::select(name, cpro, cmun, `2019`) %>%
  class()


## ----basic, fig.cap="Histograma de la Renta per cápita en España (2019)"-------------------------

library(ggplot2)

munis_renta %>%
  ggplot(aes(x = `2019`)) +
  geom_histogram(color = "darkblue", fill = "lightblue") +
  scale_x_continuous(labels = scales::label_number_auto()) +
  scale_y_continuous(labels = scales::label_percent()) +
  labs(
    y = "",
    x = "Renta neta media por persona (€)"
  )


## ----maparenta1, fig.cap="Renta neta media por persona"------------------------------------------

ggplot(munis_renta) +
  # Usamos geom_sf, y como aes() lo que queremos mostrar, en este caso, el
  # color del polígono representa la renta. Vamos a retirar los bordes con
  # color = NA
  geom_sf(aes(fill = `2019`), color = NA) +
  theme_minimal() +
  scale_fill_continuous(labels = scales::label_number(
    big.mark = ".",
    decimal.mark = ",",
    suffix = " €"
  )) +
  labs(
    title = "Renta neta media por persona",
    caption = "Datos: INE"
  )


## ----maparenta2, fig.cap="Renta neta media por persona con paleta de colores alternativa"--------

munis_renta_clean <- munis_renta %>% filter(!is.na(`2019`))

ggplot(munis_renta_clean) +
  geom_sf(aes(fill = `2019`), color = NA) +
  # Cambiamos la paleta de colores, vamos a usar una paleta denominada Inferno,
  # ya incluida en base R con hcl.colors

  # Como son datos continuos, puedo usar Inferno
  scale_fill_gradientn(
    colours = hcl.colors(20, "Inferno", rev = TRUE),
    labels = scales::label_number(
      big.mark = ".",
      decimal.mark = ",",
      suffix = " €"
    )
  ) +
  theme_minimal() +
  labs(
    title = "Renta neta media por persona",
    caption = "Datos: INE"
  )


## ----deciles, message=FALSE, fig.cap="Deciles de renta"------------------------------------------

library(classInt)
# Vamos a probar 3 métodos de clasificación: Deciles, tramos de Renta
# equidistantes y Fisher and Jenks

deciles <- classIntervals(munis_renta_clean$`2019`,
  style = "quantile", n = 10
)
deciles
plot(deciles, pal = hcl.colors(20, "Inferno"), main = "Deciles")


## ----equidist, message=FALSE, fig.cap="Tramos de renta equidistante"-----------------------------

# Tramos equidistantes en términos de renta
equal <- classIntervals(munis_renta_clean$`2019`,
  style = "equal", n = 10
)
equal
plot(equal, pal = hcl.colors(20, "Inferno"), main = "Equidistantes")


## ----fisher, message=FALSE, fig.cap="Tramos de renta usando Fisher-Jenks"------------------------

fisher <- classIntervals(munis_renta_clean$`2019`,
  style = "fisher",
  # Fuerzo para mejorar la comparación entre métodos
  n = 10
)
fisher
plot(fisher,
  pal = hcl.colors(20, "Inferno"),
  main = "Fisher-Jenks"
)


## ----mapa-deciles, message=FALSE, fig.cap="Mapa por deciles de renta"----------------------------
# Extraigo los valores de corte
breaks_d <- deciles$brks

# Y creo unas etiquetas básicas para cada clase
# Creo una función específica para crear etiquetas formateadas
label_fun <- function(x) {
  l <- length(x)
  eur <- paste0(prettyNum(round(x, 0),
    decimal.mark = ",",
    big.mark = "."
  ), " €")

  labels <- paste(eur[-l], "-", eur[-1])
  labels[1] <- paste("<", eur[1])
  labels[l - 1] <- paste(">", eur[l - 1])
  return(labels)
}

labels_d <- label_fun(breaks_d)

munis_renta_clean$Deciles <- cut(munis_renta_clean$`2019`,
  breaks = breaks_d,
  labels = labels_d,
  include.lowest = TRUE
)

ggplot(munis_renta_clean) +
  # Cambiamos la variable que usamos para crear el mapa
  geom_sf(aes(fill = Deciles), color = NA) +
  # Necesito cambiar el scale, ya no es continua
  scale_fill_manual(values = hcl.colors(length(labels_d),
    "Inferno",
    rev = TRUE
  )) +
  theme_minimal() +
  labs(
    title = "Renta neta media por persona",
    caption = "Datos: INE"
  )


## ----mapa-equal, message=FALSE, fig.cap="Mapa por tramos de renta equidistantes"-----------------

breaks_e <- equal$brks
labels_e <- label_fun(breaks_e)

munis_renta_clean$Equal <- cut(munis_renta_clean$`2019`,
  breaks = breaks_e,
  labels = labels_e,
  include.lowest = TRUE
)

ggplot(munis_renta_clean) +
  # Cambiamos la variable que usamos para crear el mapa
  geom_sf(aes(fill = Equal), color = NA) +
  scale_fill_manual(values = hcl.colors(length(labels_e),
    "Inferno",
    rev = TRUE
  )) +
  theme_minimal() +
  labs(
    title = "Renta neta media por persona",
    caption = "Datos: INE"
  )


## ----mapa-fisher, message=FALSE, fig.cap="Mapa por tramos según Fisher-Jenks"--------------------

breaks_f <- fisher$brks
labels_f <- label_fun(breaks_f)

munis_renta_clean$`Fisher-Jenks` <- cut(munis_renta_clean$`2019`,
  breaks = breaks_f,
  labels = labels_f,
  include.lowest = TRUE
)

ggplot(munis_renta_clean) +
  # Cambiamos la variable que usamos para crear el mapa
  geom_sf(aes(fill = `Fisher-Jenks`), color = NA) +
  scale_fill_manual(values = hcl.colors(length(labels_f),
    "Inferno",
    rev = TRUE
  )) +
  theme_minimal() +
  labs(
    title = "Renta neta media por persona",
    caption = "Datos: INE"
  )


## ----trucado, echo=FALSE, fig.cap="Ejemplo de visualización sesgada"-----------------------------

breaks_s <- c(seq(5500, 12000, 500), 90000)
labels_s <- label_fun(breaks_s)

munis_renta_clean$Sesgada <- cut(munis_renta_clean$`2019`,
  breaks = breaks_s,
  labels = labels_s,
  include.lowest = TRUE
)

ggplot(munis_renta_clean) +
  geom_sf(aes(fill = Sesgada), color = NA) +
  scale_fill_manual(values = c(hcl.colors(20,
    "Blue-Red2",
    rev = FALSE
  )[1:12], hcl.colors(10, "Reds2", rev = TRUE)[8:10])) +
  theme_minimal() +
  labs(
    title = "Renta neta media por persona",
    caption = "Datos: INE"
  )


## ------------------------------------------------------------------------------------------------
library(readr)
library(dplyr)

# En este caso el archivo está en la carpeta "data" de nuestro proyecto
crimen <- read_csv("data/crime-data-Valencia.csv")


summary(crimen)


## ----coods-lonlat, echo=FALSE--------------------------------------------------------------------
crimen %>%
  head() %>%
  dplyr::select(crime_lon, crime_lat) %>%
  knitr::kable(caption = "Crímenes en Valencia; Coordenadas")


## ----crimen1, fig.cap="Crímenes en Valencia"-----------------------------------------------------

library(sf)
# Objeto sf sin CRS

crimen_sf <- st_as_sf(
  crimen,
  coords = c(
    "crime_lon",
    "crime_lat"
  ),
  crs = st_crs(4326)
)

# Comprobamos con un mapa base

library(mapSpain)
library(ggplot2)

# Usamos imagen como mapa de fondo
tile <- esp_getTiles(crimen_sf, "IDErioja",
  zoommin = 1,
  crop = TRUE
)

ggplot() +
  layer_spatraster(tile) +
  geom_sf(
    data = crimen_sf,
    col = "blue",
    size = 0.3,
    alpha = 0.3
  )


## ----crimen2, fig.cap="Crímenes en Valencia (2010)"----------------------------------------------
crimen_2010_sf <- crimen_sf %>%
  filter(
    year == "2010"
  )

ggplot() +
  layer_spatraster(tile) +
  geom_sf(
    data = crimen_2010_sf,
    col = "blue",
    size = 0.3,
    alpha = 0.3
  )


## ----objeto_ppp----------------------------------------------------------------------------------

# Extraigo Valencia con mapSpain

valencia <- esp_get_munic(munic = "^Valencia$") %>%
  # Necesito proyectar, en este caso usamos ETRS89-UTM huso 30 EPSG:25830
  st_transform(25830)



library(spatstat)
# Necesitamos un recinto de observación: owin

val_owin <- as.owin(valencia)

# Extraemos las coordenadas de los crímenes. Han de estar en el mismo CRS
# que el owin

coords <- crimen_2010_sf %>%
  st_transform(25830) %>%
  st_coordinates()

mydata_ppp <- ppp(
  x = as.numeric(coords[, 1]),
  y = as.numeric(coords[, 2]),
  window = val_owin
)

plot(mydata_ppp)


## ------------------------------------------------------------------------------------------------
summary(mydata_ppp)


## ----cuadrante, fig.cap="Crímenes en Valencia por cuadrantes (2010)"-----------------------------
## Hallamos los cuadrantes
cuadrante <- quadratcount(mydata_ppp,
  nx = 5,
  ny = 5
)

## Dibujamos el número de crímenes que hay en cada cuadrante
plot(mydata_ppp, pch = 1, main = "")
plot(cuadrante, add = TRUE, col = "red", cex = 1.2)


## ----intensidad-ripley, fig.cap="Intensidad de crímenes estimada con la K-Ripley"----------------
densidad <- density(mydata_ppp)
plot(densidad, main = " ")
points(mydata_ppp, pch = "+", cex = 0.5)


library(readr)
library(dplyr)
library(sf)
library(ggplot2)
library(nominatimlite)
library(tidyr)
library(mapSpain)


# Importa zonas
shape <- st_read("img/covid/distritos_mitma.shp")


# Localiza zona donde está Barajas
barajas <- geo_lite_sf("Aeropuerto de Barajas") %>%
  st_transform(st_crs(shape)) %>% 
  st_intersection(shape, .)

id_bar <- barajas$ID


# Usa centroides
shape_cent <- st_centroid(shape, of_largest_polygon = TRUE)


# Y saca coordenadas para que sea mas facil trabajar luego
coords <- as.data.frame(st_coordinates(shape_cent))

df_cent <- bind_cols(st_drop_geometry(shape_cent),
                         coords)


# Importa datos de movilidad. Ultimos domingos de feb y mar 2020

mov_feb20 <- read_delim("img/covid/20200223_maestra_1_mitma_distrito.txt", 
                       delim = "|", escape_double = FALSE, trim_ws = TRUE) %>%
  mutate(date = as.Date("2020-02-23"))

mov_mar20 <- read_delim("img/covid/20200329_maestra_1_mitma_distrito.txt", 
                        delim = "|", escape_double = FALSE, trim_ws = TRUE) %>%
  mutate(date = as.Date("2020-03-29"))


mov_feb21 <- read_delim("img/covid/20210228_maestra_1_mitma_distrito.txt", 
                        delim = "|", escape_double = FALSE, trim_ws = TRUE) %>%
  mutate(date = as.Date("2021-02-28"))

mov_mar21 <- read_delim("img/covid/20210228_maestra_1_mitma_distrito.txt", 
                        delim = "|", escape_double = FALSE, trim_ws = TRUE) %>%
  mutate(date = as.Date("2021-03-28"))



# Une, filtra y resume
mov_tot <- bind_rows(mov_feb20,
                    mov_mar20,
                    mov_feb21,
                    mov_mar21) %>% 
  filter(origen != destino) %>%
  filter(origen == id_bar) %>%
  group_by(date, origen, destino) %>% summarise(viajes = sum(viajes))


# Añade coords

orig <- shape_cent2
names(orig) <- c("origen", "x_0", "y_0")

dest <- shape_cent2
names(dest) <- c("destino", "x_f", "y_f")

mov_tot_coords <- mov_tot %>% inner_join(orig) %>%
  inner_join(dest)



# Limpia si hay nulos
mov_tot_coords <- drop_na(mov_tot_coords)

# Crea linestrings


geom <- lapply(seq_len(nrow(mov_tot_coords)), function(x){
  m <- matrix(as.numeric(mov_tot_coords[x, c(5,7,6,8)]), nrow=2)
  st_linestring(m)
  
}) %>% st_as_sfc(crs=st_crs(shape))

# Añade a los datos donde hat viajes
lines <- st_as_sf(mov_tot_coords, geom)

# Shape de España
esp_ccaa <- esp_get_ccaa(moveCAN = FALSE) %>% st_transform(st_crs(lines))


# Plot
ggplot(esp_ccaa) +
  geom_sf(data=lines, aes(size=viajes), color="blue", alpha = 0.2) +
  geom_sf(fill=NA) +
  scale_size_continuous(range=c(0.05,2)) + 
  facet_wrap(vars(date), ncol = 2) +
  coord_sf(xlim = c(-436720.6, 1126308.7),
           ylim = c(3876597.0, 4859001.7)) +
  labs(size = "Viajeros")



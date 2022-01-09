library(readr)
library(dplyr)
library(sf)
library(ggplot2)
library(nominatimlite)
library(tidyr)
library(mapSpain)
library(giscoR)

# Importa zonas
shape <- st_read("img/covid/distritos_mitma.shp")


# Localiza zonas donde están los aeropuertos españoles
airp <- gisco_get_airports(country = "Spain")

airp_ids <- airp %>%
  st_transform(st_crs(shape)) %>%
  st_intersection(shape, .)

id_bar <- airp_ids$ID


# Usa centroides
shape_cent <- st_centroid(shape, of_largest_polygon = TRUE)


# Y saca coordenadas para que sea mas facil trabajar luego
coords <- as.data.frame(st_coordinates(shape_cent))

df_cent <- bind_cols(
  st_drop_geometry(shape_cent),
  coords
)


# Importa datos de movilidad. Ultimos domingos de feb y mar 2020

mov_feb20 <- read_delim("img/covid/20200223_maestra_1_mitma_distrito.txt",
  delim = "|", escape_double = FALSE, trim_ws = TRUE
) %>%
  mutate(date = as.Date("2020-02-23"))

mov_mar20 <- read_delim("img/covid/20200329_maestra_1_mitma_distrito.txt",
  delim = "|", escape_double = FALSE, trim_ws = TRUE
) %>%
  mutate(date = as.Date("2020-03-29"))


mov_feb21 <- read_delim("img/covid/20210228_maestra_1_mitma_distrito.txt",
  delim = "|", escape_double = FALSE, trim_ws = TRUE
) %>%
  mutate(date = as.Date("2021-02-28"))

mov_mar21 <- read_delim("img/covid/20210328_maestra_1_mitma_distrito.txt",
  delim = "|", escape_double = FALSE, trim_ws = TRUE
) %>%
  mutate(date = as.Date("2021-03-28"))



# Une, filtra y resume
mov_tot <- bind_rows(
  mov_feb20,
  mov_mar20,
  mov_feb21,
  mov_mar21
) %>%
  filter(origen != destino) %>%
  filter(origen %in% id_bar) %>%
  filter(destino %in% id_bar) %>%
  group_by(date, origen, destino) %>%
  summarise(viajes = sum(viajes))


# Añade coords

orig <- df_cent
names(orig) <- c("origen", "x_0", "y_0")

dest <- df_cent
names(dest) <- c("destino", "x_f", "y_f")

mov_tot_coords <- mov_tot %>%
  inner_join(orig) %>%
  inner_join(dest)



# Limpia si hay nulos
mov_tot_coords <- drop_na(mov_tot_coords)

# Crea linestrings


geom <- lapply(seq_len(nrow(mov_tot_coords)), function(x) {
  m <- matrix(as.numeric(mov_tot_coords[x, c(5, 7, 6, 8)]), nrow = 2)
  st_linestring(m)
}) %>% st_as_sfc(crs = st_crs(shape))

# Añade a los datos donde hat viajes
lines <- st_as_sf(mov_tot_coords, geom)

# Shape de España
esp_ccaa <- esp_get_ccaa(moveCAN = FALSE) %>% st_transform(st_crs(lines))


# Plot
ggplot(esp_ccaa) +
  geom_sf(data = lines, aes(size = viajes), color = "blue", alpha = 0.2, show.legend = FALSE) +
  geom_sf(fill = NA, size=0.1) +
  scale_size_continuous(range = c(0.05, 6),
                        labels = scales::number_format(big.mark = ".",
                                                       decimal.mark = ",")) +
  facet_wrap(vars(date), ncol = 2) +
  coord_sf(
    xlim = c(-436720.6, 1126308.7),
    ylim = c(3876597.0, 4859001.7)
  ) +
  labs(size = "Viajeros",
       title="Flujo de viajeros entre aeropuertos nacionales",
       subtitle = "Nº viajeros, últimos domingos de mes",
       caption = "Datos: Análisis de la movilidad en España, MITMA") +
  theme_void() +
  theme(plot.title =  element_text(hjust = .5, face = "bold"),
        plot.subtitle = element_text(hjust = .5, margin = margin(b=20)),
        plot.background = element_rect(fill="white", color=NA),
        legend.box.margin = margin(10, 10, 10, 10))

ggsave("img/movilidad_covid.png",
       dpi = 300)
        

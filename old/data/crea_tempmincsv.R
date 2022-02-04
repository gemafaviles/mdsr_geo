library(climaemet)
library(tidyverse)

stations <- aemet_stations() %>%
  filter(!indicativo %in% c(
    "1249I",
    "1111",
    "1014",
    "8416"
  )) %>%
  select(indicativo, longitud, latitud)

stations %>%
  select(longitud, latitud) %>%
  group_by(longitud, latitud) %>%
  summarise(n = n()) %>%
  arrange(desc(n))

clim_data <- aemet_daily_clim(
  start = "2021-01-06",
  end = "2021-01-10",
  return_sf = FALSE
)

# Join

end <- clim_data %>%
  filter(
    !provincia %in% c(
      "STA. CRUZ DE TENERIFE",
      "LAS PALMAS"
    )
  ) %>%
  inner_join(stations, by = "indicativo") %>%
  select(fecha, indicativo, nombre, provincia, tmin, longitud, latitud, altitud)

end <- drop_na(end)

write_csv(end, "data/tempmin.csv", na = "")

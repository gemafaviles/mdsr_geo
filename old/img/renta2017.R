library(sf)
library(readxl)
library(dplyr)
library(mapSpain)


renta <- read_xlsx("img/renta/30824.xlsx",
  na = "NA"
)


# Select ID
renta$LAU_CODE <- sapply(strsplit(renta$CUSEC, " "), "[", 1)

# Select municipios

munis <- esp_get_munic_siane(year = 2017)


# Join

munis_renta <- munis %>%
  left_join(renta) %>%
  mutate(Renta_hogar = as.numeric(RNMH_2017))


## ¿Son longitud y latitud significativas para explicar la renta?
# ------------------------------------------------------------------------------
renta_hogar_y <- munis_renta$Renta_hogar
long <- st_coordinates(munis_renta$geometry)[, 1]
lat <- st_coordinates(munis_renta$geometry)[, 2]

df_renta_coord <- as.data.frame(cbind(renta_hogar_y, long, lat))
summary(is.na(df_renta_coord))
df_renta_coord <- na.omit(df_renta_coord)

## lm --- no salen significativas. Sorpresa!
fit_lm <- lm(log(renta_hogar_y) ~ long + lat, df_renta_coord)
summary(fit_lm)

## GAM --- sí salen significativas. Lo esperado!
library(mgcv)
fit_gam <- gam(log(renta_hogar_y) ~ s(long, bs = "ps") + s(lat, bs = "ps"), data = df_renta_coord)
summary(fit_gam)

# ------------------------------------------------------------------------------

# Create bins
library(classInt)

breaks <- classIntervals(munis_renta$Renta_hogar, n = 10, style = "quantile")
munis_renta$cuts <- cut(munis_renta$Renta_hogar, breaks$brks, labels = FALSE)

# Create labs
df <- data.frame(cuts = c(1:10, NA))
df$labs <- c(paste0(
  prettyNum(round(breaks$brks, 0), big.mark = ".")[-length(breaks$br)],
  " - ",
  prettyNum(round(breaks$brks, 0), big.mark = ".")[-1]
), "No disponible")

df$labs <- as.factor(df$labs)
munis_renta <- munis_renta %>% left_join(df)


library(ggplot2)
ccaa <- esp_get_ccaa_siane(year = 2017)

canbox <- esp_get_can_box()

ggplot(munis_renta) +
  geom_sf(aes(fill = labs), color = NA) +
  geom_sf(data = ccaa, fill = NA, color = "grey10", size = 0.2) +
  geom_sf(data = canbox, color = "grey10", size = 0.2) +
  scale_fill_manual(values = c(hcl.colors(10, "Blue-Red"), "grey10")) +
  theme_void() +
  labs(
    title = "Renta neta media por hogar (2017)",
    fill = "Deciles (€)",
    caption = "Datos: INE"
  ) +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    plot.title = element_text(hjust = .5),
    legend.box.margin = margin(10, 10, 10, 10)
  )

ggsave("img/renta2017.png", dpi = 300, bg = "white")

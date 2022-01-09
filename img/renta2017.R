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

ggplot(munis_renta) +
  geom_sf(aes(fill = labs), color = NA) +
  geom_sf(data = ccaa, fill = NA, color = "grey10", size = 0.2) +
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

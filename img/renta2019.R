library(sf)
library(readr)
library(dplyr)
library(mapSpain)


renta <- read_csv("data/renta_municipio.csv",
             na = "."
)


# Select ID
renta$LAU_CODE <- sapply(strsplit(renta$Unidad, " "), "[", 1)

# Select municipios
munis <- esp_get_munic_siane(year = 2019)


# Join

munis_renta <- munis %>%
  left_join(renta) %>%
  mutate(Renta_pers = `2019`)



# Create bins
library(classInt)

breaks <- classIntervals(munis_renta$Renta_pers, n = 10, style = "quantile")
munis_renta$cuts <- cut(munis_renta$Renta_pers, breaks$brks, labels = FALSE)
print(breaks)
classInt::c
# Create labs
df <- data.frame(cuts = c(1:10, NA))
df$labs <- c(paste0(
  prettyNum(round(breaks$brks, 0), big.mark = ".")[-length(breaks$br)],
  " - ",
  prettyNum(round(breaks$brks, 0), big.mark = ".")[-1]
), "No disponible")



df$labs <- factor(df$labs, levels = df$labs)


levels(df$labs)
munis_renta <- munis_renta %>% left_join(df)

library(ggplot2)
ccaa <- esp_get_ccaa_siane(year = 2019)

canbox <- esp_get_can_box()

ggplot(munis_renta) +
  geom_sf(aes(fill = labs), color = NA) +
  geom_sf(data = ccaa, fill = NA, color = "grey10", size = 0.2) +
  geom_sf(data=canbox, color ="grey10", size = 0.2)+
  scale_fill_manual(values = c(hcl.colors(10, "Blue-Red"), "black")) +
  theme_void() +
  labs(
    title = "Renta neta media per cápita (2019)",
    fill = "Deciles (€)",
    caption = "Datos: INE"
  ) +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    plot.title = element_text(hjust = .5),
    legend.box.margin = margin(10, 10, 10, 10)
  )

ggsave("img/renta2019.png", dpi = 300, bg = "white")







# load all four datasets --------------------------------------------------

df.klw <- read_csv(file.path(db, 
                             "/datacode", 
                             'DOSE_climate_data/DOSEV2_W5E5D_full.csv')) %>% 
  mutate(y = dlgrp_pc_usd_2015, source = "KLW 24", id_1 = as.character(GID_1)) %>% 
  select(year, iso = GID_0, id_1, y, source, GID_1, region) %>% 
  na.omit() %>% 
  mutate(region_l = paste0(region, source))

df.bhm <- haven::read_dta(paste0(db, 
                                 "/BurkeHsiangMiguel2015_Replication/", 
                                 "data/input/GrowthClimateDataset.dta")) %>% 
  mutate(y = growthWDI) %>% 
  mutate(source = "BHM") %>% 
  select(iso, year, y, source)

df.wb <- read_csv(
  file.path(db, 
            "API_NY.GDP.PCAP.KD.ZG_DS2_en_csv_v2_3401540/", 
            "API_NY.GDP.PCAP.KD.ZG_DS2_en_csv_v2_3401540.csv"
  ), skip = 3
) %>% 
  filter(`Country Code` %in% c("UZB", "USA")) %>% 
  pivot_longer(cols = `1960`:`2023`, names_to = 'year', values_to = 'y') %>%
  filter(!is.na(y)) %>% 
  select(iso = `Country Code`, year, y) %>% 
  mutate(year = as.numeric(year), y = y / 100) %>% 
  mutate(source = "World Bank")

df.DOSEv1 <- read_csv(file.path(db, "DOSE_v1.csv")) %>% 
  group_by(iso, region) %>% 
  mutate(y=log(gdp_pc_usd)-log(dplyr::lag(gdp_pc_usd))) %>% 
  ungroup() %>% 
  select(year, iso, y, region_l=region) %>%
  mutate(source = "DOSE v1") 
  
isoTplot <- "UZB"
bind_rows(
    df.wb %>% filter(iso == isoTplot),
    df.bhm %>% filter(iso == isoTplot), 
    df.DOSEv1 %>% filter(iso == isoTplot), 
    df.klw %>% filter(iso == isoTplot)
  ) %>% 
  mutate(`Data source` = 
           fct_relevel(source, c("BHM", "World Bank", "DOSE v1", "KLW 24"))) %>% 
  ggplot() + 
  geom_line(aes(x = year, y = y, color = `Data source`, group = region_l, 
                alpha = `Data source`)) + 
  scale_alpha_manual(values = c(1, 1, .5, .5)) +
  scale_color_manual(values = c("red", "blue", "grey", "green")) + 
  ggtitle("UZB GDP-PC Growth") + 
  ylab("")+ theme(legend.position = 'left') +xlab("Year")

# setup environment -------------------------------------------------------
source('01_setup.R')

# load all four datasets --------------------------------------------------

isoTplot <- "UZB"

df.klw <- read_csv(file.path(db, 
               "/datacode", 
               'DOSE_climate_data/DOSEV2_W5E5D_full.csv')) %>% 
  arrange(GID_1, year) |>
  group_by(GID_1) |>
  mutate(
  y = (grp_pc_usd_2015 - lag(grp_pc_usd_2015))/lag(grp_pc_usd_2015),
  source = "Kotz et al. (2024) / DOSE v.2", 
  id_1 = as.character(GID_1)
  ) |>
  ungroup() |>
  select(year, iso = GID_0, id_1, y, grp_pc_usd_2015, pop, source, GID_1, region) |> 
  drop_na(y) |>
  replace_na(list(pop = 1)) |>
  mutate(region_l = paste0(region, source))

df.klw_country = df.klw |>
  group_by(iso, year) |>
  summarise(y = weighted.mean(y, w=pop), .groups='drop') |>
  mutate(source = "Kotz et al. (2024)") 

df.bhm <- haven::read_dta(paste0(db, 
                 "/BurkeHsiangMiguel2015_Replication/", 
                 "data/input/GrowthClimateDataset.dta")) %>% 
  mutate(y = growthWDI) %>% 
  mutate(source = "Burke et al. (2015)") %>% 
  select(iso, year, y, source)

df.wb <- read_csv(
  file.path(db, 
      "API_NY.GDP.PCAP.KD.ZG_DS2_en_csv_v2_3401540/", 
      "API_NY.GDP.PCAP.KD.ZG_DS2_en_csv_v2_3401540.csv"
  ), skip = 3
) %>% 
  filter(`Country Code` %in% c(isoTplot, "USA")) %>% 
  pivot_longer(cols = `1960`:`2023`, names_to = 'year', values_to = 'y') %>%
  filter(!is.na(y)) %>% 
  select(iso = `Country Code`, year, y) %>% 
  mutate(year = as.numeric(year), y = y / 100) %>% 
  mutate(source = "World Bank") %>% 
  mutate(region_l = paste0("wb")) |>
  filter(year >= 2013 & year <=2020) |>
  filter(iso == isoTplot)

df.DOSEv1 <- read_csv(file.path(db, "DOSE_v1.csv")) |> 
  arrange(ID, year) |>
  group_by(ID) |>
  mutate(y = (gdp_pc_usd - lag(gdp_pc_usd))/lag(gdp_pc_usd)) |>
  filter(!is.na(y)) |>
  dplyr::select(id = ID, iso, region, country, year, y, id_1) |>
  # Construct key for merging to GADM
  mutate(gid_1 = paste0(iso, ".", id_1, "_1")) |> 
  mutate(source = "KW")
  
plot_df = bind_rows(
    df.bhm |> filter(iso == isoTplot), 
    df.klw_country |> filter(iso == isoTplot)
  ) |> 
  mutate(`Data source` = fct_relevel(source, c("Burke et al. (2015)", "Kotz et al. (2024)"))) 


colors = c("#353935", "#CE2D4F")
data_plot = ggplot() + 
  geom_line(
    data=plot_df,
    aes(
      x = year, 
      y = y*100, 
      color = `Data source`
      # group = region_l
    ),
    linewidth=1.3,
    alpha=1
  ) + 
  geom_line(
    data=df.klw |> filter(iso == isoTplot),
    aes(
      x = year, 
      y = y*100,
      group=region_l
    ),
    color = "#CE2D4F",
    linewidth=1,
    alpha=0.2
  ) + 
  geom_line(
    data=df.DOSEv1 |> filter(iso == isoTplot),
    aes(
      x = year, 
      y = y*100,
      group=gid_1
    ),
    color = "#61988E",
    linewidth=1,
    alpha=0.2
  ) + 
  geom_line(
    data=df.wb,
    aes(
      x = year, 
      y = y*100, 
      # group = region_l
    ),
    color="#353935",
    linetype='dashed',
    linewidth=1.3,
    alpha=1
  ) +  
  # Kotz province arrow
  geom_text_repel(
    data = df.klw |> 
      filter(iso==isoTplot, year==2010) |>
      filter(GID_1 == "UZB.12_1") |>
      mutate(vlabel = "DOSE v.2\n(Kotz et al.)"),
    aes(x = year, y = y*100, label=vlabel),
    nudge_y     = 15,
    nudge_x     = 5,
    size      = 6,
    box.padding   = 1,
    point.padding = 0.5,
    force     = 100,
    segment.size  = 0.7,
    arrow     = arrow(length = unit(0.015, "npc")),
    segment.color = "grey50",
    direction   = "x"
  ) +
  # Kotz mean arrow
  geom_text_repel(
    data = df.klw_country |> 
      filter(iso==isoTplot, year==2007) |>
      mutate(vlabel = "DOSE v.2 average"),
    aes(x = year, y = y*100, label=vlabel),
    nudge_y     = -40,
    nudge_x     = 2,
    size      = 6,
    box.padding   = 1,
    point.padding = 0.5,
    force     = 100,
    segment.size  = 0.7,
    arrow     = arrow(length = unit(0.015, "npc")),
    segment.color = "grey50",
    direction   = "x"
  ) +
  # KW arrow
  geom_text_repel(
    data = df.DOSEv1 |> 
      filter(iso==isoTplot, year==2001) |>
      filter(gid_1 == "UZB.6_1") |>
      mutate(vlabel = "DOSE v.1"),
    aes(x = year, y = y*100, label=vlabel),
    nudge_y     = 25,
    nudge_x     = 1,
    size      = 6,
    box.padding   = 1,
    point.padding = 0.5,
    force     = 100,
    segment.size  = 0.7,
    arrow     = arrow(length = unit(0.015, "npc")),
    segment.color = "grey50",
    direction   = "x"
  ) +
  # BHM arrow
  geom_text_repel(
    data = df.bhm |> 
      filter(iso==isoTplot, year==1992) |>
      mutate(vlabel = "Burke et al."),
    aes(x = year, y = y*100, label=vlabel),
    nudge_y     = -20,
    nudge_x     = -1,
    size      = 6,
    box.padding   = 1,
    point.padding = 0.5,
    force     = 100,
    segment.size  = 0.7,
    arrow     = arrow(length = unit(0.015, "npc")),
    segment.color = "grey50",
    direction   = "x"
  ) +
  # WB arrow
  geom_text_repel(
    data = df.wb |> 
      filter( year==2017) |>
      mutate(vlabel = "World Bank data \n after Burke et al."),
    aes(x = year, y = y*100, label=vlabel),
    nudge_y     = -45,
    nudge_x     = -8,
    size      = 6,
    box.padding   = 1,
    point.padding = 0.5,
    force     = 100,
    segment.size  = 1,
    arrow     = arrow(length = unit(0.015, "npc")),
    segment.color = "grey50",
    direction   = "x"
  ) +
  # dotted line at zero, grey
  geom_hline(yintercept = 0, linetype="dashed", color = "grey") +
  # scale_alpha_manual(values = c(1, 1, .5, .5)) +
  scale_color_manual(name='', guide='none', values = colors) + 
  # ggtitle("UZB GDP-PC Growth") + 
  ylab("Change in GDP per capita (Percent)")+ 
  xlab("Year") +
  theme_classic() +
  theme(
    # legend.position='none',
    # legend.position.inside = c(0.7, 0.2),
    # make font larger
    text = element_text(size=20)
  )
# data
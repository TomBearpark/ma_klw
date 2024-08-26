source('01_setup.R')

# Panel A: Data
source(glue("{code}/code/figA.R"))

# Panel B: Marginal effects
source(glue("{code}/code/figB.R"))

# Panel C: Projection figure
# Load projection data
proj_df = read_feather(glue('{db}/datacode/projection_output/projection_output.feather'))

# Clean model names
proj_df = proj_df %>%
  mutate(model = case_when(
    model == 'proj' ~ 'Kotz et al.',
    model == 'proj_dropuzb' ~ 'Kotz et al. without UZB',
    model == 'proj_dropuzb_bootstrapfix' ~ 'Kotz et al. without UZB (bootstrap fix)',
  )) 

# Print uncertainty change from block bootstrap
print(proj_df |> filter(year==2100))

# Subset to models for plot
proj_df = proj_df |> 
    filter(model == 'Kotz et al.' | model == 'Kotz et al. without UZB')

# Point for Burke et al. 2100 impact
bhm_point = data.frame(year = 2100, median=-23, vlabel="2100 impact in \n Burke et al.")

# Generate plot
colors = c("#CE2D4F", "#003576", 'grey', 'orange')
proj_plot = ggplot(data=proj_df) +
    geom_line(aes(x=year, y=median, color=model), size=1) +
    geom_ribbon(
        aes(x=year, ymin=lb, ymax=ub, fill=model),
        alpha=0.2
    ) +
    geom_point(data=bhm_point, aes(x=year, y=median), size=6, fill="#353935", color="#353935") +
    geom_point(data=bhm_point, aes(x=year, y=median), size=1.5, shape=4, stroke=1.5, color='white') +
    geom_text_repel(
        data = bhm_point,
        aes(x = year, y = median, label=vlabel),
        nudge_y       = 30,
        nudge_x       = -9,
        size          = 6,
        box.padding   = 1,
        point.padding = 0.5,
        force         = 100,
        segment.size  = 1,
        arrow         = arrow(length = unit(0.015, "npc")),
        segment.color = "grey50",
        direction     = "x"
    ) +
    geom_text_repel(
        data = proj_df |> filter(year==2050, model == 'Kotz et al.'),
        aes(x = year, y = median),
        label = 'Kotz et al.',
        nudge_y       = -15,
        nudge_x       = -15,
        size          = 6,
        box.padding   = 1,
        point.padding = 0.5,
        force         = 100,
        segment.size  = 1,
        arrow         = arrow(length = unit(0.015, "npc")),
        segment.color = "grey50",
        direction     = "x"
    ) +
    geom_text_repel(
        data = proj_df |> filter(year==2050, model == 'Kotz et al. without UZB'),
        aes(x = year, y = median),
        label = 'UZB removed from data',
        nudge_y       = 20,
        nudge_x       = -12,
        size          = 6,
        box.padding   = 1,
        point.padding = 0.5,
        force         = 100,
        segment.size  = 1,
        arrow         = arrow(length = unit(0.015, "npc")),
        segment.color = "grey50",
        direction     = "x"
    ) +
    theme_classic()  +
    geom_hline(yintercept = 0, linetype="dashed", color = "grey") +
    xlab("Year") + 
    ylab("Change in GDP per capita (Percent)") + 
    scale_color_manual(name='', values = colors) + 
    scale_fill_manual(name='', values = colors) +
    theme(
        legend.position='bottom',
        legend.title=element_blank(),
        text = element_text(size=20)
    ) +
    guides(
        fill = guide_legend(override.aes = list(size=8))
    )

# Combine plots
plot = data_plot + me_plot + proj_plot + 
    patchwork::plot_layout() +
    patchwork::plot_annotation(
        tag_levels = "a"
    ) &
    theme(
        legend.position='inside',
        legend.position.inside=c(-0.8, 0.175),
        legend.text=element_text(size=18),
    )

# Save plot
ggsave(
    filename = paste0(dir.out, "/comment_main_figure.pdf"),
    plot = plot,
    width = 24,
    height = 8
)
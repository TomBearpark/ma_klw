# Funcs -------------------------------------------------------------------

cumulative_me <- function(m, 
                          xvals=seq(0, 30, 5), 
                          NL=10 
){
  nm <- names(coef(m))
  
  map_dfr(
    xvals, 
    function(baseline){
      
      ff <- ""
      for(tt in 1:(NL+1)){
        if(baseline==min(xvals)){
          print(paste0(nm[tt], " ", nm[tt+(NL+1)]))
        }
        ff <- paste0(ff, "+ b", tt,"+b", tt+(NL+1), "*", baseline)
      }
      ff
      marginaleffects::hypotheses(m, paste0(ff, '=0')) %>% 
        broom::tidy() %>% 
        dplyr::mutate(baseline = baseline) %>% 
        dplyr::select(baseline, estimate, upper = conf.high, lower = conf.low) %>% 
        dplyr::mutate(NL=NL)
    }
  )
}

run_cumulative_mes <- function(mList, mNames, NL_list, 
                               xvals = seq(0, 30, 5)){
  map_dfr(
    seq_along(mList), function(ii){
      cumulative_me(mList[[ii]], xvals = xvals, NL = NL_list[[ii]])  %>% 
        mutate(Model = mNames[[ii]])
    }
  )
}

# setup environment -------------------------------------------------------
source('01_setup.R')

# load data ---------------------------------------------------------------

pdat <- load_kotz_panel(db) %>% 
  dplyr::select(
    year, GID_0, GID_1, 
    dlgrp_pc_usd_2015,
    contains(c('Tmean', 'Tstd')),
    contains(c('Pt', 'wet_days_1', 'vwet_days_am_99p9')), 
    "pop", 'const', 'region', 'StructChange')

isos <- pdat %>% 
  filter(!is.na(dlgrp_pc_usd_2015)) %>% 
  pull(GID_0) %>% 
  unique() %>% sort()

# run loo  ----------------------------------------------------------------

run_loo <- 
  function(cc, pdat, FE = "GID_1 + year + GID_1[year]"){
    
    message(cc)
    
    df <- pdat %>% filter(GID_0 != cc)
    
    mod8  <- estimate_model("const", pdat=df, TNL = 8, 
                            FE = FE)
    mod9  <- estimate_model("const", pdat=df, TNL = 9, 
                            FE = FE)
    mod10 <- estimate_model("const", pdat=df, TNL = 10, 
                            FE = FE)
    
    me  <- run_cumulative_mes(mList=list(mod8, mod9, mod10), 
                              mNames=list("TNL8", "TNL9", "TNL10"), 
                              NL_list=c(8, 9, 10), 
                              xvals = c(0, 25, 30))
    
    me %>% 
      mutate(dropped = !!cc)
  }


loo <- purrr::map_dfr(c("none", isos), run_loo, pdat)


# output csv --------------------------------------------------------------
write_csv(loo, paste0(dir.out, "loo_country.csv"))

# plot --------------------------------------------------------------------
me_plot_df = read_csv(paste0(dir.out, "loo_country.csv"))

options(repr.plot.width=10, repr.plot.height=10)
av.plotdf <- me_plot_df |>
    group_by(baseline, Dropped=dropped) |> 
    summarize(estimate = mean(estimate)*100) |>
    mutate(Dropped = ifelse(Dropped == "none", "Kotz et al. (2024)", Dropped))

av_point = av.plotdf |> filter(baseline==25, Dropped=='UZB')
av_point = av_point |> mutate(vlabel = 'UZB removed from data')

other_av_point = av.plotdf |> filter(baseline==25, Dropped=='USA')

kotz_point = av.plotdf |> filter(baseline==25, Dropped=='Kotz et al. (2024)')

colors = c("#CE2D4F", "#003576")

me_plot = ggplot(data = av.plotdf) + 
    # UZB removed
    geom_text_repel(
        data = av_point,
        aes(x = baseline, y = estimate, label=vlabel),
        nudge_y       = 10,
        nudge_x       = -2,
        size          = 6,
        box.padding   = 1,
        point.padding = 0.5,
        force         = 100,
        segment.size  = 1,
        arrow         = arrow(length = unit(0.015, "npc")),
        segment.color = "grey50",
        direction     = "x"
    ) +
    # Other countries
    geom_text_repel(
        data = other_av_point,
        aes(x = baseline, y = estimate),
        label="Other countries removed",
        nudge_y       = 10,
        nudge_x       = -2,
        size          = 6,
        box.padding   = 1,
        point.padding = 0.5,
        force         = 100,
        segment.size  = 1,
        arrow         = arrow(length = unit(0.015, "npc")),
        segment.color = "grey50",
        direction     = "x"
    ) +
    # Kotz ME
    geom_text_repel(
        data = kotz_point,
        aes(x = baseline, y = estimate),
        label="Kotz et al.",
        nudge_y       = -2,
        nudge_x       = -8,
        size          = 6,
        box.padding   = 1,
        point.padding = 0.5,
        force         = 100,
        segment.size  = 1,
        arrow         = arrow(length = unit(0.015, "npc")),
        segment.color = "grey50",
        direction     = "x"
    ) +
    geom_line(
        data = filter(av.plotdf, !(Dropped %in% c("Kotz et al. (2024)", 'UZB'))),
        aes(x = baseline, y = estimate, group = Dropped),
        linewidth=0.7,
        alpha = .1
    ) +
    geom_line(
        data = filter(av.plotdf, Dropped %in% c("Kotz et al. (2024)")), 
        aes(x = baseline, y = estimate), 
        color="#CE2D4F",
        linewidth=1.5,
        alpha=1
    ) + 
    geom_line(
        data = filter(av.plotdf, Dropped %in% c('UZB')), 
        aes(x = baseline, y = estimate), 
        color="#003576",
        # linetype='dashed',
        linewidth=1.5,
        alpha=1
    ) + 
    # scale_linetype_manual(values = c("solid", "dashed")) +
    # scale_color_manual(values = colors) + 
    geom_hline(yintercept = 0, linetype="dashed", color = "grey") +
    xlab("Baseline temperature (°C)") + 
    ylab("Cumulative Marginal Effect (Percent)") + 
    # scale_color_manual(values = c("#CE2D4F", "")) + 
    theme_classic()  +
    theme(
        legend.position='none',
        legend.position.inside = c(0.7, 0.2),
        # make font larger
        text = element_text(size=20)
    )



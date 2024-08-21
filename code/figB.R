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


# sense check plot --------------------------------------------------------

loo %>% 
  group_by(baseline, Dropped=dropped) %>% 
  summarize(estimate = mean(estimate)) %>% 
  ungroup() %>% 

  ggplot(data = .) + 
    geom_line(
      aes(x = baseline, y = estimate, group = Dropped),
      alpha = .2) +
    geom_line(data = . %>% filter(Dropped %in% c("none", "UZB")), 
              aes(x = baseline, y = estimate,  color=Dropped), 
              linewidth = 1) + 
    geom_hline(yintercept = 0, alpha= .5) +
    xlab("Baseline temp (C)") + ylab("Cumulative ME") + 
    scale_color_manual(values = c("green", "red")) + 
    theme(legend.position = "left") + 
    ggtitle("Leave one country out")


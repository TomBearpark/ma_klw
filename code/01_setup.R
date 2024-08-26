if(!require(pacman)) install.packages('pacman')
pacman::p_load(tidyverse, fixest, marginaleffects, broom, arrow, haven, patchwork, glue, ggrepel)
ggplot2::theme_set(ggplot2::theme_bw())

# db      <- file.path("~/Library/CloudStorage/Dropbox/gdp-temp/ma_rep/")
db = file.path("/home/dhogan/Dropbox/gdp-temp/ma_rep")
code    <- file.path("/home/dhogan/repositories/ma_klw")
dir.out <- file.path(code, "/outputs/")

# helper funcs --------------------------------------------------------------

## loading data -----------------------------------------------------------

load_kotz_panel <- function(db){
  
  # Adapted from KLW replication code
  
  table <- read_csv(file.path(db, 
                              "datacode", 
                              'DOSE_climate_data/DOSEV2_W5E5D_full.csv'))
  
  varns=c('Tmean_d','Tstd_d','Pt_d','wet_days_1_d','vwet_days_am_99p9_d','Wn_d')
  modns=c('Tmean_m','Tseasdiff_m','Pt_m','wet_days_1_m','Tmean_m','Wn_m')
  
  for (i in 1:length(varns)){
    table[
      paste(modns[i],'_i_',varns[i],sep='')
      ] <- table[modns[i]] * table[varns[i]]
  }
  
  table['year2'] <- table['year']**2
  table['const'] <- 1
  
  return(table)
}

## analysis -----------------------------------------------------------

# Wrapper function for running regression model based on KLW replication code
estimate_model <- 
  function(
    weights, 
    pdat, 
    FE = "GID_1 + year + GID_1[year]",
    cluster = "GID_1",
    TNL=10,
    PNL=4,
    tvars = c('Tmean_d', "Tmean_m_i_Tmean_d", 
              "Tstd_d", "Tseasdiff_m_i_Tstd_d"), 
    pvars = c("Pt_d", "Pt_m_i_Pt_d",
              "wet_days_1_d", "wet_days_1_m_i_wet_days_1_d",
              "vwet_days_am_99p9_d","Tmean_m_i_vwet_days_am_99p9_d"), 
    panel.id = c("GID_1", "year"), 
    lean=TRUE)
{
  
  print(paste0(TNL,"lags for temp vars, ", PNL, " lags for precip, "))
  
  ff <- ""
  for(tt in tvars){
    xx <- paste0('l(', tt,",",0:TNL,')', collapse = "+")
    ff <- paste0(ff, "+", xx)
  }
  
  for(tt in pvars){
    xx <- paste0('l(', tt,",",0:TNL,')', collapse = "+")
    ff <- paste0(ff, "+", xx)
  }
  
  ff <- paste0("dlgrp_pc_usd_2015 ~ ", ff, "|", FE)
  
  fixest::feols(as.formula(ff),
                cluster = c(cluster), 
                weights = pdat[[weights]], 
                pdat,
                panel.id=panel.id, 
                lean=lean)
  }


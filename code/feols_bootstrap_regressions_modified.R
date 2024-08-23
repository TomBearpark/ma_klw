# install.packages('fixest',repos="https://ftp.gwdg.de/pub/misc/cran/")
library(dplyr)
library(fixest)

# Set WD
source('01_setup.R')

#function to help stargazer package format in scientific format nicely, adapted from: https://stackoverflow.com/a/56924401
replace_numbers = function(x, low=0.01, high=1e3, digits = 3, scipen=-7, ...) {
  x = gsub(mark,'.',x)
  x.num = as.numeric(x)
  if (x.num<0.01){
    ifelse(
      (x.num >= low) & (x.num < high), 
      round(x.num, digits = 2), 
      prettyNum(x.num, digits=2, scientific = scipen, ...)
    )
  }
  else {
    ifelse(
      (x.num >= low) & (x.num < high), 
      round(x.num, digits = digits), 
      prettyNum(x.num, digits=digits, scientific = scipen, ...)
    )
  }
}  

#take arguments for seed and number of runs
args = commandArgs(trailingOnly=TRUE)
seed = as.integer(args[1]) # we ran with integer values from 1-20
N    = as.integer(args[2]) # we ran with N=50 runs per script
regspec = 'lagdiff_lintren_fix'
drop_uzb = args[3]
bootstrap_fix = args[4]

#set random seed
set.seed(seed)

table=read.csv('DOSE_climate_data/DOSEV2_W5E5D_full.csv')

if (drop_uzb=='TRUE') {
  table = table |> filter(GID_0!='UZB')
}

#laglevel nonlinearities
table$Tmean_2 <- table$Tmean^2
table$Wn_2 <- table$Wn^2
table$wet_days_1_2 <- table$wet_days_1^2
table$Pt_2 <- table$Pt^2
table$Tseasdiff_m_i_Tstd <- table$Tstd * table$Tseasdiff_m
table$Tmean_m_i_vwet_days_am_99p9 <- table$vwet_days_am_99p9 * table$Tmean_m

#interaction terms
varns=c('Tmean_d','Tstd_d','Pt_d','wet_days_1_d','vwet_days_am_99p9_d','Wn_d')
modns=c('Tmean_m','Tseasdiff_m','Pt_m','wet_days_1_m','Tmean_m','Wn_m')

for (i in 1:length(varns)){
  table[paste(modns[i],'_i_',varns[i],sep='')] <- table[modns[i]] * table[varns[i]]
}

#base model
pdat=panel(table,~GID_1+year,duplicate.method = "first")

#bootstrapping to get estimates of regression uncertainty
if (bootstrap_fix=='TRUE') {
  IDs=unique(table$GID_0)
} else if (bootstrap_fix=='FALSE') {
  IDs=unique(table$GID_1)
}


for (n in 1:N){
  start_time <- Sys.time()

  if (bootstrap_fix=='TRUE') {
    sampleIDs <- sample(IDs,size=length(IDs),replace=T)
    new_df = data.frame(GID_0 = sampleIDs) |> 
      arrange(GID_0) |> 
      group_by(GID_0) |> 
      mutate(rep=row_number()) |>
      left_join(table, by='GID_0', relationship='many-to-many') |>
      mutate(GID_1 = paste0(GID_1, "_", rep))
    pdat=panel(new_df,~GID_1+year)
  } else if (bootstrap_fix=='FALSE') {
    sampleIDs <- sample(IDs,size=length(IDs),replace=T)
    new_df <- do.call(rbind, lapply(sampleIDs, function(x) table[table$GID_1==x,] ))
    pdat=panel(new_df,~GID_1+year,duplicate.method = "first")
  }
  
  #with linear trends
  for (TNL in 8:10){
   if (regspec=='lagdiff_lintren_fix') {
    mod = feols(dlgrp_pc_usd_2015 ~ l(Tmean_d,0:TNL) + l(Tmean_m_i_Tmean_d,0:TNL) + l(Tstd_d,0:TNL) + l(Tseasdiff_m_i_Tstd_d,0:TNL) + l(Pt_d,0:4) + l(Pt_m_i_Pt_d,0:4) + l(wet_days_1_d,0:4) + l(wet_days_1_m_i_wet_days_1_d,0:4) + l(vwet_days_am_99p9_d,0:4) + l(Tmean_m_i_vwet_days_am_99p9_d,0:4)| GID_1 + year + GID_1[year],pdat,panel.id=~GID_1+year)
  } else if (regspec=='altdefl_lagdiff_lintren_fix') {
    mod = feols(dlgrp_pc_lcu2015_usd  ~ l(Tmean_d,0:TNL) + l(Tmean_m_i_Tmean_d,0:TNL) + l(Tstd_d,0:TNL) + l(Tseasdiff_m_i_Tstd_d,0:TNL) + l(Pt_d,0:4) + l(Pt_m_i_Pt_d,0:4) + l(wet_days_1_d,0:4) + l(wet_days_1_m_i_wet_days_1_d,0:4) + l(vwet_days_am_99p9_d,0:4) + l(Tmean_m_i_vwet_days_am_99p9_d,0:4)| GID_1 + year + GID_1[year],pdat,panel.id=~GID_1+year)
  } else {
        print('Incorrect regspec specified')
        break
  } 
 
  coefs=mod$coefficients
  if (n==1){
    if (TNL==8){
      list_of_data = list(coefs)
    }
    else{
      list_of_data = append(list_of_data, list(coefs))
    }
  }
  else{
    list_of_data[[TNL-7]]=rbind(list_of_data[[TNL-7]],coefs)
  }
  }
  
  end_time <- Sys.time()
  if (n%%20==0){
    print(paste('finished ',as.character(n)))
  }
}

for (TNL in 8:10){
  filetag = ''
  if (drop_uzb=='TRUE') {
    filetag = paste0(filetag, '_dropuzb')
  }
  if (bootstrap_fix=='TRUE') {
    filetag = paste0(filetag, '_bootstrapfix')
  }
  write.csv(list_of_data[[TNL-7]],paste('reg_results/',regspec,'_spec_NL_',as.character(TNL),'_bootN_',as.character(N),'_seed_',as.character(seed),filetag,'_coefs.csv',sep=''))
}


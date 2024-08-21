import pandas as pd
import numpy as np
import glob
import sys 
from scipy import signal
from proj_functions import *

#Estimating time series of aggregate damages, and time-slices of regional damages, from bootstrapped estimates of uncertainty across:
#Regression parameters
#Climate models 

#calculate the impact on growth rates, comparing a climate change and baseline climate, and given lagged response curve 
def impact_lag_calc(clim,mod,clim_base,mod_base,param):

	NL=param.shape[-1]
	#marginal effects in future period
	marg=param[0]+np.multiply.outer(mod,param[1])
	marg=np.rollaxis(marg,2,0)
	#marginnal effects assuming continued baselineclimate
	marg_base=param[0]+np.multiply.outer(mod_base,param[1])
	marg_base=np.rollaxis(marg_base,2,0)

	#impact due to future climate change
	impactCC=np.zeros(clim.shape)
	#by-hand convolution of the climate evolution with the time-varying lagged response
	for t in range(clim.shape[0]):
		if t>=NL-1:
			marg_diag=np.diagonal(np.flip(marg[:,t-NL+1:t+1,:],axis=0))
			impactCC[t,:]=np.sum(np.multiply(marg_diag.transpose(),clim[t-NL+1:t+1,:]),axis=0)		

	#impact assuming continued baselineclimate
	impactB=np.zeros(clim.shape)
	for t in range(clim.shape[0]):
		if t>=NL-1:
			marg_diag=np.diagonal(np.flip(marg_base[:,t-NL+1:t+1,:],axis=0))
			impactB[t,:]=np.sum(np.multiply(marg_diag.transpose(),clim_base[t-NL+1:t+1,:]),axis=0)

	return(impactCC,impactB)

#reduce GDP outputs based on baseline GDP trajectory and growth impacts (possibly multi-dimensional growth impacts)
def reduce_output(gdp_traj,growth_impact):
	#economic growth trajectory
	dgdp_traj=np.diff(gdp_traj,axis=0)
	#reduce growth rate (using climate data starting from the second year)
	dgdp_traj2=dgdp_traj+growth_impact[...,:-1,:]
	#calculate damaged gdp trajectory (first years GDP plus the cumulative sum of the difference in logarthm)
	base=np.zeros([s for i,s in enumerate(growth_impact.shape) if i!=len(growth_impact.shape)-2])
	base=base[...,np.newaxis,:]
	gdp_traj2=gdp_traj[0,:]+np.concatenate((base,np.nancumsum(dgdp_traj2,axis=-2)),axis=-2)
	return(gdp_traj2)

#assess agreement in sign of data in array along a given axis, for a given level of agreement
def agree(data,axis,level):
	grthan=np.zeros(data.shape)
	grthan[data>0]=1
	agreement=np.sum(grthan,axis=axis)
	return((agreement<level) | (agreement>data.shape[axis]-level))

#get climate data, and the years
def get_clim(var,model,ssp,start):
	folder=var.split('_')[0]+'_proj'
	clim=pd.read_csv('CMIP6_data/' + folder + '/' + var + '_' + model + '_' + ssp + '_1950-2100.csv')
	clim=np.array(clim)[:,2:]
	clim_years=np.linspace(1951,1950+clim.shape[0],clim.shape[0])
	return(clim,clim_years)

#aggregate some data along the last axis, at given locations, according to given weightings (weighted average)
def aggreg(data,locs,weights):
	aggreg=np.zeros((data.shape[:-1]))
	locs=np.array(locs)
	locs=locs[~np.isnan(weights[-1,locs])]
	locs=locs[~np.isnan(data[-1,-1,locs])]
	for i in range(weights.shape[0]):
		aggreg[...,i]=np.tensordot(data[...,i,locs],weights[i,locs],axes=([-1],[-1]))/np.sum(weights[i,locs])
                
	return(aggreg)

#cap some data at given levels
def cap_it(data,cap):
	data[data<cap[0]]=cap[0]
	data[data>cap[1]]=cap[1]
	return(data)

#moving average 
def mov_av(data, N):
	cumsum = np.cumsum(np.insert(data, 0, np.zeros_like(data[0,:]), 0),axis=0)
	output = (cumsum[N:] - cumsum[:-N]) / float(N)
	return(output)

#input variables (socio scenario, climate scenario, regression specification, number of lags, number of bootstrap estimates to runn within this script, random seed, window of moving average for moderating variables 
soc_ssp=sys.argv[1] # ssp2
clim_ssp=sys.argv[2] # ssp126 / ssp585
regspec=sys.argv[3] # lagdiff_lintren_fix_spec
NLs=sys.argv[4] # 8_9_10
Nboot=int(sys.argv[5]) # 50
seed=(int(sys.argv[6])) # 1-20
winN=int(sys.argv[7]) # 30

#climate variables of interest, and their moderating variables 
variables=['T_mean','T_std','P_sum','P_wdys_num','P_mext_am']
moderators=['T_mean','T_seasdiff','P_sum','P_wdys_num','T_mean']

if 'testvar' in regspec:
        varsel=int(regspec.split('testvar')[1][0])
        variables=[variables[0],variables[varsel]]
        moderators=[moderators[0],moderators[varsel]]
if 'Tonly' in regspec:
	variables=[variables[0]]
	moderators=[moderators[0]]

#set random seed
np.random.seed(seed)

NLs=[int(n) for n in NLs.split('_')]
#load overall bootstrapped estimates of regression coefficients
seeds=[x+1 for x in range(20)]
coefs_l=[]
for n, NL in enumerate(NLs):
	for s, sd in enumerate(seeds):
		cfs=pd.read_csv('reg_results/' + regspec + '_NL_' + str(NL) + '_bootN_50_seed_' + str(sd) + '_coefs.csv')
		if s==0:
			coefs=cfs	
		else:
			coefs=coefs.append(cfs)
	del coefs['Unnamed: 0']
	coefs_l.append(coefs)

#world region lists
wrld_rgns=['North America','Europe','Central Asia/Russia','Middle East/North Africa','South Asia','Southeast/East Asia','South America','Sub-saharan Africa','Oceania']
regions=pd.read_csv('world_region_lists_2.csv')
rgn_list=[]
for l in wrld_rgns:
	rgn_list.append(list(regions[l].loc[~regions[l].isnull()]))

#region shapefiles
mask=pd.read_csv('masks/gadm36_levels_gpkg/gadm36_levels_labels.csv')
iso_list=np.array(mask.GID_0)
isos=mask.GID_0.unique()

#GDP data
GDP_PC=np.load('SSP_proj/GDP_PC_' + soc_ssp + '.npy')
gdp_years=GDP_PC[0,:].astype(int)
GDP_PC=GDP_PC[1:,:]
lgdp_pc=np.log(GDP_PC)

#population data
POP=np.load('SSP_proj/REG_POP_' + soc_ssp + '.npy')
pop_years=POP[0,:].astype(int)
pop=POP[1:,:]

#climate data 
#primary+secondary models from ISIMIP
models1=['GFDL-ESM4','IPSL-CM6A-LR','MPI-ESM1-2-HR','MRI-ESM2-0','UKESM1-0-LL','CanESM5','CNRM-CM6-1','CNRM-ESM2-1','EC-Earth3','MIROC6']
#additional models from Stefan Lange
models2=['ACCESS-ESM1-5','AWI-CM-1-1-MR','BCC-CSM2-MR','CAMS-CSM1-0','CESM2','FGOALS-g3','IITM-ESM','INM-CM5-0','KACE-1-0-G','NESM3','TaiESM1']
models=models1+models2

#how to evolve the marginal effects of the moderators? flexibly/fixed/or slowly moving fixed? Choice of the latter based on Kalkuhl Wenz 2020/Burke 2015 
margs=['movfix']*5

#implement caps on climate variables, requiring a certain amount of historical observations at that level (minp, expressed in percentage points)
#to prevent extrapolation of marginal effects outside of what we observed historically
cap_vars=np.array(['T_mean','T_std','T_seasdiff','P_ext_am','P_ext99_am','P_wdys_num','P_WASP','P_sum'])
minp=2
caps=np.load('caps/caps_' + str(minp) + '.npy')
caps=np.insert(caps,8,caps[:,-2],axis=1)
cap_vars=np.array(['T_mean','T_std','T_seasdiff','P_ext_am','P_ext99_am','P_wdys_num','P_WASP','P_sum','P_WASP2'])

#year from which to start damaging the economy
start_year=2020
end_year=2099
#GDP trajectory
gdp_traj=lgdp_pc[:,np.logical_and(gdp_years>=start_year,gdp_years<=end_year)].T
POP_traj=pop[:,np.logical_and(pop_years>=start_year,pop_years<=end_year)].T

#calculate and save bootstrapped estimates of damaged time series at different levels of aggregation (world regions, subnational, national...)
dam_curves_l=[]
reg_imps=[]
dam_curves_nat_l=[]
gdp_traj_dams_l=[]
models_l=[]

#bootstrap estimates
for nb in range(Nboot):

	#get random sample of the regression
	coefs_s=coefs_l[np.random.randint(3)].iloc[np.random.randint(len(coefs_l[0]))]
	coef_s=pd.DataFrame()
	coef_s['Unnamed: 0']=list(coefs_s.index)
	coef_s['x']=list(coefs_s)
	[varns,mods,modns,NVLs]=extract_vars_mods(coef_s)
	coef_mat=extract_specNL_coef_matrix(coef_s,varns,mods,NVLs)

	#random sample of climate model
	m=np.random.randint(len(models))
	model=models[m]
	models_l.append(model)

	growth_impacts=[]
	#load climate data for each variable
	for v in range(len(variables)):
		var=variables[v]
		mod_n=moderators[v]
		marg=margs[v]
		growth_impacts.append([])

		#response function for that variable
		param=np.array(coef_mat[v]).transpose()

		#load climate data of primary variable
		[clim, clim_years]=get_clim(var,model,clim_ssp,start_year)
		#differenced climate data
		climd=np.diff(clim,n=1,axis=0)
		clim_yearsd=clim_years[1:]

		#detrend historical climate period to use as estimate of internal variability
		climdetr=np.copy(clim[1978-1951:start_year-1-1951,:])
		climdetr[:,np.logical_not(pd.isna(climdetr[0,:]))]=signal.detrend(climdetr[:,np.logical_not(pd.isna(climdetr[0,:]))],axis=0)
		climdetr_d=np.diff(climdetr,n=1,axis=0)

		#get moderator variable
		if mod_n==var:
			mod=clim	
		elif mod_n=='none':
			mod=np.zeros(clim.shape)
		else:
			[mod,mod_years]=get_clim(mod_n,model,clim_ssp,start_year)	

		#apply the cap to the moderator variables only (i.e. capping the ME at the maximum seen historically)
		mod=cap_it(mod,caps[:,cap_vars==mod_n])
		#fix marginal effects to that seen in historical period of the DoSE analyses (1979-2014)
		if marg=='fix':
			mod[:,:]=np.nanmean(mod[1978-1952:start_year-1952,:],axis=0)
		elif marg=='movfix':
			mod=np.concatenate((mod[:29,:],mov_av(mod,winN)),axis=0)
		#from 1952 onwards, due to differenced climate data
		mod=mod[1:,:]
	
		climd_base=climd
		mod_base=mod
		[impactCC,impactB]=impact_lag_calc(climd,mod,climd_base,mod_base,param)
		impactCC=impactCC[(clim_yearsd>=start_year) & (clim_yearsd<2100),:]
		growth_impacts[v].append(impactCC)

	#calculate net growth impacts, sum across all variables
	growth_impacts=np.array(growth_impacts)
	net_impacts=np.sum(growth_impacts,axis=0)
	growth_impacts=np.concatenate((growth_impacts,net_impacts[np.newaxis,...]),axis=0)
	del net_impacts
	
	# take mean across different realisations of internal variability
	growth_impacts=np.nanmean(growth_impacts,axis=1)

	#reduce output based on damaged growth trajectory from growth impacts 
	gdp_traj_dams=reduce_output(gdp_traj,growth_impacts)
	del growth_impacts

	#convert output from logarithmic to linear US dollars
	abs_gdp_traj_dams=np.power(np.e,gdp_traj_dams)
	abs_gdp_traj=np.power(np.e,gdp_traj)
	#calculate percentage reductions along each climate trajectory
	perc=np.divide(abs_gdp_traj_dams,abs_gdp_traj)*100

	#aggregate to world regions, and globe
	dam_curves=[]
	#global aggregation
	dam_curves.append(aggreg(perc,np.linspace(0,3609,3610).astype(int),POP_traj))
	#world region aggregation
	for w in range(len(wrld_rgns)):
	       #location within array of given countries in a world region
	       locs=list(mask.loc[mask.NAME_0.isin(rgn_list[w])].index)
	       dam_curves.append(aggreg(perc,locs,POP_traj))
	dam_curves_l.append(dam_curves)

	reg_imps.append(perc[:,:2060-start_year,:])
	gdp_traj_dams_l.append(gdp_traj_dams)	

	#aggregate to national level
	dam_curves_nat=[]
	for iso in isos:
		locs=list(mask.loc[mask.GID_0==iso].index)
		dam_curves_nat.append(aggreg(perc,locs,POP_traj))
	dam_curves_nat_l.append(dam_curves_nat)		

	if nb%20==0:
		print('Done ' + str(nb))
	
#save data
dam_curves_l=np.array(dam_curves_l)
reg_imps=np.array(reg_imps)
dam_curves_nat=np.array(dam_curves_nat_l)
gdp_traj_dams_l=np.array(gdp_traj_dams_l)

NLs=str(NLs[0])+'_'+str(NLs[1])+'_'+str(NLs[2])
np.save('projection_output/dam_curves/' + soc_ssp + '_' + clim_ssp + '_' + regspec + '_NL_' + str(NLs) + '_movfix_' + str(winN) + '_Nboot_' + str(Nboot) + '_seed_' + str(seed) + '.npy',dam_curves_l)
np.save('projection_output/reg_dams/' + soc_ssp + '_' + clim_ssp + '_' + regspec + '_NL_' + str(NLs) + '_movfix_' + str(winN) + '_Nboot_' + str(Nboot) + '_seed_' + str(seed) + '.npy',reg_imps)
np.save('projection_output/nat_dams/' + soc_ssp + '_' + clim_ssp + '_' + regspec + '_NL_' + str(NLs) + '_movfix_' + str(winN) + '_Nboot_' + str(Nboot) + '_seed_' + str(seed) + '.npy',dam_curves_nat)


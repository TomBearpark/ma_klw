#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jan 17 11:24:35 2023

@author: robertcarr: (updated to output plot data csv by TB)
"""

import numpy as np
import pandas as pd
import os
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.patches import Rectangle
import string

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
This code can be used for replicating figure 7 in the NSD article: 
DOSE – Global data set of reported sub-national economic output

I. Definitions:   
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

# Paths:

data_path               = os.path.expanduser('~/Library/CloudStorage/Dropbox/gdp-temp/ma_rep/DOSE replication files/Data/') #'../Data/'

graphics_path           = os.path.expanduser('~/Documents/GitHub/ma_klw/outputs/')

deflator_path           =    data_path +'deflator/'
gennaioli_path          =    data_path +'gennaioli2014/'

# File names:
dose_v2                 =   'DOSE_V2.csv'
gennaioli               =   '10887_2014_9105_MOESM1_ESM.xlsx' 
        # --> data downloaded from https://link.springer.com/article/10.1007/s10887-014-9105-9#Sec5

dose                    =   pd.read_csv(data_path+dose_v2)

data=dose

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
IV. Consistency Check: Match economic data from other papers to DOSE:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"""
a) Matching data
"""
baseline1               =   pd.read_excel(gennaioli_path+gennaioli, 
                                          sheet_name='Data Regional Level',
                                          usecols='A:D,L').set_index('Region')
A = baseline1.copy().reset_index()
A = A.loc[A.Code.isin(list(data.drop_duplicates('GID_0').GID_0))]

regions_G2014 = A.drop_duplicates('Region')[['Code','Region']]

# First matching with dictionary of dose identifiers:
d = dict(zip(data.drop_duplicates('GID_1').region, data.drop_duplicates('GID_1').GID_1))
regions_G2014['GID_1'] = regions_G2014['Region'].apply(lambda x: d.get(x))

regions_G2014.to_excel(gennaioli_path+'gennaioli_regions_identifiers.xlsx', 
                       sheet_name='Data', index=False)

# Manual matching with GID_1-data:
B = pd.read_excel(gennaioli_path+'gennaioli_regions_identifiers_manually_edited.xlsx')
B['helper'] = B.Code+'_'+B.Region
d = dict(zip(B.helper, B.GID_1))

A = baseline1.copy().reset_index()
A['helper'] = A.Code+'_'+A.Region
A['GID_1'] = A['helper'].apply(lambda x: d.get(x))
A = A.loc[A.GID_1.notna()]
A['dup'] = A.duplicated(['GID_1','year'], keep=False) # no duplicated, all good
A = A.set_index(['GID_1','year']).rename(columns={'GDP pc Country':'gennaioli2014'})['gennaioli2014']

# Matching with DOSE data:
data = data.set_index(['GID_1','year'])
data['gennaioli2014'] = np.nan
data.update(A)

data= data.reset_index()

# Correcting the different base years in both datasets:
deflators = pd.read_excel(deflator_path+'2022_03_30_WorldBank_gdp_deflator.xlsx', sheet_name='Data', 
                            index_col=None, usecols='B,E:BM', skiprows=3).set_index('Country Code')
deflators = deflators.dropna(axis=0, how='all')

column = deflators.columns.get_loc(2005)
for i in list(range(0,len(deflators))):
    deflators.iloc[i,:] = (deflators.iloc[i,:]/deflators.iloc[i,column])*100

deflators_us = pd.DataFrame(deflators.loc[deflators.index=='USA'].stack()).rename(columns={0:'deflator_2005_us'}).reset_index().set_index('level_1')
deflators = pd.DataFrame(deflators.stack()).rename(columns={0:'deflator_2005'})

data['deflator_2005'] = np.nan
data['deflator_2005_us'] = np.nan
data = data.set_index(['GID_0','year'])
data.update(deflators)
data = data.reset_index('GID_0')
data.update(deflators_us)

ppp_data = pd.read_excel(deflator_path+'ppp_data_all_countries.xlsx')
ppp_data = ppp_data.loc[ppp_data.year==2005]
d = dict(zip(ppp_data.iso_3, ppp_data.PPP))

data['ppp_2005'] = data['GID_0'].apply(lambda x: d.get(x))
data.loc[data.GID_0=='USA','ppp_2005'] = len(data.loc[data.GID_0=='USA']) * [1]

fx_data = pd.read_excel(deflator_path+'fx_data_all_countries.xlsx')
fx_data = fx_data.loc[fx_data.year==2005]
d = dict(zip(fx_data.iso_3, fx_data.fx))
data['fx_2005'] = data['GID_0'].apply(lambda x: d.get(x))
data.loc[data.GID_0=='USA','fx_2005'] = len(data.loc[data.GID_0=='USA']) * [1]

data['PPP'] = pd.to_numeric(data.PPP, errors='coerce')
data['grp_pc_ppp']=data['grp_pc_lcu'] / data.PPP

data['grp_pc_ppp_2005'] = data['grp_pc_ppp'] *100 / data.deflator_2005_us
data['grp_pc_lcu2005_ppp'] = data.grp_pc_lcu *100 / data.deflator_2005 / data.ppp_2005

data['grp_pc_usd_2005'] = data.grp_pc_usd *100 / data.deflator_2005_us
data['grp_pc_lcu2005_usd'] = data.grp_pc_lcu *100 / data.deflator_2005 / data.fx_2005

data = data.reset_index()

"""
b) Calculate demeaned values
"""
#select ppp or demeaned values
variables = ['grp_pc_ppp_2005','grp_pc_lcu2005_ppp']
#variables = ['grp_pc_usd_2005', 'grp_pc_lcu2005_usd']

D=data.loc[(data.gennaioli2014.notna()) & (data[variables[0]].notna()) & (data[variables[1]].notna())]

#calculate averages by country-year (1), country (2) and region (3), for the two DOSE variables (A, B) and gennaioli variables (C)
A1 = pd.DataFrame(D.groupby(['GID_0','year'])[variables[0]].mean()).rename(columns={variables[0]:variables[0]+'_av'})
B1 = pd.DataFrame(D.groupby(['GID_0','year'])[variables[1]].mean()).rename(columns={variables[1]:variables[1]+'_av'})
A2 = pd.DataFrame(D.groupby(['GID_0'])[variables[0]].mean()).rename(columns={variables[0]:variables[0]+'_av2'})
B2 = pd.DataFrame(D.groupby(['GID_0'])[variables[1]].mean()).rename(columns={variables[1]:variables[1]+'_av2'})
A3 = pd.DataFrame(D.groupby(['GID_1'])[variables[0]].mean()).rename(columns={variables[0]:variables[0]+'_av3'})
B3 = pd.DataFrame(D.groupby(['GID_1'])[variables[1]].mean()).rename(columns={variables[1]:variables[1]+'_av3'})
C1 = pd.DataFrame(D.groupby(['GID_0','year'])['gennaioli2014'].mean()).rename(columns={'gennaioli2014':'G2014_av'})
C2 = pd.DataFrame(D.groupby(['GID_0'])['gennaioli2014'].mean()).rename(columns={'gennaioli2014':'G2014_av2'}) 
C3 = pd.DataFrame(D.groupby(['GID_1'])['gennaioli2014'].mean()).rename(columns={'gennaioli2014':'G2014_av3'})

data[variables[0]+'_av'] = np.nan
data[variables[1]+'_av'] = np.nan
data[variables[0]+'_av2'] = np.nan
data[variables[1]+'_av2'] = np.nan
data[variables[0]+'_av3'] = np.nan
data[variables[1]+'_av3'] = np.nan
data['G2014_av'] = np.nan
data['G2014_av2'] = np.nan
data['G2014_av3']=np.nan

data = data.set_index(['GID_0','year'])
data.update(A1)
data.update(B1)
data.update(C1)

#demean based on the different averages
data['gennaioli2014_demeaned'] = data['gennaioli2014']-data.G2014_av
data[variables[0]+'_demeaned'] = data[variables[0]]-data[variables[0]+'_av']
data[variables[1]+'_demeaned'] = data[variables[1]]-data[variables[1]+'_av']
data = data.reset_index()

#within country
data = data.set_index(['GID_0'])
data.update(A2)
data.update(B2)
data.update(C2)

data['gennaioli2014_demeaned2'] = data['gennaioli2014']-data.G2014_av2
data[variables[0]+'_demeaned2'] = data[variables[0]]-data[variables[0]+'_av2']
data[variables[1]+'_demeaned2'] = data[variables[1]]-data[variables[1]+'_av2']
data = data.reset_index()

#within subnational region
data['GID_1']=dose['GID_1']
data = data.set_index(['GID_1'])
data.update(A3)
data.update(B3)
data.update(C3)

data['gennaioli2014_demeaned3'] = data['gennaioli2014']-data.G2014_av3
data[variables[0]+'_demeaned3'] = data[variables[0]]-data[variables[0]+'_av3']
data[variables[1]+'_demeaned3'] = data[variables[1]]-data[variables[1]+'_av3']
data = data.reset_index()

"""
c) Creating a plot with subplots
"""
#functions to estimate root mean square difference/percentage difference
def RMSPD(vec1,vec2):
	vec1=np.array(vec1)
	vec2=np.array(vec2)
	dev_2=np.sum((2*(vec1-vec2)/(abs(vec1)+abs(vec2)))**2)
	return(np.sqrt(dev_2/len(vec1)))

def RMSD(vec1,vec2):
    vec1=np.array(vec1)
    vec2=np.array(vec2)
    dev_2=np.sum((vec1-vec2)**2)
    return(np.sqrt(dev_2/len(vec1)))

meths=['','_demeaned','_demeaned2','_demeaned3']

#simple linear correlations
for v, var in enumerate(variables):
	for m, meth in enumerate(meths):
		if v==m==0:
			corr=data.loc[(data['gennaioli2014'+meth].notna()) & (data[var+meth].notna()) & (data['gennaioli2014'+meth]!=0) & (data[var+meth]!=0)]
		else:
			corr=corr.loc[(data['gennaioli2014'+meth].notna()) & (data[var+meth].notna()) & (data['gennaioli2014'+meth]!=0) & (data[var+meth]!=0)]

corr_G2014 = corr.loc[(data.gennaioli2014.notna()) & (data[variables[0]].notna())].corr()

correlations = [corr_G2014.round(decimals=4).iloc[corr_G2014.index.get_loc('gennaioli2014'+m),corr_G2014.columns.get_loc(variables[0]+m)] for m in meths] + [corr_G2014.round(decimals=4).iloc[corr_G2014.index.get_loc('gennaioli2014'+m),corr_G2014.columns.get_loc(variables[1]+m)] for m in meths]

#root mean square differences
RMSPDs = [RMSPD(corr['gennaioli2014'+m],corr[variables[0]+m]) for m in meths] + [RMSPD(corr['gennaioli2014'+m],corr[variables[1]+m]) for m in meths]
RMSDs = [RMSD(corr['gennaioli2014'+m],corr[variables[0]+m]) for m in meths] + [RMSD(corr['gennaioli2014'+m],corr[variables[1]+m]) for m in meths]

letters=list(string.ascii_lowercase)

# Output csv for plotting elswhere: 
data.to_csv(data_path+'fig7_plotdata.csv')

#plot
fig = plt.figure(figsize=(10, 17))
gs = gridspec.GridSpec(nrows=4, ncols=2, height_ratios=[1, 1, 1, 1], hspace=0.4, wspace=0.35)

labels=['','demeaned by country-year','demeaned by country','demeaned by subnat. region']
lims=[[0,60000],[-10000,10000],[-15000,15000],[-15000,15000]]
ax=[]
meths=['','_demeaned','_demeaned2','_demeaned3']
for m, meth in enumerate(meths):
    for v, var in enumerate(variables):	
        ax.append(fig.add_subplot(gs[m,v]))
        ax[m*len(variables)+v].annotate(text=letters[m*len(variables)+v],xy=(-0.2,1.1),xycoords='axes fraction',fontsize='medium',weight='bold')
        ax[m*len(variables)+v].set_title('Conversion method ' + str(v+1) + '\n(corr='+'%.3g'%(correlations[v*len(meths)+m],)+')',fontsize='small')
        ax[m*len(variables)+v].scatter(data.loc[data['gennaioli2014'+meth].notna()][var+meth], data.loc[data['gennaioli2014'+meth].notna(),'gennaioli2014'+meth],marker='.',alpha=0.2,color='orange')

        if 'ppp' in var:
            ax[m*len(variables)+v].set_xlabel('DOSE GRP_PC (2005-PPP-USD)\n'+labels[m], fontsize='small')
            ax[m*len(variables)+v].set_ylabel('G2014 GRP per capita (2005-PPP-USD)\n'+labels[m], fontsize='small')
        else:
            ax[m*len(variables)+v].set_xlabel('DOSE GRP_PC (2005-USD)\n'+labels[m], fontsize='small')
            ax[m*len(variables)+v].set_ylabel('G2014 GRP per capita (2005-USD)\n'+labels[m], fontsize='small')
        
        # Added line to create patch            
        ax[m*len(variables)+v].add_patch(Rectangle((lims[m][0], lims[m][0]), lims[m][1]-lims[m][0], lims[m][1]-lims[m][0], edgecolor = 'red', fill=False, lw=2))

plt.savefig(graphics_path+'data_validation_Fig7.png',dpi=300,bbox_inches='tight')

# 		ax[m*len(variables)+v].plot(range(lims[m][0],lims[m][1]), range(lims[m][0],lims[m][1]), color='gray', linewidth=1.5, linestyle='--')
# 		ax[m*len(variables)+v].set_xlim(lims[m][0],lims[m][1])
# 		ax[m*len(variables)+v].set_ylim(lims[m][0],lims[m][1])


"""
if 'ppp' in var:
	plt.savefig(graphics_path+'Fig7.png',dpi=300,bbox_inches='tight')
else:
	plt.savefig(graphics_path+'FigS4.png',dpi=300,bbox_inches='tight')
plt.close()

#log version
lims=[[100,70000],[-10000,10000],[-15000,15000],[-15000,15000]]

fig = plt.figure(figsize=(5, 8))
gs = gridspec.GridSpec(nrows=2, ncols=1, height_ratios=[1, 1], hspace=0.35, wspace=0.35)
ax=[]
for m, meth in enumerate(meths[:1]):
        for v, var in enumerate(variables):

                ax.append(fig.add_subplot(gs[v,m]))
                ax[m*len(variables)+v].annotate(text=letters[m*len(variables)+v],xy=(-0.2,1.1),xycoords='axes fraction',fontsize='medium',weight='bold')
                ax[m*len(variables)+v].set_title('Conversion method ' + str(v+1) + '\n(corr='+'%.3g'%(correlations[v*len(meths)+m],)+')',fontsize='small')
                ax[m*len(variables)+v].scatter(data.loc[data['gennaioli2014'+meth].notna()][var+meth], data.loc[data['gennaioli2014'+meth].notna(),'gennaioli2014'+meth],marker='.',alpha=0.2,color='orange')
                
                ax[m*len(variables)+v].set_xscale('log')
                ax[m*len(variables)+v].set_yscale('log')

                if 'ppp' in var:
                        ax[m*len(variables)+v].set_xlabel('DOSE GRP_PC (2005-PPP-USD)\n'+labels[m], fontsize='small')
                        ax[m*len(variables)+v].set_ylabel('G2014 GRP per capita (2005-PPP-USD)\n'+labels[m], fontsize='small')
                else:
                        ax[m*len(variables)+v].set_xlabel('DOSE GRP_PC (2005-USD)\n'+labels[m], fontsize='small')
                        ax[m*len(variables)+v].set_ylabel('G2014 GRP per capita (2005-USD)\n'+labels[m], fontsize='small')

                ax[m*len(variables)+v].plot(range(lims[m][0],lims[m][1]), range(lims[m][0],lims[m][1]), color='gray', linewidth=1.5, linestyle='--')
                ax[m*len(variables)+v].set_xlim(lims[m][0],lims[m][1])
                ax[m*len(variables)+v].set_ylim(lims[m][0],lims[m][1])

if 'ppp' in var:
	plt.savefig(graphics_path+'FigS3.png',dpi=300,bbox_inches='tight')
else:
	plt.savefig(graphics_path+'scatter_subplots_log.png',dpi=300,bbox_inches='tight')
plt.close()

"""

import pandas as pd
import numpy as np
import os

# Change directory
dataDir = "/home/dhogan/data/gdp_temp/ma_rep/datacode"
os.chdir(dataDir)

# Set arguments
soc_ssp = "ssp2"
clim_ssp = "ssp585"
regspec= 'lagdiff_lintren_fix_spec'
suffix = "proj"
NLs = "8_9_10"
Nboot = 50
winN = 30

df = pd.DataFrame()
for filetag in ["", "_dropuzb", "_dropuzb_bootstrapfix"]:
    for seed in np.arange(1, 21):
        array = np.load(
            "projection_output/dam_curves/"
            + soc_ssp
            + "_" + clim_ssp
            + "_" + regspec
            + "_NL_" + str(NLs)
            + "_movfix_" + str(winN)
            + "_Nboot_" + str(Nboot)
            + "_seed_" + str(seed)
            + filetag
            + ".npy"
        )
        if seed == 1:
            damages = array
        else:
            damages = np.concatenate((damages, array), axis=0)
    
    damages_df = pd.DataFrame(
        {
            'model': suffix + filetag,
            'year': np.linspace(2021,2100,damages.shape[-1]).astype(int),
            'rcp': clim_ssp,
            'num_lags': NLs,
            'median': np.median(damages[:,0,-1,:], axis=0) - 100,
            'mean': np.mean(damages[:,0,-1,:], axis=0) - 100,
            'ub': np.percentile(damages[:,0,-1,:], 95, axis=0) - 100,
            'lb': np.percentile(damages[:,0,-1,:], 5, axis=0) - 100,
        }
    )
    if filetag == "":
        df = damages_df
    else:
        df = pd.concat([df, damages_df])

df.to_feather(f'projection_output/projection_output.feather')

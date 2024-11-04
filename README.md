# Data anomalies cause unprecedented estimate for the economic commitment of climate change

Replication code for Nature Matters Arising (Bearpark, Hogan and Hsiang 2024)

## Data requirements

-   Dose v.1
    -   Available here: <https://zenodo.org/records/4681306>
    -   Download `DOSE_v1.csv`
-   KLW replication data (Dose v.2)
    -   Available here: <https://zenodo.org/records/11064757>
    -   Download `datacode.zip` and unzip
-   Burke et al 2015 data
    -   Available here: <https://purl.stanford.edu/wb587wt4560>
    -   Download `BurkeHsiangMiguel2015_Replication.zip` and unzip
-   World bank UZB data
    -   Available here: <https://data.worldbank.org/indicator/NY.GDP.PCAP.KD.ZG>
    -   Download `API_NY.GDP.PCAP.KD.ZG_DS2_en_csv_v2_3401540.zip` (using the csv download option)

## Code

The replication code for this Matters Arising includes scripts written in Python (v. 3.11.9) and R (v. 4.4.1). Note that several files in this repository are modified versions of replication scripts in KLW <https://zenodo.org/records/11064757>. In particular, we modified `code/feols_bootstrap_regressions_modified.R` and `project_damages_modified.py` for our analysis.


The R scripts require the following packages:
```
pacman, tidyverse, fixest, marginaleffects, broom, arrow, haven, patchwork, glue, ggrepel
```
The Python scripts require the following packages
```
pandas, numpy, scipy
```

The R packages will be installed automatically upon code execution. The python packages can be installed using `pip` or `conda`.

To run the code in this repository:
1. Download the replication files from the four above links, and save them into a folder on your machine.
2. Edit the paths to the corresponding data and code directories in `code/01_setup.R` and `code/project_damages_modified.R`
3. Run the `code/run_analysis.sh` bash script to execute R and Python scripts. Alternatively, manually execute the commands within this bash script directly in the command line.
4. View outputs in the `outputs` folder.

Note that with 1000 bootstrap replications, the code will take some time to run on a normal laptop. Code can be modified to reduce runtime by lowering the number of bootstrap iterations in `code/run_analysis.sh`.


  

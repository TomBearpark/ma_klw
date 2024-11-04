#!/bin/bash

# For each seed 1:20
for i in {1..20}; do
    # Run 50 bootstraps without UZB (first boolean) and with bootstrap fix (second boolean)
    Rscript feols_bootstrap_regressions_modified.R $i 50 "TRUE" "FALSE"  >> logs/output_$i.log 2>&1 &
    Rscript feols_bootstrap_regressions_modified.R $i 50 "TRUE" "TRUE"  >> logs/output_$i.log 2>&1 &

    # Project damages without UZB and with bootstrap fix
    python project_damages_modified.py $i 50 1 0 >> logs/output_$i.log 2>&1 &
    python project_damages_modified.py $i 50 1 1 >> logs/output_$i.log 2>&1 &
done

# Run plot script
Rscript plot.R

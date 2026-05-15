#!/bin/zsh

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion/
max_jobs=16  # tune for M2 Ultra

for subpath in $raw_dir/*; do
    sub_id=$(basename $subpath)
    zsh msmt_connectome.sh $sub_id &

    # throttle: wait when max_jobs are running
    while [[ $(jobs -r | wc -l) -ge $max_jobs ]]; do
        sleep 2
    done
done
wait

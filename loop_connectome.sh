#!/bin/zsh

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion/
for subpath in $raw_dir/23*; do
  sub_id=$(basename $subpath)
  #echo $sub_id &
  zsh msmt_connectome.sh $sub_id &
done
wait
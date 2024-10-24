#!/bin/zsh

script_fpath=$1

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion/
for subpath in $raw_dir/2*; do
  sub_id=$(basename $subpath)
  zsh $script_fpath $sub_id &
done
wait
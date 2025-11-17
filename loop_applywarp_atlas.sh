#!/bin/zsh


raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion/
for subpath in $raw_dir/1*; do
  sub_id=$(basename $subpath)
  echo $sub_id &
  zsh applywarp_atlas_moving-mni_ref-subject.sh  $sub_id &
done
wait 

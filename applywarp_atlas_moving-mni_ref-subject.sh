#!/bin/zsh

# applywarp -i invol -o outvol -r refvol -w warpvol

tian_scale='S2'

atlas_base=atlas-custom_subcort-tian${tian_scale}_cort-aud-vis-carpet
deriv_dir=/Users/dsj3886/data_local/derivatives/
atlas_fpath=${deriv_dir}${atlas_base}/${atlas_base}_atlas_space-MNI152NLin6Asym.nii.gz

sub_id=$1
xfm=standard2acpc_dc
warp_fpath=/Users/dsj3886/data_local/HCP_3T_structural/${sub_id}/MNINonLinear/xfms/${xfm}.nii.gz
ref_fpath=/Users/dsj3886/data_local/HCP_3T_structural/${sub_id}/T1w/T1w_acpc_dc.nii.gz

out_dir=${deriv_dir}/HCP_7T_diffusion/atlas_space-sub/${sub_id}/
mkdir -p $out_dir
out_fpath=${out_dir}/sub-${sub_id}_atlas-custom_subcort-tian${tian_scale}_cort-carpet_atlas_warp-${xfm}_space-T1w.nii.gz

applywarp -i $atlas_fpath -o $out_fpath -r $ref_fpath -w $warp_fpath --interp=nn --verbose
#!/bin/zsh

sub_id=111312
tian_scale=S2
deriv_dir=/Users/dsj3886/data_local/derivatives

atlas_fname=sub-${sub_id}_atlas-custom_subcort-tian${tian_scale}_cort-carpet_atlas_warp-standard2acpc_dc_space-T1w
atlas_fpath=${deriv_dir}/HCP_7T_diffusion/atlas_space-sub/${sub_id}/${atlas_fname}.nii.gz

lut_fname=atlas-custom_subcort-tian${tian_scale}_cort-aud-vis-carpet_lut
lut_fpath=${deriv_dir}/atlas-custom_subcort-tian${tian_scale}_cort-aud-vis-carpet/${lut_fname}.tsv

out_dir=${deriv_dir}/HCP_7T_diffusion/atlas_space-sub/${sub_id}/roi_masks
mkdir -p $out_dir

while IFS=$'\t' read -r idx name; do
    out_fpath=${out_dir}/sub-${sub_id}_roi-${name}_mask.nii.gz
    fslmaths $atlas_fpath -thr $idx -uthr $idx -bin $out_fpath
    echo "  $name (index $idx) -> $out_fpath"
done < $lut_fpath
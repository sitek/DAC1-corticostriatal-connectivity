#!/bin/zsh

# Warp the combined-GP exclusion mask (MNI152NLin6Asym) into subject T1w/ACPC
# space. Parallels applywarp_atlas_moving-mni_ref-subject.sh.

gp_base=atlas-custom_subcort-tianS2_GP-combined
deriv_dir=/Users/dsj3886/data_local/derivatives/
gp_fpath=${deriv_dir}${gp_base}/${gp_base}_atlas_space-MNI152NLin6Asym.nii.gz

sub_id=$1
xfm=standard2acpc_dc
warp_fpath=/Users/dsj3886/data_local/HCP_3T_structural/${sub_id}/MNINonLinear/xfms/${xfm}.nii.gz
ref_fpath=/Users/dsj3886/data_local/HCP_3T_structural/${sub_id}/T1w/T1w_acpc_dc.nii.gz

if [[ ! -f $warp_fpath || ! -f $ref_fpath ]]; then
    echo "SKIP $sub_id: missing HCP_3T_structural warp/ref"
    exit 0
fi

out_dir=${deriv_dir}/HCP_7T_diffusion/atlas_space-sub/${sub_id}/
mkdir -p $out_dir
out_fpath=${out_dir}/sub-${sub_id}_${gp_base}_mask_warp-${xfm}_space-T1w.nii.gz

applywarp -i $gp_fpath -o $out_fpath -r $ref_fpath -w $warp_fpath --interp=nn
echo "done $sub_id -> $out_fpath"

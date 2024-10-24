#!/bin/zsh

xfm_fpath='/Users/dsj3886/data_local/reference/tpl-MNI152NLin2009cAsym_from-MNI152NLin6Asym_mode-image_xfm.h5'
fixed_fpath='/Users/dsj3886/data_local/HCP_3T_structural/100610/MNINonLinear/T1w.nii.gz'
moving_fpath='/Users/dsj3886/data_local/derivatives/atlas-custom_subcort-tians3_cort-carpet/atlas-custom_subcort-tians3_cort-carpet_atlas.nii.gz'
out_fpath='/Users/dsj3886/data_local/derivatives/atlas-custom_subcort-tians3_cort-carpet/atlas-custom_subcort-tians3_cort-carpet_atlas_space-MNI152NLin6Asym.nii.gz'

antsApplyTransforms -i $moving_fpath -r $fixed_fpath -o $out_fpath -n GenericLabel -t ${xfm_fpath} -v
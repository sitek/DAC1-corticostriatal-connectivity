#!/bin/zsh

tian_scale='S2'

# ATLAS_BASE (env) selects the atlas version; default is the 54-region v1 atlas.
#   ATLAS_BASE=atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal-v2 zsh applytransforms_MNI2009cAsym-to-MNINLin6Asym.sh
atlas_base=${ATLAS_BASE:-atlas-custom_subcort-tian${tian_scale}_cort-aud-vis-prefrontal}

xfm_fpath='/Users/dsj3886/data_local/reference/tpl-MNI152NLin2009cAsym_from-MNI152NLin6Asym_mode-image_xfm.h5'
fixed_fpath='/Users/dsj3886/data_local/HCP_3T_structural/100610/MNINonLinear/T1w.nii.gz'
moving_fpath="/Users/dsj3886/data_local/derivatives/${atlas_base}/${atlas_base}_atlas.nii.gz"
out_fpath="/Users/dsj3886/data_local/derivatives/${atlas_base}/${atlas_base}_atlas_space-MNI152NLin6Asym.nii.gz"

/Applications/ants-2.5.1-arm/bin/antsApplyTransforms -i $moving_fpath -r $fixed_fpath -o $out_fpath -n GenericLabel -t ${xfm_fpath} -v
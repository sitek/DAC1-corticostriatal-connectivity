#!/bin/zsh

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion/
deriv_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion
nthreads=1

sub_base=$1
echo "basename: $sub_base"

out_dir=${deriv_dir}/msmt_csd_nthreads-$nthreads/$sub_base/
mkdir -p $out_dir

dwi_fpath=${raw_dir}/${sub_base}/T1w/Diffusion_7T/data.nii.gz
bval_fpath=${raw_dir}/${sub_base}/T1w/Diffusion_7T/bvals
bvec_fpath=${raw_dir}/${sub_base}/T1w/Diffusion_7T/bvecs
mask_fpath=${raw_dir}/${sub_base}/T1w/Diffusion_7T/nodif_brain_mask.nii.gz

echo "Generating MSMT response functions for $dwi_fpath ..."
dwi2response  -nocleanup dhollander -nthreads $nthreads \
          -mask $mask_fpath \
          -fslgrad $bvec_fpath $bval_fpath \
          $dwi_fpath \
          $out_dir/wm_response.txt \
          $out_dir/gm_response.txt \
          $out_dir/csf_response.txt  

echo "Generating MSMT FODs for $dwi_fpath ..."
dwi2fod -nthreads $nthreads \
        -mask $mask_fpath \
        -fslgrad $bvec_fpath $bval_fpath \
        msmt_csd \
        $dwi_fpath \
        $out_dir/wm_response.txt $out_dir/wmfod.mif \
        $out_dir/gm_response.txt $out_dir/gm.mif \
        $out_dir/csf_response.txt $out_dir/csf.mif
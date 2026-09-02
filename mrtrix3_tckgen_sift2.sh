#!/bin/zsh

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion/
deriv_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion
nthreads=2

sub_base=$1
echo "basename: $sub_base"

mask_fpath=${raw_dir}/${sub_base}/T1w/Diffusion_7T/nodif_brain_mask.nii.gz

out_dir=${deriv_dir}/msmt_csd_nthreads-1/$sub_base/

echo "Generating MSMT streamlines  ..."
tckgen -nthreads $nthreads -select 10000000 \
       -debug \
       -seed_image $mask_fpath \
       --force \
       $out_dir/wmfod.mif \
       $out_dir/streamlines_alg-iFOD2_nsl-10mil.tck 

echo "SIFT2 streamlines  ..."
# -out_mu writes the SIFT2 proportionality coefficient (mu); the connectome
# must be multiplied by mu for valid cross-subject comparison.
tcksift2 -nthreads $nthreads \
       -debug \
       --force \
       -out_mu $out_dir/sift2_mu_streamlines_alg-iFOD2_nsl-10mil.txt \
       $out_dir/streamlines_alg-iFOD2_nsl-10mil.tck \
       $out_dir/wmfod.mif \
       $out_dir/sift2_weights_streamlines_alg-iFOD2_nsl-10mil

echo "Creating reduced streamline file for visualization ..."
tckedit $out_dir/streamlines_alg-iFOD2_nsl-10mil.tck \
        -number 100000 \
        --force \
        $out_dir/streamlines_alg-iFOD2_nsl-10mil_reduced-100k.tck
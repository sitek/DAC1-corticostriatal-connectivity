#!/bin/zsh

# Re-run tcksift2 on EXISTING streamlines solely to obtain the SIFT2
# proportionality coefficient (mu), which is required to make connectome
# edge weights comparable across subjects.
#
# This does NOT re-run tckgen. tcksift2 is deterministic, so the recomputed
# weights are identical to the originals; they are overwritten in place.
#
# Usage (single subject):   zsh sift2_mu.sh <sub_id>
# Loop over all subjects:   zsh loop_mrtrix3.sh sift2_mu.sh

sub_base=$1
echo "basename: $sub_base"

deriv_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion
nthreads=2

out_dir=${deriv_dir}/msmt_csd_nthreads-1/$sub_base
tck_fpath=$out_dir/streamlines_alg-iFOD2_nsl-10mil.tck
fod_fpath=$out_dir/wmfod.mif
weights_fpath=$out_dir/sift2_weights_streamlines_alg-iFOD2_nsl-10mil
mu_fpath=$out_dir/sift2_mu_streamlines_alg-iFOD2_nsl-10mil.txt

if [[ ! -f $tck_fpath || ! -f $fod_fpath ]]; then
    echo "SKIP $sub_base: missing $tck_fpath or $fod_fpath"
    exit 0
fi

echo "SIFT2 (mu) for $sub_base ..."
tcksift2 -nthreads $nthreads \
       --force \
       -out_mu $mu_fpath \
       $tck_fpath \
       $fod_fpath \
       $weights_fpath

echo "  mu -> $(cat $mu_fpath 2>/dev/null)"

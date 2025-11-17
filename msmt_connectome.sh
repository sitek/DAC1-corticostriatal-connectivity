#!/bin/zsh

sub_id=$1

tian_scale='S2'

alg=iFOD2
nsl=10mil
data_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion/msmt_csd_nthreads-1/
tck_dir=${data_dir}/${sub_id}
sl_base=streamlines_alg-${alg}_nsl-${nsl}
tck_fpath=${tck_dir}/${sl_base}.tck
echo "streamline file: ${tck_fpath}"

sift2_weights_fpath=${tck_dir}/sift2_weights_streamlines_alg-${alg}_nsl-${nsl}

desc_base=atlas-custom_subcort-tian${tian_scale}_cort-aud-vis-carpet
opt_desc="_sift2"
out_dir=${tck_dir}/connectome_${sl_base}/${desc_base}${opt_desc}/
mkdir -p $out_dir
echo "output directory: ${out_dir}"

atlas_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion/atlas_space-sub/${sub_id}/
atlas_fpath=${atlas_dir}/sub-${sub_id}_${desc_base}_atlas_warp-standard2acpc_dc_space-T1w.nii.gz

echo "generating connectome"
tck2connectome $tck_fpath \
  $atlas_fpath \
  ${out_dir}/${sl_base}_connectome${opt_desc}.csv \
  -tck_weights_in $sift2_weights_fpath \
  -out_assignments ${out_dir}/${sl_base}_assignments${opt_desc}.txt \
  -symmetric \
  -force

echo "generating edge streamlines"
connectome2tck $tck_fpath \
  ${out_dir}/${sl_base}_assignments${opt_desc}.txt \
  ${out_dir}/${sl_base}${opt_desc}_edge- \
  -force
#!/bin/zsh

# v2 of run_subject.sh: same per-subject pipeline, but tckgen excludes any
# streamline that passes through the combined globus pallidus mask
# (atlas-custom_subcort-tianS2_GP-combined, both hemispheres, aGP+pGP).
#
# Runs CONCURRENTLY with the baseline (no-exclusion) run_subject.sh pass, so
# every output path is kept distinct from the baseline's (own tck/weights/mu/
# connectome dir, via the _gpexcl-suffixed sl_base) -- no shared files, no
# collisions, safe to run both loops on this machine at the same time.
#
# Requires: wmfod.mif, the 54-region subject atlas, AND the GP mask warped to
# this subject (applywarp_GPmask_moving-mni_ref-subject.sh). Subjects missing
# any of these are skipped, not failed -- re-run the loop later to pick them up.
#
# Usage (one subject):  zsh run_subject_gpexcl.sh <sub_id>
# Loop (throttled):     zsh loop_mrtrix3.sh run_subject_gpexcl.sh <max_jobs>

set -u

sub_id=$1
echo "==== $sub_id (GP-excluded) ===="

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion
deriv_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion
tian_scale='S2'
alg=iFOD2
nsl=10mil
nstreamlines=10000000
nthreads=2
min_free_gb=20

sl_base=streamlines_alg-${alg}_nsl-${nsl}_gpexcl
out_dir=${deriv_dir}/msmt_csd_nthreads-1/${sub_id}
tck_fpath=${out_dir}/${sl_base}.tck
fod_fpath=${out_dir}/wmfod.mif
mask_fpath=${raw_dir}/${sub_id}/T1w/Diffusion_7T/nodif_brain_mask.nii.gz
weights_fpath=${out_dir}/sift2_weights_${sl_base}
mu_fpath=${out_dir}/sift2_mu_${sl_base}.txt
reduced_fpath=${out_dir}/${sl_base}_reduced-100k.tck

desc_base=atlas-custom_subcort-tian${tian_scale}_cort-carpet
opt_desc="_sift2-noscaling"
atlas_fpath=${deriv_dir}/atlas_space-sub/${sub_id}/sub-${sub_id}_${desc_base}_atlas_warp-standard2acpc_dc_space-T1w.nii.gz
gp_mask_fpath=${deriv_dir}/atlas_space-sub/${sub_id}/sub-${sub_id}_atlas-custom_subcort-tianS2_GP-combined_mask_warp-standard2acpc_dc_space-T1w.nii.gz
conn_dir=${out_dir}/connectome_${sl_base}/${desc_base}${opt_desc}
conn_csv=${conn_dir}/${sl_base}_connectome${opt_desc}.csv
assignments=${conn_dir}/${sl_base}_assignments${opt_desc}.txt

# ---- guards -----------------------------------------------------------------
if [[ -f $conn_csv ]]; then
    echo "  SKIP: connectome already exists ($conn_csv)"
    exit 0
fi
if [[ ! -f $fod_fpath ]]; then
    echo "  SKIP: missing FOD $fod_fpath"
    exit 0
fi
if [[ ! -f $mask_fpath ]]; then
    echo "  SKIP: missing seed mask $mask_fpath"
    exit 0
fi
if [[ ! -f $atlas_fpath ]]; then
    echo "  SKIP: missing subject atlas $atlas_fpath (run applywarp_atlas first)"
    exit 0
fi
if [[ ! -f $gp_mask_fpath ]]; then
    echo "  SKIP: missing GP exclusion mask $gp_mask_fpath (run applywarp_GPmask first)"
    exit 0
fi

n_labels=$(mrstats -output max "$atlas_fpath" 2>/dev/null | tr -d '[:space:]')
if [[ "$n_labels" != "54" ]]; then
    echo "  SKIP: subject atlas has ${n_labels:-?} regions, expected 54"
    exit 0
fi

free_gb=$(df -g "$out_dir" | tail -1 | awk '{print $4}')
if [[ ${free_gb:-0} -lt $min_free_gb ]]; then
    echo "  ABORT: only ${free_gb} GB free on the data volume (need >= ${min_free_gb})"
    exit 1
fi

mkdir -p $conn_dir

# ---- 1. tractography (GP-excluded) ----------------------------------------
tck_count=$(tckinfo "$tck_fpath" 2>/dev/null | awk '/^[[:space:]]*count:/ {print $2; exit}')
if [[ -n $tck_count && $tck_count -ge $nstreamlines ]]; then
    echo "  tckgen: reusing existing complete tractogram (count=$tck_count)"
else
    echo "  tckgen -exclude GP ..."
    tckgen -nthreads $nthreads -select $nstreamlines \
           -seed_image $mask_fpath \
           -exclude $gp_mask_fpath \
           --force \
           $fod_fpath \
           $tck_fpath || { echo "  FAIL: tckgen"; exit 1; }
fi

# ---- 2. SIFT2 (weights + mu) -------------------------------------------
echo "  tcksift2 ..."
tcksift2 -nthreads $nthreads \
       --force \
       -out_mu $mu_fpath \
       $tck_fpath \
       $fod_fpath \
       $weights_fpath || { echo "  FAIL: tcksift2"; exit 1; }
echo "    mu = $(cat $mu_fpath 2>/dev/null)"

# ---- 3. reduced streamline file for visualization ---------------------
echo "  tckedit (reduced-100k) ..."
tckedit $tck_fpath -number 100000 --force $reduced_fpath \
    || echo "  WARN: tckedit failed (continuing)"

# ---- 4. connectome (raw SIFT2 sums, NO -scale_invnodevol) ------------
echo "  tck2connectome ..."
tck2connectome $tck_fpath \
  $atlas_fpath \
  $conn_csv \
  -tck_weights_in $weights_fpath \
  -out_assignments $assignments \
  -symmetric \
  -force || { echo "  FAIL: tck2connectome"; exit 1; }

# ---- 5. per-edge streamlines (striatal nodes only) --------------------
echo "  connectome2tck ..."
connectome2tck $tck_fpath \
  $assignments \
  ${conn_dir}/${sl_base}${opt_desc}_edge- \
  -nodes 1,2,3,4,5,6,7,8 \
  -force || echo "  WARN: connectome2tck failed (continuing)"

# ---- 6. drop the full tractogram ----------------------------------
if [[ -f $conn_csv ]]; then
    echo "  rm full tck ($(du -h $tck_fpath | cut -f1))"
    rm -f $tck_fpath
else
    echo "  KEEP full tck: connectome CSV was not produced"
fi

echo "  done: $sub_id"

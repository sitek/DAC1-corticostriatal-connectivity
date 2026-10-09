#!/bin/zsh

# Unattended v2 pipeline: 70-region atlas -> subject space -> GP-excluded
# re-tracking of every subject. Run atlas_construction.ipynb with
# ATLAS_VERSION = 'v2' first (and eyeball the new masks), then:
#
#   nohup caffeinate -i zsh run_v2_pipeline.sh 8 > v2_pipeline.out 2>&1 & disown
#   tail -f v2_pipeline.out
#
# Re-running is safe: run_subject_gpexcl.sh skips subjects whose v2 connectome
# already exists, so an interrupted run resumes where it stopped.
# Afterwards, run connectivity_statistics_gpexcl_visual-v2.ipynb.

set -eu

max_jobs=${1:-8}
here=${0:A:h}
cd $here

export ATLAS_BASE=atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal-v2
export ATLAS_DESC=atlas-custom_subcort-tianS2_cort-carpet-v2
n_expected=70
deriv_dir=/Users/dsj3886/data_local/derivatives

n_labels() { mrstats -output max "$1" 2>/dev/null | tr -d '[:space:]' }

# ---- 0. v2 atlas from atlas_construction.ipynb --------------------------
atlas_2009c=${deriv_dir}/${ATLAS_BASE}/${ATLAS_BASE}_atlas.nii.gz
[[ -f $atlas_2009c ]] || { echo "missing $atlas_2009c -- run atlas_construction.ipynb with ATLAS_VERSION = 'v2'"; exit 1; }
[[ $(n_labels $atlas_2009c) == $n_expected ]] || { echo "$atlas_2009c has $(n_labels $atlas_2009c) labels, expected $n_expected"; exit 1; }

# ---- 1. MNI152NLin2009cAsym -> MNI152NLin6Asym ----------------------------
echo "$(date '+%F %T')  1. antsApplyTransforms -> MNI152NLin6Asym"
zsh applytransforms_MNI2009cAsym-to-MNINLin6Asym.sh
atlas_nlin6=${deriv_dir}/${ATLAS_BASE}/${ATLAS_BASE}_atlas_space-MNI152NLin6Asym.nii.gz
[[ $(n_labels $atlas_nlin6) == $n_expected ]] || { echo "$atlas_nlin6 has $(n_labels $atlas_nlin6) labels, expected $n_expected"; exit 1; }

# ---- 2. MNI -> each subject's T1w/acpc space -------------------------------
echo "$(date '+%F %T')  2. applywarp atlas -> subject space"
zsh loop_applywarp_atlas.sh > /dev/null
n_ok=0; n_bad=0
for f in ${deriv_dir}/HCP_7T_diffusion/atlas_space-sub/*/sub-*_${ATLAS_DESC}_atlas_warp-standard2acpc_dc_space-T1w.nii.gz(N); do
    if [[ $(n_labels $f) == $n_expected ]]; then (( n_ok += 1 )); else (( n_bad += 1 )); echo "  WARN: $f has $(n_labels $f) labels"; fi
done
echo "  subject atlases with $n_expected labels: $n_ok   (other: $n_bad)"
(( n_ok > 0 )) || { echo "no usable v2 subject atlases"; exit 1; }

# ---- 3. re-track + SIFT2 + connectome, max_jobs subjects at a time ---------
echo "$(date '+%F %T')  3. run_subject_gpexcl_v2.sh over all subjects (max_jobs=${max_jobs})"
zsh loop_mrtrix3.sh run_subject_gpexcl_v2.sh $max_jobs

conns=(${deriv_dir}/HCP_7T_diffusion/msmt_csd_nthreads-1/*/connectome_streamlines_alg-iFOD2_nsl-10mil_gpexcl-v2/${ATLAS_DESC}_sift2-noscaling/*_connectome_sift2-noscaling.csv(N))
echo "$(date '+%F %T')  done: ${#conns} v2 connectomes"

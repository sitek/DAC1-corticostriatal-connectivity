#!/bin/zsh

# v2 atlas run: same per-subject pipeline as run_subject_gpexcl.sh (GP-excluded
# tckgen, SIFT2, tck2connectome), re-tracked against the 70-region v2 atlas.
# Every output gets the gpexcl-v2 tag, so nothing from the v1 run (tck, SIFT2
# weights, mu, connectomes) is touched.
#
# Requires the v2 subject atlases:
#   ATLAS_BASE=atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal-v2 \
#   ATLAS_DESC=atlas-custom_subcort-tianS2_cort-carpet-v2 zsh loop_applywarp_atlas.sh
#
# Usage (one subject):  zsh run_subject_gpexcl_v2.sh <sub_id>
# Loop (throttled):     zsh loop_mrtrix3.sh run_subject_gpexcl_v2.sh <max_jobs>

export SL_TAG=gpexcl-v2
export ATLAS_DESC=atlas-custom_subcort-tianS2_cort-carpet-v2
export N_LABELS=70

exec zsh ${0:A:h}/run_subject_gpexcl.sh "$@"

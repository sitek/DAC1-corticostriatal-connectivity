#!/bin/zsh
#
# Warp the atlas into every subject's T1w/ACPC space, <max_jobs> at a time.
#
#   zsh loop_applywarp_atlas.sh [max_jobs] [subjects_file]
#
# subjects_file: optional, one subject ID per line. Defaults to every
# directory under raw_dir (all available subjects).
#
# ATLAS_BASE / ATLAS_DESC (env, optional): forwarded to
# applywarp_atlas_moving-mni_ref-subject.sh to target a specific atlas
# version (e.g. the v2 atlas, as run_v2_pipeline.sh exports them); unset
# falls back to that script's own v1 defaults.
#
# Concurrency is enforced with `xargs -P`, same as loop_mrtrix3.sh -- the
# previous version launched every subject's applywarp at once with a bare
# `&`/`wait` loop. On 100 concurrent FSL warps that silently dropped output
# for ~20 subjects with no error surfaced (their stdout/stderr went nowhere;
# the only visible failures were the few with genuinely missing input).
#
# Each subject's output goes to logs/applywarp_atlas/<sub>.log (appended).
# Re-running is safe: applywarp overwrites its own output, nothing else is
# touched.

set -u

max_jobs=${1:-8}
subjects_file=${2:-}

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion
here=${0:A:h}
log_dir=${here}/logs/applywarp_atlas
mkdir -p "$log_dir"

if [[ -n $subjects_file ]]; then
    subjects=("${(@f)$(<$subjects_file)}")
else
    subjects=($raw_dir/*(/N:t))
fi
(( ${#subjects} )) || { echo "no subjects (check $subjects_file or $raw_dir)"; exit 1; }

echo "$(date '+%F %T')  start ${#subjects} subjects  max_jobs=${max_jobs}  ATLAS_BASE=${ATLAS_BASE:-<default>}"
echo "logs: $log_dir"

printf '%s\n' $subjects \
  | xargs -P "$max_jobs" -I '{}' zsh -c '
        sub=$1; here=$2; logdir=$3
        {
            echo "=== $(date "+%F %T")  start $sub ==="
            zsh "$here/applywarp_atlas_moving-mni_ref-subject.sh" "$sub"
            st=$?
            echo "=== $(date "+%F %T")  end $sub  exit=$st ==="
        } >> "$logdir/$sub.log" 2>&1
        printf "%s  %-10s exit=%d\n" "$(date "+%F %T")" "$sub" "$st"
    ' _ '{}' "$here" "$log_dir"

echo "$(date '+%F %T')  loop finished"

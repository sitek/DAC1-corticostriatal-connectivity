#!/bin/zsh
#
# Run a per-subject script over all HCP 7T subjects, <max_jobs> at a time.
#
#   zsh loop_mrtrix3.sh <script.sh> [max_jobs]
#
# Notes
#   - Concurrency is enforced with `xargs -P`. The previous `jobs -r | wc -l`
#     guard did nothing in zsh: a builtin `jobs` inside a pipeline runs in a
#     subshell that cannot see the parent's job table, so it always returned 0
#     and every subject launched at once.
#   - Each subject's output goes to  logs/<script>/<sub>.log  (appended).
#   - A one-line pass/fail per subject is printed to stdout as they finish.
#   - Re-running is safe: run_subject.sh skips subjects that already finished.
#
# Launch it detached so a closed terminal (SIGHUP) or Ctrl-Z can't stop it --
# that killed the earlier attempts. In zsh, `&!` backgrounds and disowns:
#
#   nohup caffeinate -i zsh loop_mrtrix3.sh run_subject.sh 8 > loop.out 2>&1 &!
#
# caffeinate -i keeps the machine from idle-sleeping during the run.
# Watch progress:  tail -f loop.out

set -u

script_fpath=${1:?usage: zsh loop_mrtrix3.sh <script.sh> [max_jobs]}
max_jobs=${2:-8}

raw_dir=/Users/dsj3886/data_local/HCP_7T_diffusion
here=${0:A:h}
log_dir=${here}/logs/${script_fpath:t:r}
mkdir -p "$log_dir"

subjects=($raw_dir/*(/N:t))
(( ${#subjects} )) || { echo "no subject directories under $raw_dir"; exit 1; }

echo "$(date '+%F %T')  start ${#subjects} subjects  max_jobs=${max_jobs}  script=${script_fpath}"
echo "logs: $log_dir"

printf '%s\n' $subjects \
  | xargs -P "$max_jobs" -I '{}' zsh -c '
        sub=$1; script=$2; logdir=$3
        {
            echo "=== $(date "+%F %T")  start $sub ==="
            zsh "$script" "$sub"
            st=$?
            echo "=== $(date "+%F %T")  end $sub  exit=$st ==="
        } >> "$logdir/$sub.log" 2>&1
        printf "%s  %-10s exit=%d\n" "$(date "+%F %T")" "$sub" "$st"
    ' _ '{}' "$script_fpath" "$log_dir"

echo "$(date '+%F %T')  loop finished"

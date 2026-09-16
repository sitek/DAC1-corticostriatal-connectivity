#!/usr/bin/env python3
"""
For every subject with both a baseline connectome and a warped GP mask,
and every striatum-touching edge in that baseline connectome, count how many
of the edge's streamlines also pass through the GP mask -- i.e. exactly the
streamlines that -exclude would have discarded under the GP-exclusion pass.

Uses only already-completed baseline output (per-edge .tck files kept by
connectome2tck) -- no tractography is re-run, nothing baseline/gpexcl-in-
progress is touched.

Output:
  stats_exports/gp_exclusion_edge_scan.tsv     per subject x edge
  stats_exports/gp_exclusion_edge_summary.tsv  aggregated per edge, region-named
"""
import os
import re
import csv
import subprocess
import tempfile
from glob import glob
from concurrent.futures import ThreadPoolExecutor, as_completed

D = '/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion/msmt_csd_nthreads-1'
DERIV = '/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion'
LUT_FPATH = ('/Users/dsj3886/data_local/derivatives/'
             'atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal/'
             'atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal_lut.tsv')
OUT_DIR = os.path.join(os.path.dirname(__file__), 'stats_exports')
STRIATAL = set(range(1, 9))
EDGE_PAT = re.compile(r'_edge-(\d+)-(\d+)\.tck$')
N_WORKERS = 16

region_list = {}
with open(LUT_FPATH) as fh:
    for line in fh:
        idx, name = line.strip().split('\t')
        region_list[int(idx)] = name


def tck_count(path):
    out = subprocess.run(['tckinfo', path], capture_output=True, text=True).stdout
    m = re.search(r'^\s*count:\s*(\d+)', out, re.M)
    return int(m.group(1)) if m else None


def scan_one(sub, edge_fpath, lo, hi, gp_mask):
    n_total = tck_count(edge_fpath)
    if not n_total:
        return None
    with tempfile.NamedTemporaryFile(suffix='.tck') as tmp:
        r = subprocess.run(['tckedit', edge_fpath, '-include', gp_mask,
                            tmp.name, '-force', '-quiet'])
        n_gp = tck_count(tmp.name) if r.returncode == 0 else None
    if n_gp is None:
        return None
    return dict(subject=sub, lo=lo, hi=hi, n_total=n_total, n_gp=n_gp,
               frac_gp=n_gp / n_total)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    jobs = []
    subjects = sorted(os.listdir(D))
    for sub in subjects:
        gp_mask = (f'{DERIV}/atlas_space-sub/{sub}/sub-{sub}_'
                   'atlas-custom_subcort-tianS2_GP-combined_mask_'
                   'warp-standard2acpc_dc_space-T1w.nii.gz')
        if not os.path.isfile(gp_mask):
            continue
        conn_dir = (f'{D}/{sub}/connectome_streamlines_alg-iFOD2_nsl-10mil/'
                   'atlas-custom_subcort-tianS2_cort-carpet_sift2-noscaling')
        if not os.path.isdir(conn_dir):
            continue
        # connectome2tck sometimes writes the SAME edge twice, under both
        # label orderings (edge-6-28.tck and edge-28-6.tck, byte-identical) --
        # dedupe per (subject, canonical edge) so each edge is only scanned
        # once per subject.
        seen_edges = {}
        for f in glob(f'{conn_dir}/*_edge-*.tck'):
            m = EDGE_PAT.search(f)
            if not m:
                continue
            lo, hi = int(m.group(1)), int(m.group(2))
            if lo not in STRIATAL and hi not in STRIATAL:
                continue
            seen_edges[tuple(sorted((lo, hi)))] = (f, lo, hi)
        for f, lo, hi in seen_edges.values():
            jobs.append((sub, f, lo, hi, gp_mask))

    n_subs = len({j[0] for j in jobs})
    print(f'{len(jobs)} (subject, edge) pairs to scan across {n_subs} subjects')

    rows = []
    with ThreadPoolExecutor(max_workers=N_WORKERS) as ex:
        futs = {ex.submit(scan_one, *j): j for j in jobs}
        done = 0
        for fut in as_completed(futs):
            r = fut.result()
            if r is not None:
                rows.append(r)
            done += 1
            if done % 2000 == 0:
                print(f'  {done} / {len(jobs)}')

    raw_fpath = os.path.join(OUT_DIR, 'gp_exclusion_edge_scan.tsv')
    with open(raw_fpath, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=['subject', 'lo', 'hi', 'n_total',
                                           'n_gp', 'frac_gp'], delimiter='\t')
        w.writeheader()
        w.writerows(rows)
    print('wrote', raw_fpath, f'({len(rows)} rows)')

    # aggregate per edge across subjects, keyed by the CANONICAL (sorted)
    # label pair -- raw (lo, hi) from the filename isn't a reliable key (see
    # dedup note above), and a subject could in principle contribute more
    # than one row here only if scan_one() logic changes, so also guard
    # against double-counting a subject within one edge.
    agg = {}
    for r in rows:
        key = tuple(sorted((r['lo'], r['hi'])))
        a = agg.setdefault(key, dict(subjects=set(), sum_total=0, sum_gp=0, fracs=[]))
        if r['subject'] in a['subjects']:
            continue
        a['subjects'].add(r['subject'])
        a['sum_total'] += r['n_total']
        a['sum_gp'] += r['n_gp']
        a['fracs'].append(r['frac_gp'])

    def region(idx):
        return region_list.get(idx, f'label{idx}')

    summary_fpath = os.path.join(OUT_DIR, 'gp_exclusion_edge_summary.tsv')
    with open(summary_fpath, 'w', newline='') as fh:
        w = csv.writer(fh, delimiter='\t')
        w.writerow(['striatum', 'other', 'n_subjects', 'sum_n_total', 'sum_n_gp',
                   'pooled_frac_gp', 'mean_frac_gp', 'sd_frac_gp'])
        srt = sorted(agg.items(), key=lambda kv: -(kv[1]['sum_gp'] / max(kv[1]['sum_total'], 1)))
        for (lo, hi), a in srt:
            # display striatal label first when the edge has one, for readability
            striatal_first = lo if lo in STRIATAL else (hi if hi in STRIATAL else lo)
            other = hi if striatal_first == lo else lo
            fracs = a['fracs']
            mean_f = sum(fracs) / len(fracs)
            sd_f = (sum((x - mean_f) ** 2 for x in fracs) / len(fracs)) ** 0.5
            w.writerow([region(striatal_first), region(other), len(a['subjects']),
                       a['sum_total'], a['sum_gp'], a['sum_gp'] / max(a['sum_total'], 1),
                       round(mean_f, 4), round(sd_f, 4)])
    print('wrote', summary_fpath)


if __name__ == '__main__':
    main()

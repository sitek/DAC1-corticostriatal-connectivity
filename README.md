# DAC1-corticostriatal-connectivity
Code for auditory corticostriatal tractography analysis in HCP 7T diffusion-weighted MRI.

Original analysis was conducted on the MGH 760 µm dataset in DSI Studio. Added a few HCP participants in second analysis, then added mrtrix3 in MGH dataset for third analysis. (See [bioRxiv preprint](https://doi.org/10.1101/2022.08.04.502679).) Now conducting full analysis in mrtrix3 with 100 HCP 7T participants.

**Primary analysis excludes streamlines that pass through the globus pallidus** (`tckgen -exclude`), to support the claim that measured streamlines are direct corticostriatal projections rather than pallidal-relay pathways — see `docs/methods_connectome_normalisation.md`. N = 97 of 100 (3 participants lack the HCP 3T structural data needed to warp the exclusion mask; not a data-quality exclusion). An otherwise-identical no-exclusion pass (N ≈ 100) is kept as a comparison baseline.

## Code structure
1. Tractography
  - `mrtrix3_msmt.sh`, which includes:
   - `dwi2response`
   - `dwi2fod`
  - `mrtrix3_tckgen_sift2.sh`, which includes:
   - `tckgen`
   - `tcksift2` – with `-out_mu` (the SIFT2 proportionality coefficient µ, needed for cross-subject connectome scaling)
   - `tckedit` – which creates a visualization-friendly reduced-count streamline file
  - `sift2_mu.sh` – re-runs only `tcksift2 -out_mu` on existing streamlines (for subjects whose SIFT2 predates the `-out_mu` addition; does **not** re-run `tckgen`)
  - Helper function: `loop_mrtrix3.sh`
   - Takes a per-subject script path as input and runs it over all HCP subjects, `max_jobs` at a time (via `xargs -P`)
2. Atlas generation
  - `atlas_construction.ipynb`, which creates a reference space, mrtrix3-compatible atlas of relevant regions (8 striatal subdivisions from Tian S2 + 46 cortical ROIs = 54 total). `ATLAS_VERSION = 'v2'` appends 16 more cortical labels (55–70: cuneal, lingual, temporo-occipital MTG/ITG, posterior MTG, temporal pole, postcentral gyrus, SMA) as `..._cort-aud-vis-prefrontal-v2`; labels 1–54 are unchanged
  - `applytransforms_MNI2009cAsym-to-MNINLin6Asym.sh` — converts the new atlas from MNI2009cAsym → MNI152NLin6Asym using ANTs (`ATLAS_BASE` env var selects the atlas version)
  - `applywarp_atlas_moving-mni_ref-subject.sh` — warps from MNI152NLin6Asym → subject T1w space using FSL applywarp (`ATLAS_BASE` / `ATLAS_DESC` env vars select the atlas version and subject-space filename)
    - `loop_applywarp_atlas.sh` – helper that loops over all subjects for atlas transformation
  - `applywarp_GPmask_moving-mni_ref-subject.sh` — warps the combined globus pallidus exclusion mask (Tian S2 aGP+pGP, both hemispheres) into subject T1w space, same warp fields as the main atlas
3. Connectivity and statistics
  - `run_subject_gpexcl.sh` – **primary pipeline**: identical to `run_subject.sh` below but `tckgen -exclude`s the warped GP mask. Every output (tractogram/weights/mu/connectome dir) is `_gpexcl`-suffixed so it can run concurrently with `run_subject.sh` on the same subjects without collision. Skips subjects missing the GP mask. Run as `zsh loop_mrtrix3.sh run_subject_gpexcl.sh 4`. The `SL_TAG` / `ATLAS_DESC` / `N_LABELS` env vars select the atlas version (defaults: the 54-region v1 run).
  - `run_subject_gpexcl_v2.sh` – wrapper that runs `run_subject_gpexcl.sh` against the 70-region v2 atlas, re-tracking every subject. All outputs are `_gpexcl-v2`-tagged, so the v1 tractograms' SIFT2 weights, µ and connectomes are never overwritten.
  - `run_v2_pipeline.sh` – unattended v2 driver: v2 atlas → MNI152NLin6Asym → subject space (with label-count checks) → `run_subject_gpexcl_v2.sh` over all subjects. Run `atlas_construction.ipynb` with `ATLAS_VERSION = 'v2'` first, then `nohup caffeinate -i zsh run_v2_pipeline.sh 8 > v2_pipeline.out 2>&1 &!`
  - `run_subject.sh` – **no-exclusion baseline pipeline**, kept for comparison: `tckgen` → `tcksift2 -out_mu` → `tckedit` (reduced) → `tck2connectome` → `connectome2tck`, then deletes the ~12 GB tractogram. Skips subjects whose atlas has < 54 regions. Idempotent (re-run the loop to resume). Run as `zsh loop_mrtrix3.sh run_subject.sh 8`.
  - `msmt_connectome.sh` – standalone `tck2connectome` + `connectome2tck` (used by `run_subject.sh`, or on its own). Output goes to `..._cort-carpet_sift2-noscaling/`: SIFT2-weighted edge sums **without** `-scale_invnodevol`.
    - `loop_connectome.sh` – helper that loops over all subjects for connectome generation
  - `combine_tcks.sh` – merges per-edge striatum–auditory .tck files into per-striatal-ROI bundles for visualization
  - `gp_exclusion_edge_scan.py` – for the baseline (no-exclusion) connectomes, counts how many of each edge's streamlines also cross the GP mask (i.e. what `-exclude` would have removed); writes `stats_exports/gp_exclusion_edge_scan.tsv` (per subject × edge) and `gp_exclusion_edge_summary.tsv` (aggregated per edge)
  - `connectivity_statistics_gpexcl.ipynb` – **primary analysis notebook**: normalisation, group-mean plots, and across-subject statistics on the GP-excluded connectomes. Outputs go to `stats_exports/gpexcl/` and `figures/gpexcl/`.
  - `connectivity_statistics_no-gpexcl.ipynb` – same analysis on the no-exclusion baseline connectomes, for comparison. Outputs go to `stats_exports/no-gpexcl/` and `figures/no-gpexcl/`.
  - `connectivity_statistics_gpexcl_visual.ipynb` – GP-excluded analysis across four cortical networks (auditory, prefrontal, visual, motor): per-network statistics, the network comparison, auditory/visual hierarchy analyses (absolute and proportional), per-cell means recording the direction of each effect, and a log-transform sensitivity analysis. `ATLAS_VERSION` in its config cell selects v1 or v2 data. Outputs go to `stats_exports/gpexcl_visual/` and `figures/gpexcl_visual/`.
  - `connectivity_statistics_gpexcl_visual-v2.ipynb` – the same notebook with `ATLAS_VERSION = 'v2'` (70-region atlas, re-tracked connectomes). Outputs go to `stats_exports/gpexcl_visual-v2/` and `figures/gpexcl_visual-v2/`.
  - `stats_fmt.py` – APA-style formatting helpers; `export_anova` / `export_posthoc` write tidy TSVs from statsmodels or pingouin results; `export_cell_means` writes per-cell means/medians so the direction of each effect is recorded
  - `archive/mean_connectivity.ipynb` – **archival** (earlier `-scale_invnodevol`-based analysis; superseded)

## Connectivity normalisation

The connectome CSVs hold raw SIFT2-weighted streamline sums. In both
`connectivity_statistics_gpexcl.ipynb` and `connectivity_statistics_no-gpexcl.ipynb`,
each striatal–cortical edge (striatum *i*, cortex *j*) for subject *s* is
normalised to

    C = µ_s · Σ(SIFT2 weights for the pair) / V_striatum(s, i)

- **µ_s** — the SIFT2 proportionality coefficient (`tcksift2 -out_mu`), which
  makes streamline weights comparable across subjects.
- **V_striatum** — the volume (mm³) of the striatal node in that subject's own
  T1w/ACPC-space parcellation, i.e. connectivity as a density per unit striatal
  tissue. The cortical node is left unnormalised.

`-scale_invnodevol` is **not** used: it scales an edge by `2/(Vᵢ+Vⱼ)`, which
entangles both node volumes and cannot be inverted to normalise by one node.

See `docs/methods_connectome_normalisation.md` for a manuscript-ready description.

## Statistics

- **Omnibus** repeated-measures ANOVAs on the (untransformed) connectivity
  values: `statsmodels` `AnovaRM` for 3–4 within-factor designs; `pingouin`
  `rm_anova` (Greenhouse–Geisser + partial η²) for 2-factor designs.
- **Pairwise post-hoc** comparisons use the **Wilcoxon signed-rank test**
  (`pg.pairwise_tests(parametric=False)`, Benjamini–Hochberg FDR), because the
  connectivity values are strongly right-skewed with a spike at zero.
- Outputs: `stats_exports/no-gpexcl/` and `figures/no-gpexcl/` for the
  baseline notebook; `stats_exports/gpexcl/` and `figures/gpexcl/` for the
  primary (GP-excluded) notebook, kept separate so neither overwrites the
  other.

# DAC1-corticostriatal-connectivity
Code for auditory corticostriatal tractography analysis in HCP 7T diffusion-weighted MRI.

Original analysis was conducted on the MGH 760 µm dataset in DSI Studio. Added a few HCP participants in second analysis, then added mrtrix3 in MGH dataset for third analysis. (See [bioRxiv preprint](https://doi.org/10.1101/2022.08.04.502679).) Now conducting full analysis in mrtrix3 with 100 HCP 7T participants.

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
   - Takes a function path as input
   - Loops that function call over HCP subjects
2. Atlas generation
  - `atlas_construction.ipynb`, which creates a reference space, mrtrix3-compatible atlas of relevant regions
  - `applytransforms_MNI2009cAsym-to-MNINLin6Asym.sh` — converts the new atlas from MNI2009cAsym → MNI152NLin6Asym using ANTs
  - `applywarp_atlas_moving-mni_ref-subject.sh ` — warps from MNI152NLin6Asym → subject T1w space using FSL applywarp
    - `loop_applywarp_atlas.sh` – helper function that loops over all subjects for atlas transformation
3. Connectivity and statistics
  - `msmt_connectome.sh` – includes `tck2connectome` then `connectome2tck` to generate per-edge .tck files for the given atlas file
    - Outputs go to `..._cort-carpet_sift2-noscaling/`: SIFT2-weighted edge sums **without** `-scale_invnodevol`. Node-volume normalisation (striatal volume only) and the µ scaling are applied in `connectivity_statistics.ipynb`, where `-scale_invnodevol`'s `2/(v_i+v_j)` form could not be undone for one node.
    - `loop_connectome.sh` – help function that loops over all subjects for connectome generation
  - `combine_tcks.sh` – merges per-edge striatum–auditory .tck files into per-striatal-ROI bundles for visualization
  - `connectivity_statistics.ipynb` – create group-mean plots and perform across-subject statistical testing
  - `mean_connectivity.ipynb` – **archival** (earlier invnodevol-based analysis; superseded by `connectivity_statistics.ipynb`)
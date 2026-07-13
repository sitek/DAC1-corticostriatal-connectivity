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
   - `tcksift2`
   - `tckedit` – which creates a visualization-friendly reduced-count streamline file
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
    - `loop_connectome.sh` – help function that loops over all subjects for connectome generation
  - `connectivity_statistics.ipynb` – create group-mean plots and perform across-subject statistical testing
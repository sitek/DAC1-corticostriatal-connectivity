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
  - Reference space
  - Warp to subjects' space
3. Connectivity and statistics
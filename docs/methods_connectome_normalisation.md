# Methods — tractography and connectome normalisation

Manuscript-ready description of the current pipeline. Numbers in **[brackets]**
should be confirmed against the exact preprocessing before submission.

---

## Tractography

Diffusion data (HCP 7T, **[1.05 mm]** isotropic, **[b = 1000/2000 s/mm²]**) were
processed with MRtrix3 **[3.0.x]**. Fibre orientation distributions were
estimated by multi-shell multi-tissue constrained spherical deconvolution
(`dwi2response` / `dwi2fod`). Whole-brain probabilistic tractography was
performed with `tckgen` (iFOD2 algorithm), seeding uniformly within the
brain mask until 10 million streamlines were selected. Streamline weights were
then estimated with SIFT2 (`tcksift2`), which also yields the proportionality
coefficient µ relating the streamline density to the fibre orientation
distribution amplitude.

### Globus pallidus exclusion (primary analysis)

To ensure the measured streamlines reflect direct corticostriatal projections
rather than pathways passing through or relayed via the globus pallidus,
streamlines intersecting a combined globus pallidus mask were excluded during
tractography generation (`tckgen -exclude`). The mask combined the anterior
and posterior globus pallidus subdivisions of the Tian S2 subcortical atlas,
bilaterally, in each participant's native space (same registration pipeline
as the parcellation below). This GP-excluded pass is the primary analysis; an
otherwise-identical pass without the exclusion was also generated and is
reported as a comparison baseline.

Of the 100 HCP 7T participants, 97 were included in the primary analysis;
three were excluded because their HCP 3T structural data (needed to warp the
exclusion mask into native space) is no longer available on ConnectomeDB —
not a data-quality exclusion. A small number of participants may be further
excluded on a per-analysis basis if a striatal subdivision has zero volume
after warping (flagged automatically at load time); this is independent of
the GP-exclusion criterion.

## Atlas

A custom parcellation (54 regions) combined the Tian S2 subcortical atlas —
providing eight striatal subdivisions (anterior/posterior caudate and
anterior/posterior putamen, per hemisphere) — with 46 cortical regions of
interest (auditory, prefrontal, and visual). The atlas was constructed in
MNI152NLin2009cAsym space, transformed to MNI152NLin6Asym (ANTs), and warped to
each participant's native T1w/ACPC space (FSL `applywarp`, nearest-neighbour).

## Connectome construction

Structural connectomes were built with `tck2connectome` using the SIFT2
streamline weights, producing for each region pair the sum of the weights of
streamlines assigned to it. Node-volume scaling (`-scale_invnodevol`) was **not**
applied at this stage (see below).

## Connectivity normalisation

For each participant *s* and each striatal–cortical region pair (striatal node
*i*, cortical node *j*), connectivity was defined as

> C(s, i, j) = µ_s · [ Σ_k w_k ] / V(s, i)

where Σ_k w_k is the summed SIFT2 weight of streamlines connecting *i* and *j*,
µ_s is the participant's SIFT2 proportionality coefficient, and V(s, i) is the
volume (mm³) of striatal node *i* in that participant's native-space
parcellation. Multiplying by µ_s renders the weighted streamline counts
comparable across participants; dividing by the striatal node volume expresses
connectivity as a weighted streamline density per unit striatal tissue. The
cortical node was deliberately left unnormalised, so that connectivity reflects
the density of the projection reaching a given volume of striatum.

The MRtrix3 `-scale_invnodevol` option was not used because it scales each edge
by 2 / (V_i + V_j) — a function of the *sum* of both node volumes that cannot be
factorised, and therefore cannot be inverted to normalise by the striatal node
alone.

## Statistical analysis

Connectivity was analysed with repeated-measures ANOVA (within-participant
factors: striatal structure [caudate/putamen], rostro-caudal subdivision,
cortical region, and hemisphere). Two-factor models were fitted with
Greenhouse–Geisser correction and partial η² effect sizes. Pairwise post-hoc
comparisons used the Wilcoxon signed-rank test with Benjamini–Hochberg
false-discovery-rate correction, as the connectivity values were strongly
right-skewed with a point mass at zero (region pairs with no connecting
streamlines).

#!/bin/zsh

# Unweighted track-density images (TDI) of striatum <-> cortex bundles, for
# visualization. One map per striatal ROI x cortical group (auditory /
# prefrontal / visual), built from the per-edge .tck files that
# connectome2tck kept. Same-hemisphere edges only (as in combine_tcks.sh).
#
# NOT SIFT2-weighted: the weights index the deleted full tractogram, so these
# are raw streamline counts -- fine for figures, not comparable to the
# connectivity values used in the stats.
#
# Also writes {striatal ROI}_rgb.nii.gz: a 3-volume overlay, one striatal ROI
# per file, R=auditory G=prefrontal B=visual, each channel the *_clean map
# scaled to its own max (0-1) so hues are comparable. View in mrview with the
# image's colourmap set to "Colour by direction" (or split volumes in nilearn).
#
# Usage: zsh tdi_bundles.sh <sub_id> [gpexcl|baseline] [thresh_frac] [vox_mm]
#   thresh_frac  voxels below this fraction of the bundle's max density are
#                zeroed in the *_clean map (default 0.05)
#   vox_mm       TDI grid resolution (default 0.5, finer than the 1.05 mm dMRI)

set -u

sub_id=$1
pass=${2:-gpexcl}
thresh_frac=${3:-0.05}
vox=${4:-0.5}

tian_scale='S2'
alg=iFOD2
nsl=10mil
deriv_dir=/Users/dsj3886/data_local/derivatives
sub_dir=${deriv_dir}/HCP_7T_diffusion/msmt_csd_nthreads-1/${sub_id}

if [[ $pass == gpexcl ]]; then
    sl_base=streamlines_alg-${alg}_nsl-${nsl}_gpexcl
elif [[ $pass == baseline ]]; then
    sl_base=streamlines_alg-${alg}_nsl-${nsl}
else
    echo "pass must be gpexcl or baseline"; exit 1
fi

desc_base=atlas-custom_subcort-tian${tian_scale}_cort-carpet
opt_desc="_sift2-noscaling"
conn_dir=${sub_dir}/connectome_${sl_base}/${desc_base}${opt_desc}
template=${deriv_dir}/HCP_7T_diffusion/atlas_space-sub/${sub_id}/sub-${sub_id}_${desc_base}_atlas_warp-standard2acpc_dc_space-T1w.nii.gz
lut_fpath=${deriv_dir}/atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal/atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal_lut.tsv

[[ -d $conn_dir ]]   || { echo "SKIP $sub_id: no connectome dir $conn_dir"; exit 0 }
[[ -f $template ]]   || { echo "SKIP $sub_id: no template $template"; exit 0 }

out_dir=${conn_dir}/tdi
mkdir -p $out_dir
tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT

typeset -A roi_idx
while IFS=$'\t' read -r idx name; do
    roi_idx[$name]=$idx
done < $lut_fpath

striatal_rois=(aPUT-lh pPUT-lh aCAU-lh pCAU-lh aPUT-rh pPUT-rh aCAU-rh pCAU-rh)
typeset -A groups
groups[auditory]="HG PP PT STGa STGp"
groups[prefrontal]="OFC ACC FMC IFGt IFGo"
groups[visual]="LOCsup LOCinf IntraCalc TempOccFus OccFus SupraCalc OccPole"

for str_roi in $striatal_rois; do
    hemi=${str_roi##*-}
    pfx=$([[ $hemi == lh ]] && echo L || echo R)
    str_i=${roi_idx[$str_roi]}

    typeset -A gmax
    gmax=()
    for group in auditory prefrontal visual; do
        edge_files=()
        for cort in ${=groups[$group]}; do
            cort_i=${roi_idx[${pfx}-${cort}]}
            [[ -z $cort_i ]] && { echo "  warn: ${pfx}-${cort} not in LUT"; continue }
            lo=$(( str_i < cort_i ? str_i : cort_i ))
            hi=$(( str_i < cort_i ? cort_i : str_i ))
            f=${conn_dir}/${sl_base}${opt_desc}_edge-${lo}-${hi}.tck
            [[ -f $f ]] && edge_files+=($f)
        done
        if [[ ${#edge_files[@]} -eq 0 ]]; then
            echo "  ${str_roi} x ${group}: no edge files, skipping"
            continue
        fi

        base=${out_dir}/${str_roi}_${group}
        tckedit $edge_files $tmp/bundle.tck -force -quiet || { echo "  FAIL tckedit ${str_roi} ${group}"; continue }
        n=$(tckinfo $tmp/bundle.tck | awk '/^[[:space:]]*count:/ {print $2; exit}')
        if [[ -z $n || $n -eq 0 ]]; then
            echo "  ${str_roi} x ${group}: 0 streamlines, skipping"
            continue
        fi

        tckmap $tmp/bundle.tck ${base}_tdi.nii.gz \
               -template $template -vox $vox -force -quiet || { echo "  FAIL tckmap ${str_roi} ${group}"; continue }

        mx=$(mrstats -quiet -output max ${base}_tdi.nii.gz | tr -d '[:space:]')
        thr=$(awk -v m=$mx -v f=$thresh_frac 'BEGIN{print m*f}')
        mrcalc ${base}_tdi.nii.gz $thr -gt ${base}_tdi.nii.gz -mult \
               ${base}_tdi_clean.nii.gz -force -quiet
        gmax[$group]=$mx

        echo "  ${str_roi} x ${group}: ${n} streamlines, max=${mx}, thresh=${thr}"
    done

    # combined RGB overlay: each group's clean map divided by its own max
    # (0-1), stacked as volumes R=auditory, G=prefrontal, B=visual
    if [[ ${#gmax[@]} -eq 3 ]]; then
        chans=()
        for group in auditory prefrontal visual; do
            mrcalc ${out_dir}/${str_roi}_${group}_tdi_clean.nii.gz ${gmax[$group]} -div \
                   $tmp/${group}_norm.nii.gz -force -quiet
            chans+=($tmp/${group}_norm.nii.gz)
        done
        mrcat -axis 3 $chans ${out_dir}/${str_roi}_rgb.nii.gz -force -quiet
        echo "  ${str_roi}: RGB overlay (R=auditory G=prefrontal B=visual)"
    else
        echo "  ${str_roi}: missing a group, no RGB overlay"
    fi
done

echo "done $sub_id -> $out_dir"

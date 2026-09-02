#!/bin/zsh

sub_id=$1

tian_scale='S2'

alg=iFOD2
nsl=10mil
data_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion/msmt_csd_nthreads-1/
tck_dir=${data_dir}/${sub_id}
sl_base=streamlines_alg-${alg}_nsl-${nsl}
tck_fpath=${tck_dir}/${sl_base}.tck
echo "streamline file: ${tck_fpath}"

lut_fpath=/Users/dsj3886/data_local/derivatives/atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal/atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal_lut.tsv

sift2_weights_fpath=${tck_dir}/sift2_weights_streamlines_alg-${alg}_nsl-${nsl}

desc_base=atlas-custom_subcort-tian${tian_scale}_cort-carpet
# Match msmt_connectome.sh. Edge .tck files are identical regardless of
# connectome scaling, but the output folder name must line up.
opt_desc="_sift2-noscaling"
out_dir=${tck_dir}/connectome_${sl_base}/${desc_base}${opt_desc}/
mkdir -p $out_dir
echo "output directory: ${out_dir}"

atlas_dir=/Users/dsj3886/data_local/derivatives/HCP_7T_diffusion/atlas_space-sub/${sub_id}/
atlas_fpath=${atlas_dir}/sub-${sub_id}_${desc_base}_atlas_warp-standard2acpc_dc_space-T1w.nii.gz

echo "combining striatum-auditory streamlines by ROI"

# Parse LUT: name -> index
typeset -A roi_idx
while IFS=$'\t' read -r idx name; do
    roi_idx[$name]=$idx
done < $lut_fpath

striatal_rois=(aPUT-lh pPUT-lh aCAU-lh pCAU-lh aPUT-rh pPUT-rh aCAU-rh pCAU-rh)
typeset -A aud_rois
aud_rois[lh]="L-HG L-PP L-PT L-STGa L-STGp"
aud_rois[rh]="R-HG R-PP R-PT R-STGa R-STGp"

combined_dir=${out_dir}/combined_striatum_auditory
mkdir -p $combined_dir

for str_roi in $striatal_rois; do
    hemi=${str_roi##*-}  # lh or rh
    str_i=${roi_idx[$str_roi]}
    if [[ -z $str_i ]]; then
        echo "Warning: $str_roi not in LUT, skipping"
        continue
    fi

    edge_files=()
    for cort_roi in ${=aud_rois[$hemi]}; do
        cort_i=${roi_idx[$cort_roi]}
        if [[ -z $cort_i ]]; then
            echo "Warning: $cort_roi not in LUT, skipping"
            continue
        fi

        # connectome2tck names files with lower index first
        lo=$(( str_i  < cort_i ? str_i  : cort_i ))
        hi=$(( str_i  < cort_i ? cort_i : str_i  ))
        f="${out_dir}/${sl_base}${opt_desc}_edge-${lo}-${hi}.tck"
        [[ -f $f ]] && edge_files+=($f) || echo "Warning: missing $f"
    done

    if [[ ${#edge_files[@]} -gt 0 ]]; then
        out_tck="${combined_dir}/${str_roi}_auditory.tck"
        echo "  $str_roi (${#edge_files[@]} edges) -> $out_tck"
        tckedit $edge_files $out_tck -force
    fi
done

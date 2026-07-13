#!/bin/zsh

atlas_dir=/Users/dsj3886/data_local/derivatives/atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal
atlas_fpath=${atlas_dir}/atlas-custom_subcort-tianS2_cort-aud-vis-prefrontal_atlas_space-MNI152NLin6Asym.nii.gz
out_fpath=${atlas_dir}/atlas-custom_subcort-tianS2_cort-auditory_atlas_space-MNI152NLin6Asym.nii.gz
lut_fpath=${atlas_dir}/atlas-custom_subcort-tianS2_cort-auditory_lut.tsv
tmp=${atlas_dir}/.tmp_roi.nii.gz

typeset -a orig_indices new_indices roi_names
orig_indices=(9  10  11  12     13     14   15   16   17     18)
new_indices=( 1   2   3   4      5      6    7    8    9     10)
roi_names=(L-HG L-PP L-PT L-STGa L-STGp R-HG R-PP R-PT R-STGa R-STGp)

fslmaths $atlas_fpath -mul 0 $out_fpath

for i in {1..${#orig_indices}}; do
    orig=${orig_indices[$i]}
    new=${new_indices[$i]}
    name=${roi_names[$i]}
    fslmaths $atlas_fpath -thr $orig -uthr $orig -bin -mul $new $tmp
    fslmaths $out_fpath -add $tmp $out_fpath
    echo "  $name: $orig -> $new"
done

rm -f $tmp

rm -f $lut_fpath
for i in {1..${#new_indices}}; do
    echo "${new_indices[$i]}\t${roi_names[$i]}" >> $lut_fpath
done

echo "Done: $out_fpath"

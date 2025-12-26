#!/bin/bash
# Manual Cleanup Script for PET-NeuroProject
# Removes intermediate files for subjects 01-24 to free up space for Subject 25.
# CAUTION: This deletes files. Ensure you have the final results or don't need these intermediates.

start_sub=1
end_sub=24

echo "Starting cleanup for subjects $start_sub to $end_sub..."

for i in $(seq -f "%02g" $start_sub $end_sub); do
    subject="sub-$i"
    base_dir="$HOME/Desktop/derivatives/data/$subject"
    
    # Check if directory exists
    if [ ! -d "$base_dir" ]; then
        echo "Directory not found for $subject, skipping."
        continue
    fi
    
    echo "Cleaning $subject..."
    
    # 1. SPM Intermediate NIfTIs (Large)
    # These are safe to delete if 'pet/${subject}_pet_to_MNI_smoothed.nii.gz' exists (which it should)
    rm -f "$base_dir/pet/sw${subject}_pet_avg.nii"
    rm -f "$base_dir/pet/w${subject}_pet_avg.nii"
    
    # 2. SPM Deformation Fields (Large)
    # Only needed if you plan to re-apply normalization later.
    rm -f "$base_dir/anat/y_${subject}_T1w.reoriented.nii"
    
    # 3. Intermediate FSL Processing Files
    rm -f "$base_dir/pet/${subject}_pet_crop.nii.gz"
    rm -f "$base_dir/pet/${subject}_pet_avg.nii.gz"
    rm -f "$base_dir/anat/${subject}_T1w_preproc.nii.gz"
    
    # 4. Large Uncompressed Inputs for QC
    # CHECK: Only delete these if the QC snapshots already exist!
    qc_dir="$HOME/Desktop/derivatives/QC/$subject"
    if [ -f "$qc_dir/qc_coreg.png" ] && [ -f "$qc_dir/qc_norm.png" ]; then
        echo "QC snapshots found. Removing QC input NIfTIs..."
        rm -f "$base_dir/pet/${subject}_pet_avg.nii"
        rm -f "$base_dir/anat/${subject}_T1w.reoriented.nii"
    else
        echo "WARNING: QC snapshots NOT found for $subject. Keeping QC input NIfTIs."
    fi
    
    # 5. Resampled PET from Analysis step (can be regenerated easily)
    rm -f "$base_dir/pet/${subject}_pet_resampled_to_mask.nii.gz"

done

echo "Cleanup complete. Check 'df -h' to see reclaimed space."

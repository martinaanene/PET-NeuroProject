#!/bin/bash

# =================================================================================
# SCRIPT TO RUN SAMSEG & EXTRACT SUVR VALUES IN MNI SPACE (v4 - All ROIs, 1mm)
#
# This script is a complete workflow that:
# 1. Loads all necessary software (FSL, FreeSurfer).
# 2. Runs SAMSEG on native T1 image to create anatomical segmentations.
# 3. Converts the SAMSEG output to a NIFTI file.
# 4. Loops through the list of 4 ROI pairs.
# 5. For each ROI, warps the native-space mask to MNI space.
# 6. Extracts the mean SUVR value from a pre-existing MNI-space SUVR image.
# 7. Appends all results to a final CSV file.
# =================================================================================

# Go into the sub-02 directory
cd ~/Desktop/CAPSTONE/capstonebids/sub-02/

# --- 1. LOAD REQUIRED SOFTWARE MODULES ---
# ---------------------------------------------------------------------------------
echo "Loading software modules..."
ml fsl/6.0.7.8
ml freesurfer/7.3.2


# --- 2. SETUP: PLEASE VERIFY THESE FILENAMES AND PATHS! ---
# ---------------------------------------------------------------------------------
subject="sub-02"

# Your input T1 image (in native space)
native_t1_image="anat/${subject}_T1w.nii.gz"

# Your final SUVR image (already created and in MNI space)
mni_suvr_image="pet/${subject}_SUVR_in_MNI.nii.gz"

# The warp file from registering the T1 to MNI space (created by fnirt)
# THIS IS A CRITICAL FILE - MAKE SURE THE PATH IS CORRECT!
t1_to_mni_warp_file="anat/${subject}_T1w_to_MNI_warp.nii.gz"

# A standard MNI template brain to use as a reference for warping.
# MNI SUVR image MUST also be 1mm.
mni_reference_brain="$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz"

# The final output CSV file
output_csv="${subject}_results.csv"

# The all-in-one segmentation file that this script will create
native_segmentation_file="${subject}_samseg_rois.nii.gz"


# --- 3. RUN SAMSEG SEGMENTATION (if not already done) ---
# ---------------------------------------------------------------------------------
if [ ! -f "$native_segmentation_file" ]; then
    echo "--- Running SAMSEG to create native-space segmentations (this will take 5-10 minutes)... ---"
    
    # a. Run the main SAMSEG command
    run_samseg -i "$native_t1_image" \
               -o "$PWD/samseg_output/${subject}" \
               --threads 8
               
    # b. Convert the SAMSEG output (.mgz) to a NIFTI file (.nii.gz)
    mri_convert "samseg_output/${subject}/seg.mgz" "$native_segmentation_file"
    
    echo "--- SAMSEG finished. Segmentation file created: $native_segmentation_file ---"
else
    echo "--- Found existing segmentation file: $native_segmentation_file. Skipping SAMSEG. ---"
fi


# --- 4. CREATE CSV HEADER (if the file doesn't exist) ---
# ---------------------------------------------------------------------------------
if [ ! -f "$output_csv" ]; then
    echo "Creating new CSV file: $output_csv"
    echo "subject_id,roi_name,mean_suvr_mni" > "$output_csv"
fi


# --- 5. DEFINE YOUR ROIS ---
# ---------------------------------------------------------------------------------
# ROIs are: Hippocampus, Amygdala, Thalamus, and Caudate.
ROI_NAMES=( "Right-Hippocampus" "Left-Hippocampus" "Right-Amygdala" "Left-Amygdala" "Right-Thalamus" "Left-Thalamus" "Right-Caudate" "Left-Caudate" )
ROI_LABELS=( 53 17 54 18 49 10 50 11 )


# --- 6. MAIN LOOP: Create masks, warp them, and extract values ---
# ---------------------------------------------------------------------------------
echo "--- Starting ROI value extraction... ---"
for (( i=0; i<${#ROI_NAMES[@]}; i++ )); do

    roi_name=${ROI_NAMES[$i]}
    roi_label=${ROI_LABELS[$i]}

    echo "Processing ROI: $roi_name (Label: $roi_label)"

    # a. Create a temporary mask in NATIVE space
    temp_mask_native="temp_${roi_name}_native.nii.gz"
    fslmaths "$native_segmentation_file" -thr "$roi_label" -uthr "$roi_label" -bin "$temp_mask_native"

    # b. WARP the native mask to MNI space
    temp_mask_mni="temp_${roi_name}_mni.nii.gz"
    applywarp --in="$temp_mask_native" \
              --ref="$mni_reference_brain" \
              --warp="$t1_to_mni_warp_file" \
              --out="$temp_mask_mni" \
              --interp=nn

    # c. Calculate the mean SUVR value from the MNI SUVR image using the MNI mask
    mean_value=$(fslstats "$mni_suvr_image" -k "$temp_mask_mni" -M)

    # d. Append the result to the CSV file
    echo "$subject,$roi_name,$mean_value" >> "$output_csv"

    # e. Clean up the temporary mask files
    rm "$temp_mask_native" "$temp_mask_mni"

done

echo ""
echo "--- SCRIPT COMPLETE ---"
echo "Results have been saved to: $output_csv"

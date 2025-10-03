#!/bin/bash

# =================================================================================
# SCRIPT TO CALCULATE GLOBAL CORTICAL SUVR & CENTILOID (v7 - User-Specified)
#
# This complete workflow will:
# 1. Change to the correct subject directory.
# 2. Load specified software versions (FSL 6.0.7.8, FreeSurfer 7.3.2).
# 3. Use Centiloid parameters for [11C]PiB tracer.
# 4. Run SAMSEG on a native T1 image.
# 5. Create a global cortical mask using user-defined labels (3 and 42).
# 6. Warp the native-space cortical mask to 1mm MNI space.
# 7. Extract the mean cortical SUVR value from a pre-existing MNI-space SUVR image.
# 8. Convert the SUVR value to the Centiloid scale.
# 9. Save the subject ID, SUVR, and Centiloid values to a final CSV file.
# =================================================================================


# --- 1. NAVIGATE TO THE SUBJECT'S DIRECTORY ---
# ---------------------------------------------------------------------------------
echo "Changing directory to the subject's folder..."
cd ~/Desktop/CAPSTONE/capstonebids/sub-02/


# --- 2. LOAD REQUIRED SOFTWARE MODULES ---
# ---------------------------------------------------------------------------------
echo "Loading software modules..."
ml fsl/6.0.7.8
ml freesurfer/7.3.2


# --- 3. SETUP: PLEASE VERIFY THESE FILENAMES AND PATHS! ---
# ---------------------------------------------------------------------------------
subject="sub-02"

# === CRITICAL CENTILOID PARAMETERS for [11C]PiB ===
# Using the values you provided for PiB with a whole cerebellum reference.
CENTILOID_SUVR_ZERO=1.009
CENTILOID_SUVR_100=2.076
# ================================================

# Your input T1 image (in native space, path is now relative to the new directory)
native_t1_image="anat/${subject}_T1w.nii.gz"

# Your final SUVR image (already created and in MNI space)
mni_suvr_image="pet/${subject}_SUVR_in_MNI.nii.gz"

# The warp file from registering the T1 to MNI space (created by fnirt)
t1_to_mni_warp_file="anat/${subject}_T1w_to_MNI_warp.nii.gz"

# A standard MNI template brain to use as a reference for warping.
# Set to 1mm as requested. Your MNI SUVR image MUST also be 1mm.
mni_reference_brain="$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz"

# The final output CSV file
output_csv="${subject}_global_cortical_results.csv"

# The all-in-one segmentation file that this script will create
native_segmentation_file="${subject}_samseg_rois.nii.gz"


# --- 4. RUN SAMSEG SEGMENTATION (if not already done) ---
# ---------------------------------------------------------------------------------
if [ ! -f "$native_segmentation_file" ]; then
    echo "--- Running SAMSEG to create native-space segmentations... ---"

    # Detect available CPUs and choose a safe number of threads
    CPUS=$(nproc)
    THREADS=$((CPUS / 2))
    if [ $THREADS -lt 1 ]; then
        THREADS=1
    fi

    echo "Detected $CPUS CPUs. Using $THREADS threads for SAMSEG."

    run_samseg -i "$native_t1_image" \
               -o "$PWD/samseg_output/${subject}" \
               --threads $THREADS > samseg_log.txt 2>&1

    mri_convert "samseg_output/${subject}/seg.mgz" "$native_segmentation_file"
    echo "--- SAMSEG finished. ---"
else
    echo "--- Found existing segmentation file. Skipping SAMSEG. ---"
fi


# --- 5. CREATE CSV HEADER ---
# ---------------------------------------------------------------------------------
echo "Creating new CSV file: $output_csv"
echo "subject_id,global_cortical_suvr,global_cortical_centiloid" > "$output_csv"


# --- 6. CREATE GLOBAL CORTICAL MASK ---
# ---------------------------------------------------------------------------------
echo "--- Creating global cortical mask using labels 3 and 42... ---"

# a. Create a mask of the Left Cortex using label 3 (in NATIVE space).
# NOTE: In standard FreeSurfer, label 3 is Left-Cerebral-White-Matter.
temp_mask_left_native="temp_left_cortex_native.nii.gz"
fslmaths "$native_segmentation_file" -thr 3 -uthr 3 -bin "$temp_mask_left_native"

# b. Create a mask of the Right Cortex using label 42 (in NATIVE space).
# NOTE: In standard FreeSurfer, label 42 is Right-Cerebral-White-Matter.
temp_mask_right_native="temp_right_cortex_native.nii.gz"
fslmaths "$native_segmentation_file" -thr 42 -uthr 42 -bin "$temp_mask_right_native"

# c. Add the left and right masks together to create a single whole-cortex mask in NATIVE space.
temp_mask_global_native="temp_global_cortex_native.nii.gz"
fslmaths "$temp_mask_left_native" -add "$temp_mask_right_native" -bin "$temp_mask_global_native"

# d. WARP the final native-space cortical mask to MNI space.
final_cortical_mask_mni="${subject}_cortical_mask_in_MNI.nii.gz"
applywarp --in="$temp_mask_global_native" \
          --ref="$mni_reference_brain" \
          --warp="$t1_to_mni_warp_file" \
          --out="$final_cortical_mask_mni" \
          --interp=nn

echo "Successfully created MNI-space cortical mask: $final_cortical_mask_mni"

# e. Clean up temporary native-space masks
rm "$temp_mask_left_native" "$temp_mask_right_native" "$temp_mask_global_native"


# --- 7. EXTRACT SUVR, CONVERT TO CENTILOID, AND SAVE TO CSV ---
# ---------------------------------------------------------------------------------
echo "--- Extracting SUVR and converting to Centiloid... ---"

# a. Calculate the mean SUVR value from the entire cortical mask
mean_suvr=$(fslstats "$mni_suvr_image" -k "$final_cortical_mask_mni" -M)

# b. Convert the SUVR to Centiloid using the formula and the 'bc' calculator
centiloid_value=$(echo "scale=4; 100 * ($mean_suvr - $CENTILOID_SUVR_ZERO) / ($CENTILOID_SUVR_100 - $CENTILOID_SUVR_ZERO)" | bc -l)

# c. Append the final SUVR and CENTILOID values to the CSV file
echo "$subject,$mean_suvr,$centiloid_value" >> "$output_csv"


echo ""
echo "--- SCRIPT COMPLETE ---"
echo "Results have been saved to: $output_csv"

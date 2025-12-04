#!/bin/bash
set -e

# =================================================================================
# SCRIPT TO CALCULATE GLOBAL CORTICAL SUVR & CENTILOID (v7 - User-Specified)
#
# This complete workflow will:
# 1. Change to the correct subject directory.
# 2. Load specified software versions (FSL 6.0.7.8, FreeSurfer 7.3.2).
# 3. Use Centiloid parameters for [11C]PiB tracer.
# 4. Use pre-existing Centiloid masks (Whole Cerebellum & Global Cortex).
# 5. Extract the mean cortical SUVR value from a pre-existing MNI-space PET image.
# 6. Convert the SUVR value to the Centiloid scale.
# 7. Save the subject ID, SUVR, and Centiloid values to a final CSV file.
# =================================================================================


# Check for Subject ID argument
if [ -z "$1" ]; then
    echo "Usage: $0 <subject_id>"
    echo "Example: $0 02"
    exit 1
fi

subject_id=$1
subject="sub-${subject_id}"

echo "Analyzing Subject: ${subject}"

# --- 1. NAVIGATE TO THE SUBJECT'S DIRECTORY ---
# ---------------------------------------------------------------------------------
echo "Changing directory to the subject's folder..."
cd ~/Desktop/CAPSTONE/capstonebids/${subject}/


# --- 2. LOAD REQUIRED SOFTWARE MODULES ---
# ---------------------------------------------------------------------------------
echo "Loading software modules..."
# Load FSL
if ! ml fsl/6.0.7.8 2>/dev/null; then
    echo "Specific fsl version not found, trying default..."
    ml fsl
fi

# Load FreeSurfer
if ! ml freesurfer/7.3.2 2>/dev/null; then
    echo "Specific freesurfer version not found, trying default..."
    ml freesurfer
fi


# --- 3. SETUP: PLEASE VERIFY THESE FILENAMES AND PATHS! ---
# ---------------------------------------------------------------------------------
# subject="sub-02" # Already set above

# === CRITICAL CENTILOID PARAMETERS for [11C]PiB ===
# Using the values you provided for PiB with a whole cerebellum reference.
CENTILOID_SUVR_ZERO=1.009
CENTILOID_SUVR_100=2.076
# ================================================

# Path to the Centiloid Masks
# Dynamically find the project root relative to this script
# Script location: .../PET-NeuroProject/scripts/protocol_specific/
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MASK_DIR="${PROJECT_ROOT}/Centiloid_Masks"

# Check if MASK_DIR exists
if [ ! -d "$MASK_DIR" ]; then
    echo "WARNING: Mask directory not found at expected relative path:"
    echo "$MASK_DIR"
    echo "Please ensure the 'Centiloid_Masks' folder is in the project root."
    exit 1
fi

# Centiloid Masks
ref_mask="${MASK_DIR}/voi_WhlCbl_1mm.nii"
target_mask="${MASK_DIR}/voi_ctx_1mm.nii"

# Input PET image (Smoothed MNI PET from preprocessing)
mni_pet_image="pet/${subject}_pet_to_MNI_smoothed.nii.gz"

# The final output CSV file
# If a second argument is provided, use that as the output file.
# Otherwise, default to the subject-specific file.
output_csv=${2:-"${subject}_global_cortical_results.csv"}


# --- 4. VERIFY INPUTS ---
# ---------------------------------------------------------------------------------
if [ ! -f "$mni_pet_image" ]; then
    echo "ERROR: Input PET image not found: $mni_pet_image"
    exit 1
fi

if [ ! -f "$ref_mask" ]; then
    echo "ERROR: Reference mask not found: $ref_mask"
    exit 1
fi

if [ ! -f "$target_mask" ]; then
    echo "ERROR: Target mask not found: $target_mask"
    exit 1
fi


# --- 5. CREATE CSV HEADER ---
# ---------------------------------------------------------------------------------
# Only create the file and header if it doesn't exist.
# This allows appending to an existing master file.
if [ ! -f "$output_csv" ]; then
    echo "Creating new CSV file: $output_csv"
    echo "subject_id,ref_region_mean,global_cortical_suvr,global_cortical_centiloid" > "$output_csv"
else
    echo "Appending to existing CSV file: $output_csv"
fi


# --- 6. CALCULATE SUVR AND CENTILOID ---
# ---------------------------------------------------------------------------------
echo "--- Calculating SUVR and converting to Centiloid... ---"

# a. Calculate the mean value in the Reference Region (Whole Cerebellum)
echo "Calculating mean uptake in Reference Region (Whole Cerebellum)..."
ref_mean=$(fslstats "$mni_pet_image" -k "$ref_mask" -M)
echo "Reference Mean: $ref_mean"

# b. Calculate the mean value in the Target Region (Global Cortex)
# Note: We calculate the mean uptake first, then divide by ref_mean to get SUVR.
# Alternatively, we can create an SUVR image first. Let's calculate mean uptake directly.
echo "Calculating mean uptake in Target Region (Global Cortex)..."
target_mean=$(fslstats "$mni_pet_image" -k "$target_mask" -M)
echo "Target Mean: $target_mean"

# c. Calculate SUVR
suvr=$(echo "scale=6; $target_mean / $ref_mean" | bc -l)
echo "Global Cortical SUVR: $suvr"

# d. Convert the SUVR to Centiloid using the formula
centiloid_value=$(echo "scale=4; 100 * ($suvr - $CENTILOID_SUVR_ZERO) / ($CENTILOID_SUVR_100 - $CENTILOID_SUVR_ZERO)" | bc -l)
echo "Centiloid Value: $centiloid_value"

# e. Append the final values to the CSV file
echo "$subject,$ref_mean,$suvr,$centiloid_value" >> "$output_csv"


echo ""
echo "--- SCRIPT COMPLETE ---"
echo "Results have been saved to: $output_csv"

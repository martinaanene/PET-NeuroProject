#!/bin/bash
# Preprocessing Script (FSL Modified - Standard PiB Method)
# Based on Centiloid Project Guidelines
# Modifications:
# 1. Frame Averaging: 50-70 min (PiB)
# 2. Reorientation: fslreorient2std
# 3. Normalization: FNIRT (FSL equivalent of Unified Segmentation)
# 4. Bounding Box: Adjusted to [-90 -126 -72; 91 91 109]

set -e

# Check for Subject ID argument
if [ -z "$1" ]; then
    echo "Usage: $0 <subject_id>"
    echo "Example: $0 02"
    exit 1
fi

subject_id=$1
subject="sub-${subject_id}"

echo "Preprocessing Subject: ${subject} (FSL Modified)"

# Load FSL module
if ! ml fsl/6.0.7.8 2>/dev/null; then
    echo "Specific fsl version not found, trying default..."
    ml fsl
fi

# --- Step 1: Frame Averaging (50-70 min) & Reorientation ---
cd ~/Desktop/CAPSTONE/capstonebids/${subject}/anat/
# Manual Reorientation equivalent in FSL
fslreorient2std ${subject}_T1w.nii.gz ${subject}_T1w_reoriented.nii.gz
mv ${subject}_T1w_reoriented.nii.gz ${subject}_T1w.nii.gz

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/pet/

# Path to the CSV file
FRAMING_CSV="$HOME/Desktop/PET-NeuroProject/framing_info.csv"

if [ ! -f "$FRAMING_CSV" ]; then
    echo "ERROR: Framing info CSV not found at $FRAMING_CSV"
    exit 1
fi

frame_info=$(grep "AD${subject_id}," "$FRAMING_CSV")
if [ -z "$frame_info" ]; then
    echo "ERROR: No framing info found for AD${subject_id}"
    exit 1
fi

# Extract range (50-70 min window)
range=$(echo "$frame_info" | cut -d',' -f3)
start_frame=$(echo "$range" | cut -d'-' -f1)
end_frame=$(echo "$range" | cut -d'-' -f2)

echo "Subject AD${subject_id}: Averaging frames $start_frame to $end_frame"

start_idx=$((start_frame - 1))
num_frames=$((end_frame - start_frame + 1))

fslroi ${subject}_pet.nii.gz ${subject}_pet_crop.nii.gz $start_idx $num_frames
fslmaths ${subject}_pet_crop.nii.gz -Tmean ${subject}_pet_avg.nii.gz

# Reorient averaged PET
fslreorient2std ${subject}_pet_avg.nii.gz ${subject}_pet_reoriented.nii.gz
mv ${subject}_pet_reoriented.nii.gz ${subject}_pet.nii.gz

rm ${subject}_pet_crop.nii.gz ${subject}_pet_avg.nii.gz

# --- Step 2: Coregistration (PET to MRI) ---
cd ~/Desktop/CAPSTONE/capstonebids/${subject}/anat/
bet ${subject}_T1w.nii.gz ${subject}_T1w_brain.nii.gz -R -f 0.2 -m

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/
# Robust Coregistration (NormMI, Full Search)
flirt -in pet/${subject}_pet.nii.gz \
      -ref anat/${subject}_T1w.nii.gz \
      -out pet/${subject}_pet_coreg.nii.gz \
      -omat pet/${subject}_pet_to_T1w.mat \
      -dof 6 \
      -cost normmi \
      -usesqform \
      -searchrx -180 180 -searchry -180 180 -searchrz -180 180

# Snapshot for verification
slicer anat/${subject}_T1w.nii.gz pet/${subject}_pet_coreg.nii.gz -a ${subject}_reg_check.png

# --- Step 3: Normalization (FNIRT) ---
# Linear Registration to MNI
flirt -in anat/${subject}_T1w_brain.nii.gz \
      -ref $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz \
      -omat anat/${subject}_T1w_to_MNI_linear.mat \
      -out anat/${subject}_T1w_to_MNI_linear.nii.gz

export OMP_NUM_THREADS=15

# Non-Linear Registration (FNIRT)
fnirt --in=anat/${subject}_T1w_brain.nii.gz \
      --ref=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz \
      --aff=anat/${subject}_T1w_to_MNI_linear.mat \
      --cout=anat/${subject}_T1w_to_MNI_warp.nii.gz \
      --warpres=10,10,10 \
      --subsamp=4,2,1,1 \
      --infwhm=8,4,2,2 \
      --verbose

# Apply Warp to PET
applywarp --in=pet/${subject}_pet.nii.gz \
          --ref=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz \
          --warp=anat/${subject}_T1w_to_MNI_warp.nii.gz \
          --premat=pet/${subject}_pet_to_T1w.mat \
          --out=pet/${subject}_pet_to_MNI_full.nii.gz

# --- Step 4: Bounding Box Adjustment ---
# The guidelines specify: [-90 -126 -72; 91 91 109]
# MNI 1mm coordinates are usually:
# X: -90 to 90 (181 voxels)
# Y: -126 to 90 (217 voxels)
# Z: -72 to 108 (181 voxels)
# FSL MNI152_T1_1mm is 182x218x182.
# We will crop/resample to match the Centiloid mask dimensions exactly (181x217x181)
# This mimics the "Bounding Box Adjustment" step.

# We use the Centiloid mask as the reference for the final geometry
MASK_DIR="$HOME/Desktop/PET-NeuroProject/Centiloid_Masks"
REF_MASK="${MASK_DIR}/voi_WhlCbl_1mm.nii"

if [ -f "$REF_MASK" ]; then
    echo "Adjusting Bounding Box to match Centiloid Mask..."
    flirt -in pet/${subject}_pet_to_MNI_full.nii.gz \
          -ref "$REF_MASK" \
          -applyxfm -usesqform \
          -out pet/${subject}_pet_to_MNI.nii.gz
else
    echo "WARNING: Centiloid mask not found. Using standard MNI output."
    cp pet/${subject}_pet_to_MNI_full.nii.gz pet/${subject}_pet_to_MNI.nii.gz
fi

# --- Step 5: Smoothing ---
fslmaths pet/${subject}_pet_to_MNI.nii.gz -s 3.4 pet/${subject}_pet_to_MNI_smoothed.nii.gz

echo "FSL Modified Preprocessing Complete."

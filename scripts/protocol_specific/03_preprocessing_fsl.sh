#!/bin/bash
# Preprocessing Script (Protocol-Specific Version)
# Co-registration, brain extraction, normalization, smoothing
set -e

# Check for Subject ID argument
if [ -z "$1" ]; then
    echo "Usage: $0 <subject_id>"
    echo "Example: $0 02"
    exit 1
fi

subject_id=$1
subject="sub-${subject_id}"

echo "Preprocessing Subject: ${subject}"

# Step 1: Frame Averaging and Visual Reorientation
# Load FSL module. Try specific version first, then default.
if ! ml fsl/6.0.7.8 2>/dev/null; then
    echo "Specific fsl version not found, trying default..."
    ml fsl
fi

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/anat/
fslreorient2std ${subject}_T1w.nii.gz ${subject}_T1w_reoriented.nii.gz
mv ${subject}_T1w_reoriented.nii.gz ${subject}_T1w.nii.gz

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/pet/

# --- NEW: Frame Averaging based on CSV ---
# Path to the CSV file (assumed to be in the project root)
FRAMING_CSV="$HOME/Desktop/PET-NeuroProject/framing_info.csv"

if [ ! -f "$FRAMING_CSV" ]; then
    echo "ERROR: Framing info CSV not found at $FRAMING_CSV"
    exit 1
fi

# Find the row for the current subject (e.g., AD01)
# CSV format: Subject,Total Frames,50-70 Frames
# Example: AD01,10,3-6
frame_info=$(grep "AD${subject_id}," "$FRAMING_CSV")

if [ -z "$frame_info" ]; then
    echo "ERROR: No framing info found for AD${subject_id} in $FRAMING_CSV"
    exit 1
fi

# Extract the range (3rd column)
range=$(echo "$frame_info" | cut -d',' -f3)
start_frame=$(echo "$range" | cut -d'-' -f1)
end_frame=$(echo "$range" | cut -d'-' -f2)

echo "Subject AD${subject_id}: Averaging frames $start_frame to $end_frame (from CSV)"

# Convert to 0-based indexing and calculate size
# Assuming CSV is 1-based (standard for humans)
start_idx=$((start_frame - 1))
num_frames=$((end_frame - start_frame + 1))

# Extract the frames
fslroi ${subject}_pet.nii.gz ${subject}_pet_crop.nii.gz $start_idx $num_frames

# Average the frames to create a static 3D image
fslmaths ${subject}_pet_crop.nii.gz -Tmean ${subject}_pet_avg.nii.gz

# Use the averaged image for reorientation and subsequent steps
fslreorient2std ${subject}_pet_avg.nii.gz ${subject}_pet_reoriented.nii.gz
mv ${subject}_pet_reoriented.nii.gz ${subject}_pet.nii.gz

# Clean up intermediate files
rm ${subject}_pet_crop.nii.gz ${subject}_pet_avg.nii.gz
# -----------------------------------------

# Step 2: Co-registration of PET and MRI
cd ~/Desktop/CAPSTONE/capstonebids/${subject}/anat/
bet ${subject}_T1w.nii.gz ${subject}_T1w_brain.nii.gz -R -f 0.2 -m
# fsleyes ${subject}_T1w.nii.gz ${subject}_T1w_brain.nii.gz -cm red &

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/
flirt -in pet/${subject}_pet.nii.gz \
      -ref anat/${subject}_T1w.nii.gz \
      -out pet/${subject}_pet_coreg.nii.gz \
      -omat pet/${subject}_pet_to_T1w.mat \
      -dof 6 \
      -cost normmi \
      -usesqform \
      -searchrx -180 180 -searchry -180 180 -searchrz -180 180

# Generate a PNG snapshot to verify registration
echo "Generating registration check snapshot..."
slicer anat/${subject}_T1w.nii.gz pet/${subject}_pet_coreg.nii.gz -a ${subject}_reg_check.png

# fsleyes anat/${subject}_T1w_brain.nii.gz pet/${subject}_pet_coreg.nii.gz -cm hot -a 50 &

# Step 3: Normalisation to MNI Space

flirt -in anat/${subject}_T1w_brain.nii.gz \
      -ref $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz \
      -omat anat/${subject}_T1w_to_MNI_linear.mat \
      -out anat/${subject}_T1w_to_MNI_linear.nii.gz

      export OMP_NUM_THREADS=15
      
fnirt --in=anat/${subject}_T1w_brain.nii.gz \
      --ref=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz \
      --aff=anat/${subject}_T1w_to_MNI_linear.mat \
      --cout=anat/${subject}_T1w_to_MNI_warp.nii.gz \
      --warpres=10,10,10 \
      --subsamp=4,2,1,1 \
      --infwhm=8,4,2,2 \
      --verbose

applywarp --in=pet/${subject}_pet.nii.gz \
          --ref=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz \
          --warp=anat/${subject}_T1w_to_MNI_warp.nii.gz \
          --premat=pet/${subject}_pet_to_T1w.mat \
          --out=pet/${subject}_pet_to_MNI.nii.gz

# Step 4: Smoothing
fslmaths pet/${subject}_pet_to_MNI.nii.gz -s 3.4 pet/${subject}_pet_to_MNI_smoothed.nii.gz



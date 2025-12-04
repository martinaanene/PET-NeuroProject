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

# Step 1: Visual Reorientation
# Load FSL module. Try specific version first, then default.
if ! ml fsl/6.0.7.8 2>/dev/null; then
    echo "Specific fsl version not found, trying default..."
    ml fsl
fi

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/anat/
fslreorient2std ${subject}_T1w.nii.gz ${subject}_T1w_reoriented.nii.gz
mv ${subject}_T1w_reoriented.nii.gz ${subject}_T1w.nii.gz

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/pet/
fslreorient2std ${subject}_pet.nii.gz ${subject}_pet_reoriented.nii.gz
mv ${subject}_pet_reoriented.nii.gz ${subject}_pet.nii.gz

# Step 2: Co-registration of PET and MRI
cd ~/Desktop/CAPSTONE/capstonebids/${subject}/anat/
bet ${subject}_T1w.nii.gz ${subject}_T1w_brain.nii.gz -R -f 0.2 -m
# fsleyes ${subject}_T1w.nii.gz ${subject}_T1w_brain.nii.gz -cm red &

cd ~/Desktop/CAPSTONE/capstonebids/${subject}/
flirt -in pet/${subject}_pet.nii.gz \
      -ref anat/${subject}_T1w_brain.nii.gz \
      -out pet/${subject}_pet_coreg.nii.gz \
      -omat pet/${subject}_pet_to_T1w.mat \
      -dof 6

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



#!/bin/bash
# Preprocessing Script (Generalized Version)
# Co-registration, brain extraction, normalization, smoothing

# Load FSL
ml fsl/6.0.7.8

# Define variables
PROJECT_DIR=~/Desktop/CAPSTONE
SUBJECT=sub-XX   # replace XX with subject ID
ANAT_DIR=${PROJECT_DIR}/${SUBJECT}/anat
PET_DIR=${PROJECT_DIR}/${SUBJECT}/pet
MNI_TEMPLATE_BRAIN=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz
MNI_TEMPLATE=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz

# -----------------------------
# Step 1: Visual Reorientation
# -----------------------------
cd $ANAT_DIR
fslreorient2std ${SUBJECT}_T1w.nii.gz

cd $PET_DIR
fslreorient2std ${SUBJECT}_pet.nii.gz

# -----------------------------
# Step 2: Co-registration (FLIRT)
# -----------------------------
cd $ANAT_DIR
bet ${SUBJECT}_T1w.nii.gz ${SUBJECT}_T1w_brain.nii.gz -R -f 0.2 -m
fsleyes ${SUBJECT}_T1w.nii.gz ${SUBJECT}_T1w_brain.nii.gz -cm red

cd ${PROJECT_DIR}/${SUBJECT}
flirt -in pet/${SUBJECT}_pet.nii.gz \
      -ref anat/${SUBJECT}_T1w_brain.nii.gz \
      -out pet/${SUBJECT}_pet_coreg.nii.gz \
      -omat pet/${SUBJECT}_pet_to_T1w.mat \
      -dof 6

fsleyes anat/${SUBJECT}_T1w_brain.nii.gz pet/${SUBJECT}_pet_coreg.nii.gz -cm hot -a 50

# -----------------------------
# Step 3: Normalization to MNI
# -----------------------------
flirt -in anat/${SUBJECT}_T1w_brain.nii.gz \
      -ref $MNI_TEMPLATE_BRAIN \
      -omat anat/${SUBJECT}_T1w_to_MNI_linear.mat \
      -out anat/${SUBJECT}_T1w_to_MNI_linear.nii.gz

fnirt --in=anat/${SUBJECT}_T1w.nii.gz \
      --ref=$MNI_TEMPLATE \
      --aff=anat/${SUBJECT}_T1w_to_MNI_linear.mat \
      --cout=anat/${SUBJECT}_T1w_to_MNI_warp.nii.gz \
      --warpres=10,10,10 \
      --subsamp=4,2,1,1 \
      --infwhm=8,4,2,2

applywarp --in=pet/${SUBJECT}_pet.nii.gz \
          --ref=$MNI_TEMPLATE_BRAIN \
          --warp=anat/${SUBJECT}_T1w_to_MNI_warp.nii.gz \
          --out=pet/${SUBJECT}_pet_MNI.nii.gz

# -----------------------------
# Step 4: Smoothing
# -----------------------------
fslmaths pet/${SUBJECT}_pet_MNI.nii.gz -s 3.4 pet/${SUBJECT}_pet_MNI_smoothed.nii.gz

# -----------------------------
# Step 5: SUVR Calculation
# -----------------------------
fslstats pet/${SUBJECT}_pet_MNI.nii.gz -k cerebellum_mask.nii.gz -M

#!/bin/bash
# Preprocessing Script (Protocol-Specific Version)

# Step 1: Visual Reorientation
ml fsl/6.0.7.8

cd ~/Desktop/CAPSTONE/sub-02/anat
fslreorient2std sub-02_T1w.nii.gz

cd ~/Desktop/CAPSTONE/sub-02/pet
fslreorient2std sub-02_pet.nii.gz

# Step 2: Co-registration of PET and MRI
cd ~/Desktop/CAPSTONE/sub-02/anat
bet sub-02_T1w.nii.gz sub-02_T1w_brain.nii.gz -R -f 0.2 -m
fsleyes sub-02_T1w.nii.gz sub-02_T1w_brain.nii.gz -cm red

cd ~/Desktop/CAPSTONE/sub-02
flirt -in pet/sub-02_pet.nii.gz \
      -ref anat/sub-02_T1w_brain.nii.gz \
      -out pet/sub-02_pet_coreg.nii.gz \
      -omat pet/sub-02_pet_to_T1w.mat \
      -dof 6

fsleyes anat/sub-02_T1w_brain.nii.gz pet/sub-02_pet_coreg.nii.gz -cm hot -a 50

# Step 3: Normalisation to MNI Space
MNI_TEMPLATE_BRAIN=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz

flirt -in anat/sub-02_T1w_brain.nii.gz \
      -ref $MNI_TEMPLATE_BRAIN \
      -omat anat/sub-02_T1w_to_MNI_linear.mat \
      -out anat/sub-02_T1w_to_MNI_linear.nii.gz

fnirt --in=anat/sub-02_T1w.nii.gz \
      --ref=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz \
      --aff=anat/sub-02_T1w_to_MNI_linear.mat \
      --cout=anat/sub-02_T1w_to_MNI_warp.nii.gz \
      --warpres=10,10,10 \
      --subsamp=4,2,1,1 \
      --infwhm=8,4,2,2

applywarp --in=pet/sub-02_pet.nii.gz \
          --ref=$MNI_TEMPLATE_BRAIN \
          --warp=anat/sub-02_T1w_to_MNI_warp.nii.gz \
          --out=pet/sub-02_pet_MNI.nii.gz

# Step 4: Smoothing
fslmaths pet/sub-064_ses-03_pet_in_MNI.nii.gz -s 3.4 pet/sub-064_ses-03_pet_in_MNI_smoothed.nii.gz

# Step 5: SUVR Calculation
fslstats sub-064_ses-03_pet_MNI.nii.gz -k cerebellum_mask.nii.gz -M

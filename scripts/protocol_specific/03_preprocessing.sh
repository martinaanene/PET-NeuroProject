#!/bin/bash
# Preprocessing Script (Protocol-Specific Version)
# Co-registration, brain extraction, normalization, smoothing

# Step 1: Visual Reorientation
ml fsl/6.0.7.8

cd ~/Desktop/CAPSTONE/capstonebids/sub-02/anat/
fslreorient2std sub-02_T1w.nii.gz

cd ~/Desktop/CAPSTONE/capstonebids/sub-02/pet/
fslreorient2std sub-02_pet.nii.gz

# Step 2: Co-registration of PET and MRI
cd ~/Desktop/CAPSTONE/capstonebids/sub-02/anat/
bet sub-02_T1w.nii.gz sub-02_T1w_brain.nii.gz -R -f 0.2 -m
fsleyes sub-02_T1w.nii.gz sub-02_T1w_brain.nii.gz -cm red

cd ~/Desktop/CAPSTONE/capstonebids/sub-02/
flirt -in pet/sub-02_pet.nii.gz \
      -ref anat/sub-02_T1w_brain.nii.gz \
      -out pet/sub-02_pet_coreg.nii.gz \
      -omat pet/sub-02_pet_to_T1w.mat \
      -dof 6

fsleyes anat/sub-02_T1w_brain.nii.gz pet/sub-02_pet_coreg.nii.gz -cm hot -a 50

# Step 3: Normalisation to MNI Space

flirt -in anat/sub-02_T1w_brain.nii.gz \
      -ref $FSLDIR/data/standard/MNI152_T1_1mm.nii.gz \
      -omat anat/sub-02_T1w_to_MNI_linear.mat \
      -out anat/sub-02_T1w_to_MNI_linear.nii.gz

      export OMP_NUM_THREADS=15
fnirt --in=anat/sub-02_T1w_brain.nii.gz \
      --ref=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz \
      --aff=anat/sub-02_T1w_to_MNI_linear.mat \
      --cout=anat/sub-02_T1w_to_MNI_warp.nii.gz \
      --warpres=10,10,10 \
      --subsamp=4,2,1,1 \
      --infwhm=8,4,2,2

applywarp --in=pet/sub-02_pet.nii.gz \
          --ref=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz \
          --warp=anat/sub-02_T1w_to_MNI_warp.nii.gz \
          --premat=pet/sub-02_pet_to_T1w.mat \
          --out=pet/sub-02_pet_to_MNI.nii.gz

# Step 4: Smoothing
fslmaths pet/sub-02_pet_to_MNI.nii.gz -s 3.4 pet/sub-02_pet_to_MNI_smoothed.nii.gz



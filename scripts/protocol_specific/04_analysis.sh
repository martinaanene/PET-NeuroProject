#!/bin/bash
# Analysis pipeline (protocol-specific: single subject sub-02)

# Step 1: Define Regions of Interest (ROI) with FreeSurfer
ml freesurfer/7.3.2
export SUBJECTS_DIR=$PWD/freesurfer_output

# Run full FreeSurfer reconstruction (structural MRI)
recon-all -s sub-02 -all -i sub-02_T1w.nii.gz

# Convert cortical parcellation to ROI mask
mri_aparc2aseg --s sub-02 --o sub-02_ROIs.nii.gz

# Step 2: Extract Mean Uptake / SUVr from PET Data
ml fsl/6.0.7.8
fslstats pet/sub-02_pet_in_MNI_smoothed.nii.gz -k sub-02_ROIs.nii.gz -M > sub-02_SUVR.txt

# Step 3: Create Participant-Level SUVR CSV
echo "Subject,ROI,SUVR" > participant_SUVR.csv
echo "sub-02,ROI1,$(cat sub-02_SUVR.txt)" >> participant_SUVR.csv

# Step 4: Convert SUVR to Centiloid values
ml R/4.3.2
Rscript -e "suvr <- read.csv('participant_SUVR.csv'); \
             suvr\$Centiloid <- (suvr\$SUVR * 100) / 1.5; \
             write.csv(suvr, 'participant_CL.csv', row.names=FALSE)"

# Step 5: Quality Check (visual)
fsleyes pet/sub-02_pet_in_MNI_smoothed.nii.gz sub-02_ROIs.nii.gz -cm red

# Step 6: Statistical Analysis (compare to published Centiloid values)
Rscript -e "data <- read.csv('participant_CL.csv'); \
             standard <- read.csv('published_centiloid.csv'); \
             model <- lm(data\$Centiloid ~ standard\$Centiloid); \
             summary(model)"

#!/bin/bash
# Analysis pipeline (protocol-specific version)

# Step 1: Define Regions of Interest (ROI) with FreeSurfer
# Assuming FreeSurfer has already been run (recon-all completed)
ml freesurfer/7.3.2
export SUBJECTS_DIR=$PWD/freesurfer_output

# Example ROI extraction for sub-02
asegstats2table --subjects sub-02 --meas volume --tablefile sub-02_ROI_volumes.csv

# Step 2: Extract Mean Uptake / SUVR from PET Data with FSLstats
ml fsl/6.0.7.8
fslstats pet/sub-02_pet_in_MNI_smoothed.nii.gz -k ROI_mask.nii.gz -M > sub-02_SUVR.txt

# Step 3: Create Participant-Level CSV
echo "Subject,ROI,SUVR" > participant_SUVR.csv
echo "sub-02,ROI1,$(cat sub-02_SUVR.txt)" >> participant_SUVR.csv

# Step 4: Convert SUVR to Centiloid (CL) values
# Example: linear scaling (y = ax + b). Replace a and b with your study calibration.
Rscript -e "suvr <- read.csv('participant_SUVR.csv'); \
             suvr\$Centiloid <- (suvr\$SUVR * 100) / 1.5; \
             write.csv(suvr, 'participant_CL.csv', row.names=FALSE)"

# Step 5: Quality Check - Verify ROI placement visually
fsleyes pet/sub-02_pet_in_MNI_smoothed.nii.gz ROI_mask.nii.gz -cm red

# Step 6: Statistical Analysis in R
ml R/4.3.2
Rscript -e "data <- read.csv('participant_CL.csv'); \
             standard <- read.csv('published_centiloid.csv'); \
             model <- lm(data\$Centiloid ~ standard\$Centiloid); \
             summary(model)"

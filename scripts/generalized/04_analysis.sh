#!/bin/bash
# Analysis pipeline (generalized version)
# ROI definition, SUVR extraction, Centiloid conversion, statistics

# Usage:
#   ./analysis.sh <SUBJECT_ID> <SESSION_ID>
# Example:
#   ./analysis.sh sub-02 ses-03

SUBJECT_ID=$1
SESSION_ID=$2

# Step 1: Define Regions of Interest (ROI) with FreeSurfer
ml freesurfer/7.3.2
export SUBJECTS_DIR=$PWD/freesurfer_output

asegstats2table --subjects ${SUBJECT_ID} --meas volume --tablefile ${SUBJECT_ID}_ROI_volumes.csv

# Step 2: Extract Mean Uptake / SUVR from PET Data
ml fsl/6.0.7.8
fslstats pet/${SUBJECT_ID}_${SESSION_ID}_pet_in_MNI_smoothed.nii.gz \
    -k ROI_mask.nii.gz -M > ${SUBJECT_ID}_${SESSION_ID}_SUVR.txt

# Step 3: Create Participant-Level CSV
echo "Subject,ROI,SUVR" > ${SUBJECT_ID}_${SESSION_ID}_SUVR.csv
echo "${SUBJECT_ID},ROI1,$(cat ${SUBJECT_ID}_${SESSION_ID}_SUVR.txt)" >> ${SUBJECT_ID}_${SESSION_ID}_SUVR.csv

# Step 4: Convert SUVR to Centiloid (CL) values
Rscript -e "suvr <- read.csv('${SUBJECT_ID}_${SESSION_ID}_SUVR.csv'); \
             suvr\$Centiloid <- (suvr\$SUVR * 100) / 1.5; \
             write.csv(suvr, '${SUBJECT_ID}_${SESSION_ID}_CL.csv', row.names=FALSE)"

# Step 5: Quality Check - Verify ROI placement visually
fsleyes pet/${SUBJECT_ID}_${SESSION_ID}_pet_in_MNI_smoothed.nii.gz ROI_mask.nii.gz -cm red

# Step 6: Statistical Analysis (Linear Correlation with published Centiloid values)
ml R/4.3.2
Rscript -e "data <- read.csv('${SUBJECT_ID}_${SESSION_ID}_CL.csv'); \
             standard <- read.csv('published_centiloid.csv'); \
             model <- lm(data\$Centiloid ~ standard\$Centiloid); \
             summary(model)"

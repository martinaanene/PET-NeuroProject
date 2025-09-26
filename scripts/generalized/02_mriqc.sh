#!/bin/bash
# MRIQC pipeline (generalized version)

# Step 1: Visual Inspection of Structural and Functional Images
# Load FSL for viewing images
ml fsl/6.0.7.8

# Navigate to the anatomical or PET folder
# Example: replace $SUBJECT_ID with the subject identifier
cd ~/Desktop/CAPSTONE/capstonebids/sub-$SUBJECT_ID/anat

# Open the anatomical image in FSLeyes
fsleyes sub-$SUBJECT_ID_T1w.nii.gz

# Repeat for PET or functional images if needed
# fsleyes sub-$SUBJECT_ID_pet.nii.gz

# Step 2: Generate Automated QC Metrics with MRIQC
ml mriqc/v24.0.2

# Set paths
export BIDSDIR=~/Desktop/CAPSTONE/capstonebids/
mkdir -p ~/Desktop/derivatives/
export MRIQCDIR=~/Desktop/derivatives/

# Run participant-level QC
mriqc $BIDSDIR $MRIQCDIR participant

# Step 3: View MRIQC Results
cd $MRIQCDIR
# Open HTML report (replace $SUBJECT_ID with subject)
open sub-$SUBJECT_ID_T1w.html

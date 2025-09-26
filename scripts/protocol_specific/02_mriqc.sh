#!/bin/bash
# MRIQC pipeline (protocol-specific version)

# Step 1: Visual Inspection of Structural Images
ml fsl/6.0.7.8

# Navigate to anatomical folder
cd ~/Desktop/CAPSTONE/capstonebids/sub-02/anat

# Open the T1w MRI image in FSLeyes
fsleyes sub-02_T1w.nii.gz

# Optional: Open PET image for visual inspection
cd ~/Desktop/CAPSTONE/capstonebids/sub-02/pet
fsleyes sub-02_pet.nii.gz

# Step 2: Generate Automated QC Metrics with MRIQC
ml mriqc/v1.0.20240202

# Set paths
export BIDSDIR=~/Desktop/CAPSTONE/capstonebids/
mkdir -p ~/Desktop/derivatives/
export MRIQCDIR=~/Desktop/derivatives/

# Run participant-level QC
mriqc $BIDSDIR $MRIQCDIR participant

# Step 3: View MRIQC Results
cd $MRIQCDIR
open sub-02_T1w.html

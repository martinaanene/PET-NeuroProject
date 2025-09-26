#!/bin/bash
# Data Structure Script (Protocol-As-Is Version)
# This script prepares PET and MRI data, converts DICOM to NIfTI, structures the data in BIDS format, and validates.

# Step 1: Create CAPSTONE project directory
cd ~/Desktop/
mkdir CAPSTONE

# Step 2: Move raw data zip files from Downloads to CAPSTONE
cd ~/Downloads/
mv AD02-20250925T163237Z-1-001.zip AD02_MR_DICOM-20250925T163714Z-1-001.zip ~/Desktop/CAPSTONE/

# Step 3: Unzip and remove raw zip files
cd ~/Desktop/CAPSTONE/
unzip AD02_MR_DICOM-20250925T163714Z-1-001.zip
unzip AD02-20250925T163237Z-1-001.zip
rm AD02_MR_DICOM-20250925T163714Z-1-001.zip AD02-20250925T163237Z-1-001.zip

# Step 4: Create BIDS directories
mkdir -p capstonebids/sub-02/anat capstonebids/sub-02/pet

# Step 5: Convert raw MRI data to NIFTI (dcm2niix)
ml dcm2niix/v1.0.20240202
dcm2niix -o $PWD -z y -ba y -v y AD02_MR_DICOM

# Step 6: Move & rename NIFTI + JSON into BIDS folders
mv <MRI_FILE>.nii.gz capstonebids/sub-02/anat/sub-02_T1w.nii.gz
mv <MRI_FILE>.json capstonebids/sub-02/anat/sub-02_T1w.json
mv <PET_FILE>.nii.gz capstonebids/sub-02/pet/sub-02_pet.nii.gz
mv <PET_FILE>.json capstonebids/sub-02/pet/sub-02_pet.json

# Step 7: Create dataset_description.json
cd capstonebids/
echo '{ "Name": "capstone_dataset", "BIDSVersion": "1.8.0" }' > dataset_description.json

# Step 8: View structure
tree

# Step 9: Validate BIDS
conda install conda-forge::deno -y
conda activate
deno run -ERWN jsr:@bids/validator capstonebids/ --ignoreWarnings

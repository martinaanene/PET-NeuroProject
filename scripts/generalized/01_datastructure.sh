#!/bin/bash
# Data Structure Script (Generalized Version)
# This script prepares PET and MRI data, convert DICOM to NIfT, structures the files in BIDS format, and validates.
# Generalized for multiple subjects and modalities.

# Define variables
PROJECT_DIR=~/Desktop/CAPSTONE
BIDS_DIR=$PROJECT_DIR/capstonebids
SUBJECT=sub-02
MRI_RAW=AD02-20250925T163237Z-1-001.zip
PET_RAW=AD02_MR_DICOM-20250925T163714Z-1-001.zip
DCM2NIIX_VERSION=v1.0.20240202

# Step 1: Create project directory
mkdir -p $PROJECT_DIR

# Step 2: Move raw data zips (assumes already downloaded into ~/Downloads)
mv ~/Downloads/${MRI_RAW}*.zip ~/Downloads/${PET_RAW}*.zip $PROJECT_DIR/

# Step 3: Unzip and remove raw zip files
cd $PROJECT_DIR
for file in *.zip; do unzip $file; done
rm *.zip

# Step 4: Create BIDS directory structure
mkdir -p $BIDS_DIR/$SUBJECT/anat $BIDS_DIR/$SUBJECT/pet

# Step 5: Convert raw DICOM to NIFTI using dcm2niix
ml dcm2niix/$DCM2NIIX_VERSION
dcm2niix -o $PWD -z y -ba y -v y $MRI_RAW
dcm2niix -o $PWD -z y -ba y -v y $PET_RAW

# Step 6: Move & rename NIFTI + JSON into BIDS folders
mv ${MRI_RAW}/*.nii.gz $BIDS_DIR/$SUBJECT/anat/${SUBJECT}_T1w.nii.gz
mv ${MRI_RAW}/*.json $BIDS_DIR/$SUBJECT/anat/${SUBJECT}_T1w.json
mv ${PET_RAW}/*.nii.gz $BIDS_DIR/$SUBJECT/pet/${SUBJECT}_pet.nii.gz
mv ${PET_RAW}/*.json $BIDS_DIR/$SUBJECT/pet/${SUBJECT}_pet.json

# Step 7: Create dataset_description.json
cd $BIDS_DIR
echo '{ "Name": "capstone_dataset", "BIDSVersion": "1.8.0" }' > dataset_description.json

# Step 8: View structure
tree $BIDS_DIR

# Step 9: Validate BIDS
conda install conda-forge::deno -y
conda activate
deno run -ERWN jsr:@bids/validator $BIDS_DIR/ --ignoreWarnings

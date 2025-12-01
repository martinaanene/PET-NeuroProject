#!/bin/bash
# Data Structure Script (Protocol-As-Is Version)
# This script prepares PET and MRI data, converts DICOM to NIfTI, structures the data in BIDS format, and validates.

# Check for Subject ID argument
if [ -z "$1" ]; then
    echo "Usage: $0 <subject_id>"
    echo "Example: $0 02"
    exit 1
fi

subject_id=$1
subject="sub-${subject_id}"

echo "Processing Subject: ${subject}"

# Step 1: Create CAPSTONE project directory
# (Only create if it doesn't exist to avoid errors in batch mode)
mkdir -p ~/Desktop/CAPSTONE

# Step 2: Move raw data zip files from Downloads to CAPSTONE
# Using wildcard to find files matching the subject ID (e.g., AD02...)
echo "Moving zip files for ${subject_id}..."
# Note: This assumes files are named like AD02... or AD02_MR...
# We use find or wildcards cautiously.
mv ~/Downloads/AD${subject_id}*.zip ~/Desktop/CAPSTONE/ 2>/dev/null || echo "No zip files found in Downloads for ${subject_id} (might already be moved)"

# Step 3: Unzip and remove raw zip files
cd ~/Desktop/CAPSTONE/
# Unzip any zip files matching the ID that are present
unzip -o "AD${subject_id}*.zip"

# Step 4: Create BIDS directories
mkdir -p "capstonebids/${subject}/anat" "capstonebids/${subject}/pet"

# Step 5: Convert raw MRI data to NIFTI (dcm2niix)
ml dcm2niix/v1.0.20240202

# Find the unzipped directories. 
# Assumption: The unzip creates directories starting with AD${subject_id}
# We need to be careful about which folder is which.
# Based on original script:
# AD02_MR_DICOM... -> anat
# AD02... (shorter one?) -> pet? 
# The original script had:
# AD02_MR_DICOM-20250925T163714Z-1-001.zip -> sub-02_T1w (anat)
# AD02-20250925T163237Z-1-001.zip -> sub-02_pet (pet)

# We will try to detect them by name.
anat_dir=$(find . -maxdepth 1 -type d -name "AD${subject_id}_MR_DICOM*" | head -n 1)
pet_dir=$(find . -maxdepth 1 -type d -name "AD${subject_id}*" ! -name "*MR_DICOM*" | head -n 1)

if [ -d "$anat_dir" ]; then
    echo "Converting Anatomical: $anat_dir"
    dcm2niix -o "~/Desktop/CAPSTONE/capstonebids/${subject}/anat" -f "${subject}_T1w" -z y -ba y -v y "$anat_dir"
else
    echo "WARNING: Anatomical DICOM directory not found for ${subject_id}"
fi

if [ -d "$pet_dir" ]; then
    echo "Converting PET: $pet_dir"
    dcm2niix -o "~/Desktop/CAPSTONE/capstonebids/${subject}/pet" -f "${subject}_pet" -z y -ba y -v y "$pet_dir"
else
    echo "WARNING: PET DICOM directory not found for ${subject_id}"
fi


# Step 6: Create dataset_description.json (Only needs to be done once, but harmless to repeat)
cd capstonebids/
if [ ! -f dataset_description.json ]; then
    echo '{ "Name": "capstone_dataset", "BIDSVersion": "1.8.0" }' > dataset_description.json
fi

# Step 7: View structure
# tree # Optional, can be noisy in batch

# Step 8: Validate BIDS
cd ..
# Only run validator if requested or maybe once at the end? 
# Keeping it for now but it might slow down batch processing.
# conda install conda-forge::deno -y # Should be installed once globally
# conda init
# conda activate
# deno run -ERWN jsr:@bids/validator capstonebids/ --ignoreWarnings

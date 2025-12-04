#!/bin/bash
# Data Structure Script (Protocol-As-Is Version)
# This script prepares PET and MRI data, converts DICOM to NIfTI, structures the data in BIDS format, and validates.
set -e

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

# Step 2: Extract data from bulk zip files
# We look for the specific subject's data within the bulk archives in Downloads.
# Using -n to skip if files already exist (idempotent).
# We assume the bulk zips are in ~/Downloads.
MRI_ZIP="$HOME/Downloads/AD-100_MR.zip"
PET_ZIP="$HOME/Downloads/AD_PET_01-25.zip"

echo "Extracting data for ${subject_id} from bulk archives..."

# Extract MRI data
if [ -f "$MRI_ZIP" ]; then
    echo "DEBUG: Listing first 20 files in MRI zip to check structure:"
    unzip -l "$MRI_ZIP" | head -n 20
    
    unzip -n "$MRI_ZIP" "*AD${subject_id}*" -d ~/Desktop/CAPSTONE/
else
    echo "WARNING: MRI bulk zip not found at $MRI_ZIP"
fi

# Extract PET data
if [ -f "$PET_ZIP" ]; then
    unzip -n "$PET_ZIP" "*AD${subject_id}*" -d ~/Desktop/CAPSTONE/
else
    echo "WARNING: PET bulk zip not found at $PET_ZIP"
fi

# Step 3: Prepare for processing
cd ~/Desktop/CAPSTONE/

# Step 4: Create BIDS directories
mkdir -p "capstonebids/${subject}/anat" "capstonebids/${subject}/pet"

# Step 5: Convert raw MRI data to NIFTI (dcm2niix)
# Load dcm2niix module. Try specific version first, then default.
if ! ml dcm2niix/v1.0.20240202 2>/dev/null; then
    echo "Specific dcm2niix version not found, trying default..."
    ml dcm2niix
fi

# Debugging: List what was extracted
echo "Contents of ~/Desktop/CAPSTONE after extraction:"
ls -F ~/Desktop/CAPSTONE/

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
# Increased maxdepth to 2 in case the bulk zip extracts into a parent folder.
anat_dir=$(find . -maxdepth 2 -type d -name "AD${subject_id}_MR_DICOM*" | head -n 1)
pet_dir=$(find . -maxdepth 2 -type d -name "AD${subject_id}*" ! -name "*MR_DICOM*" | head -n 1)

if [ -d "$anat_dir" ]; then
    echo "Converting Anatomical: $anat_dir"
    dcm2niix -o "~/Desktop/CAPSTONE/capstonebids/${subject}/anat" -f "${subject}_T1w" -z y -ba y -v y "$anat_dir"
else
    echo "ERROR: Anatomical DICOM directory not found for ${subject_id}"
    echo "Expected pattern: AD${subject_id}_MR_DICOM*"
    exit 1
fi

if [ -d "$pet_dir" ]; then
    echo "Converting PET: $pet_dir"
    dcm2niix -o "~/Desktop/CAPSTONE/capstonebids/${subject}/pet" -f "${subject}_pet" -z y -ba y -v y "$pet_dir"
else
    echo "ERROR: PET DICOM directory not found for ${subject_id}"
    echo "Expected pattern: AD${subject_id}* (excluding MR_DICOM)"
    exit 1
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

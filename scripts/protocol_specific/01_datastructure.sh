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

# Function to extract zip with fallback to Python
extract_zip() {
    local zip_file=$1
    local pattern=$2
    local output_dir=$3
    local subject_str=$4

    echo "Attempting to extract $zip_file with unzip..."
    # Try standard unzip first
    if unzip -n "$zip_file" "$pattern" -d "$output_dir"; then
        echo "Unzip successful."
        return 0
    else
        echo "WARNING: Standard unzip failed (possible zip bomb or format issue)."
        echo "Attempting extraction with Python..."
        
        # Python fallback
        # We filter files containing the subject string (e.g., "AD01")
        python3 -c "
import zipfile, sys, os
zip_path = sys.argv[1]
out_dir = sys.argv[2]
subj_str = sys.argv[3]

try:
    with zipfile.ZipFile(zip_path, 'r') as z:
        # Filter files matching the subject string
        members = [m for m in z.namelist() if subj_str in m]
        if not members:
            print(f'No files found matching {subj_str}')
            sys.exit(1)
        
        print(f'Found {len(members)} files for {subj_str}. Extracting...')
        for m in members:
            z.extract(m, out_dir)
    print('Python extraction successful.')
except Exception as e:
    print(f'Python extraction failed: {e}')
    sys.exit(1)
" "$zip_file" "$output_dir" "$subject_str"
        
        return $?
    fi
}

echo "Extracting data for ${subject_id} from bulk archives..."
echo "DEBUG: Checking Downloads folder content:"
ls -F ~/Downloads/
echo "DEBUG: Looking for MRI_ZIP at: $MRI_ZIP"

# Extract MRI data
if [ -f "$MRI_ZIP" ]; then
    # Use the new extraction function
    # Pattern for unzip: *AD${subject_id}*
    # String for Python: AD${subject_id}
    extract_zip "$MRI_ZIP" "*AD${subject_id}*" ~/Desktop/CAPSTONE/ "AD${subject_id}"
else
    echo "WARNING: MRI bulk zip not found at $MRI_ZIP"
fi

# Extract PET data
if [ -f "$PET_ZIP" ]; then
    extract_zip "$PET_ZIP" "*AD${subject_id}*" ~/Desktop/CAPSTONE/ "AD${subject_id}"
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
# Increased maxdepth to 5 because the zip structure is AD-100_MR/dicom/AD01... (3 levels deep)
anat_dir=$(find . -maxdepth 5 -type d -name "AD${subject_id}_MR_DICOM*" | head -n 1)
pet_dir=$(find . -maxdepth 5 -type d -name "AD${subject_id}*" ! -name "*MR_DICOM*" | head -n 1)

if [ -d "$anat_dir" ]; then
    echo "Converting Anatomical: $anat_dir"
    dcm2niix -o "$HOME/Desktop/CAPSTONE/capstonebids/${subject}/anat" -f "${subject}_T1w" -z y -ba y -v y "$anat_dir"
else
    echo "ERROR: Anatomical DICOM directory not found for ${subject_id}"
    echo "Expected pattern: AD${subject_id}_MR_DICOM*"
    exit 1
fi

if [ -d "$pet_dir" ]; then
    echo "Converting PET: $pet_dir"
    dcm2niix -o "$HOME/Desktop/CAPSTONE/capstonebids/${subject}/pet" -f "${subject}_pet" -z y -ba y -v y "$pet_dir"
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

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

# Function to extract zip (Standard unzip only)
extract_zip() {
    local zip_file=$1
    local pattern=$2
    local output_dir=$3

    echo "Attempting to extract $zip_file..."
    if unzip -n "$zip_file" "$pattern" -d "$output_dir"; then
        echo "Unzip successful."
        return 0
    else
        echo "ERROR: Unzip failed for $zip_file"
        return 1
    fi
}

echo "Extracting data for ${subject_id} from bulk archives..."

# Extract MRI data
if [ -f "$MRI_ZIP" ]; then
    extract_zip "$MRI_ZIP" "*AD${subject_id}*" ~/Desktop/CAPSTONE/
else
    echo "WARNING: MRI bulk zip not found at $MRI_ZIP"
fi

# Extract PET data
if [ -f "$PET_ZIP" ]; then
    extract_zip "$PET_ZIP" "*AD${subject_id}*" ~/Desktop/CAPSTONE/
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

# Load FSL for merging split PET series
if ! ml fsl/6.0.7.8 2>/dev/null; then
    echo "Specific FSL version not found, trying default..."
    ml fsl
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
# Prioritize finding directories ending in _PET_DICOM (seen in Sub-04/05)
pet_dir=$(find . -maxdepth 5 -type d -name "AD${subject_id}*_PET_DICOM" | head -n 1)

# Fallback if strict pattern not found
if [ -z "$pet_dir" ]; then
    pet_dir=$(find . -maxdepth 5 -type d -name "AD${subject_id}*" ! -name "*MR_DICOM*" | head -n 1)
fi

anat_dir=$(find . -maxdepth 5 -type d -name "AD${subject_id}_MR_DICOM*" | head -n 1)

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
    # Convert all series in the directory (handled automatically by dcm2niix if pointing to parent)
    dcm2niix -o "$HOME/Desktop/CAPSTONE/capstonebids/${subject}/pet" -f "${subject}_pet" -z y -ba y -v y "$pet_dir"
    
    # Check for split files (e.g., if multiple folders existed) and merge them
    cd "$HOME/Desktop/CAPSTONE/capstonebids/${subject}/pet"
    
    # Store current IFS
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    
    # List generated PET files (excluding .json)
    # This relies on dcm2niix naming behavior. If multiple series, it appends suffixes.
    files=($(ls ${subject}_pet*.nii.gz 2>/dev/null | sort))
    
    num_files=${#files[@]}
    echo "Found $num_files PET NIfTI files."
    
    if [ "$num_files" -gt 1 ]; then
        echo "Detected split PET series ($num_files files). Merging..."
        # fslmerge -t concatenates in time
        fslmerge -t "${subject}_pet_merged.nii.gz" "${files[@]}"
        
        # Verify merge success
        if [ -f "${subject}_pet_merged.nii.gz" ]; then
            echo "Merge successful. replacing original files."
            # Remove partial files
            rm "${files[@]}"
            # Rename merged file to standard name
            mv "${subject}_pet_merged.nii.gz" "${subject}_pet.nii.gz"
            # Also need to handle JSONs? 
            # Usually strict BIDS requires One JSON. We'll just keep the first one or leave as is.
            # Ideally we merge JSONs but for this pipeline only the NIfTI matters for fslroi.
            
            # Clean up extra JSONs if they exist (keep the main one)
            # This is a simplification.
             rm ${subject}_pet_*.json 2>/dev/null || true
        else
            echo "ERROR: fslmerge failed."
            exit 1
        fi
    fi
    
    # Restore IFS
    IFS=$SAVEIFS
    
    # Go back to dataset root
    cd ~/Desktop/CAPSTONE/
else
    echo "ERROR: PET DICOM directory not found for ${subject_id}"
    echo "Expected pattern: AD${subject_id}* (excluding MR_DICOM)"
    exit 1
fi


# Step 6: Create dataset_description.json (Only needs to be done once, but harmless to repeat)
cd capstonebids/
if [ ! -f dataset_description.json ]; then
    # BIDS Version is a declaration of which standard we are complying with.
    # We are structuring this manually, so we declare the version we support.
    BIDS_VERSION="1.9.0"
    echo "{ \"Name\": \"capstone_dataset\", \"BIDSVersion\": \"$BIDS_VERSION\" }" > dataset_description.json
fi

# Step 7: View structure
# tree # Optional, can be noisy in batch

# Step 8: Validate BIDS using Deno
cd ..
if ! command -v deno &> /dev/null; then
    echo "Deno not found. Installing via Conda..."
    # Attempt to install Deno via conda if available in the environment
    if command -v conda &> /dev/null; then
        conda install -y conda-forge::deno
    else
        echo "ERROR: Conda not found. Cannot auto-install Deno."
    fi
fi

if command -v deno &> /dev/null; then
    echo "Running BIDS Validator..."
    # Run validator and capture output to a log file
    # Run validator and capture output to a log file
    if ! deno run -A jsr:@bids/validator capstonebids/ --ignoreWarnings > "bids_validation_report_sub-${subject_id}.txt" 2>&1; then
        echo "ERROR: BIDS Validator failed! Output from bids_validation_report_sub-${subject_id}.txt:"
        echo "---------------------------------------------------"
        cat "bids_validation_report_sub-${subject_id}.txt"
        echo "---------------------------------------------------"
        exit 1
    fi
    
    # Check if validation passed (exit code might be 0 even with warnings, so we just log it)
    echo "BIDS Validation complete. See bids_validation_report_sub-${subject_id}.txt"
    cat "bids_validation_report_sub-${subject_id}.txt"
else
    echo "WARNING: Deno still not found. Skipping BIDS validation."
fi


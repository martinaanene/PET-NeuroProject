#!/bin/bash
# MRIQC pipeline (protocol-specific version)
set -e

# Check for Subject ID argument
if [ -z "$1" ]; then
    echo "Usage: $0 <subject_id> OR $0 group"
    echo "Example: $0 02"
    echo "Example: $0 group"
    exit 1
fi

mode=$1

# Set paths
export BIDSDIR=~/Desktop/CAPSTONE/capstonebids/
# Move output completely outside of CAPSTONE to avoid any nesting detection errors
mkdir -p ~/Desktop/MRIQC_OUTPUT
mkdir -p ~/Desktop/MRIQC_WORK
export MRIQCDIR=~/Desktop/MRIQC_OUTPUT
export WORKDIR=~/Desktop/MRIQC_WORK
# Load MRIQC module. Try specific version first, then default.
if ! ml mriqc/24.0.2 2>/dev/null; then
    echo "Specific mriqc version not found, trying default..."
    ml mriqc
fi

if [ "$mode" == "group" ]; then
    echo "Running MRIQC Group Analysis..."
    # Run group-level QC
    mriqc $BIDSDIR $MRIQCDIR group -w $WORKDIR
    echo "Group analysis complete. Check $MRIQCDIR for group reports."
    exit 0
fi

# Participant Mode
subject_id=$mode
subject="sub-${subject_id}"

echo "Running MRIQC for Subject: ${subject}"

# Step 1: Visual Inspection of Structural Images
ml fsl/6.0.7.8

# Navigate to anatomical folder
cd ~/Desktop/CAPSTONE/capstonebids/${subject}/anat

# Open the T1w MRI image in FSLeyes
# fsleyes ${subject}_T1w.nii.gz & # Run in background or skip for batch

# Optional: Open PET image for visual inspection
# cd ~/Desktop/CAPSTONE/capstonebids/${subject}/pet
# fsleyes ${subject}_pet.nii.gz &

# Step 2: Generate Automated QC Metrics with MRIQC
# (Module loaded above)

# Run participant-level QC
# Note: MRIQC might need the full subject list or can run on one participant
# If running on one participant:
mriqc $BIDSDIR $MRIQCDIR participant --participant-label $subject_id -w $WORKDIR

# Step 3: View MRIQC Results
# cd $MRIQCDIR
# open ${subject}_T1w.html

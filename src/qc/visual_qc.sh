#!/bin/bash
# Visual QC Snapshot Generator
# Generates PNG snapshots for Coregistration, Normalization, and Mask Alignment

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <subject_id>"
    exit 1
fi

subject_id=$1
subject="sub-${subject_id}"

echo "Generatng Visual QC for Subject: ${subject}"

# Define Paths
BASE_DIR=~/Desktop/derivatives
SUB_DIR="${BASE_DIR}/data/${subject}"
ANAT_DIR="${SUB_DIR}/anat"
PET_DIR="${SUB_DIR}/pet"
QC_DIR="${BASE_DIR}/QC/${subject}"

# Create QC output directory
mkdir -p "$QC_DIR"

# Load FSL (if not already loaded)
if ! command -v fsleyes &> /dev/null; then
    if ! ml fsl/6.0.7.8 2>/dev/null; then
        ml fsl
    fi
fi

# Define Image Paths
T1="${ANAT_DIR}/${subject}_T1w_spm.nii"          # Reoriented MRI
PET_MNI="${PET_DIR}/${subject}_pet_to_MNI_smoothed.nii.gz" # Final MNI PET
AVG_PET="${PET_DIR}/${subject}_pet_avg.nii"      # Averaged Raw PET (before MNI)

# Standard MNI Template (FSL standard)
MNI_TEMPLATE="${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz"

# Project Masks (Relative to script location for robustness)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MASK_DIR="${PROJECT_ROOT}/data/references/centiloid_masks"
MASK_CEREB="${MASK_DIR}/voi_WhlCbl_2mm.nii"
MASK_CTX="${MASK_DIR}/voi_ctx_2mm.nii"

# Check dependencies
if [ ! -f "$T1" ] || [ ! -f "$PET_MNI" ]; then
    echo "ERROR: Missing required input files for QC."
    echo "Expected: $T1 and $PET_MNI"
    exit 1
fi

# NOTE: fsleyes render syntax:
# fsleyes render -of <output_file> [display_opts] file1 [display_opts] file2 ...

# 1. COREGISTRATION CHECK
# Overlay PET (Avg, Native) onto MRI (Native)
# Note: In SPM workflow, MRI is the reference.
# We want to see if PET aligns with MRI.
echo "Snapshot 1/3: Coregistration..."
# Use slicing to show 3 orthogonal views
# Auto-contrast usually works, but we can set display range.
# PET usually needs a 'hot' colormap.
fsleyes render --outfile "${QC_DIR}/qc_coreg.png" \
    --size 1200 400 \
    --scene ortho \
    "$T1" --overlayType volume --name "T1" \
    "$AVG_PET" --overlayType volume --name "PET" --cmap hot --alpha 50

# 2. NORMALIZATION CHECK
# Overlay MNI PET onto MNI Template
echo "Snapshot 2/3: Normalization..."
fsleyes render --outfile "${QC_DIR}/qc_norm.png" \
    --size 1200 400 \
    --scene ortho \
    "$MNI_TEMPLATE" --overlayType volume --name "MNI152" \
    "$PET_MNI" --overlayType volume --name "PET_MNI" --cmap hot --alpha 50

# 3. MASK ALIGNMENT CHECK
# Overlay Cerebellum and Cortex Masks onto MNI PET
echo "Snapshot 3/3: Mask Alignment..."
# We render the PET as background, and masks as colored overlays
fsleyes render --outfile "${QC_DIR}/qc_masks.png" \
    --size 1200 400 \
    --scene ortho \
    "$PET_MNI" --overlayType volume --name "PET_MNI" --cmap gray \
    "$MASK_CEREB" --overlayType volume --name "Cerebellum" --cmap Blue --alpha 40 \
    "$MASK_CTX" --overlayType volume --name "Cortex" --cmap Red --alpha 40

echo "Visual QC Complete for $subject. Images saved to $QC_DIR"

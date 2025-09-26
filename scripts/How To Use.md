# PET Neuroimaging Pipeline

This repository contains scripts for data structuring, quality control, preprocessing, and analysis of PET-MRI neuroimaging data following the BIDS format.  
Scripts are provided in two versions:
- **protocol_specific/**: Scripts written exactly as used in our project with subject-specific details.
- **generalized/**: Scripts written with generalized variables for reuse across datasets.

## Scripts
- `01_datastructure.sh` → DICOM to NIfTI, BIDS formatting 
- `02_mriqc.sh` → Run MRIQC
- `03_preprocessing.sh` → PET-MRI preprocessing
- `04_analysis.sh` → ROI, SUVR, Centiloid, statistics

---

## Folder Structure
PET-NeuroProject/scripts/
│
├── generalized/
│   ├── 01_datastructure.sh
│   ├── 02_mriqc.sh
│   ├── 03_preprocessing.sh
│   └── 04_analysis.sh
│
├── protocol_specific/
│   ├── 01_datastructure.sh
│   ├── 02_mriqc.sh
│   ├── 03_preprocessing.sh
│   └── 04_analysis.sh

---

## Workflow Overview

### 1. Data Structure
- Converts raw DICOM to NIfTI using **dcm2niix**.  
- Organizes data in **BIDS** format.  
- Validates using the **BIDS Validator**.  

### 2. MRIQC
- Runs **MRIQC** to compute Image Quality Metrics (IQMs).  
- Produces both visual and numerical QC outputs.  

### 3. Preprocessing
- Reorients images with **FSL (fslreorient2std)**.  
- Performs co-registration (FLIRT) and brain extraction (BET).  
- Normalizes images to **MNI space** (FLIRT + FNIRT).  
- Applies transformations and smoothing.  
- Computes **SUVR** values using **FSLstats**.  

### 4. Analysis
- Defines ROIs using **FreeSurfer**.  
- Extracts mean uptake values and converts to **Centiloid (CL)** values.  
- Performs QC of ROI placement.  
- Runs **R scripts** for correlation analysis with published Centiloid values.  
- Group-level script merges results across participants for statistical analysis.  

---

## How to Run
Each step has its own script inside the relevant folder:  

```bash
# Example: Run generalized preprocessing script
bash preprocessing/generalized/preprocessing.sh
``` 

---

## Usage
Run each script in order:

```bash
bash 01_datastructure.sh
bash 02_mriqc.sh
bash 03_preprocessing.sh
bash 04_analysis.sh
```

---

## Dependencies
This pipeline requires:

- **Neurodesk** (container environment)  
- **dcm2niix v1.0.20240202**  
- **FSL v6.0.7.8**  
- **MRIQC v23.1.0**  
- **FreeSurfer v7.3.2**  
- **R v4.3.2**

---

## Documentation
Full protocol steps are available on [Protocols.io](https://www.protocols.io/private/7660A61B845711F093A30A58A9FEAC02).

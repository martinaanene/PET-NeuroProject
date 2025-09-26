#!/bin/bash
# Analysis pipeline (generalized: loop across multiple subjects)

# Step 1:  Define Regions of Interest (ROI) with FreeSurfer (must be pre-run for each subject)
ml freesurfer/7.3.2
export SUBJECTS_DIR=$PWD/freesurfer_output

# Run FreeSurfer reconstruction (structural MRI) for each subject (example: sub-01 ... sub-10)
for subj in sub-01 sub-02 sub-03 sub-04 sub-05 sub-06 sub-07 sub-08 sub-09 sub-10; do
    recon-all -s $subj -all -i ${subj}_T1w.nii.gz
    
# Convert cortical parcellation to ROI mask
mri_aparc2aseg --s $subj --o ${subj}_ROIs.nii.gz

# Step 2–4: Extract SUVR and convert to Centiloid
ml fsl/6.0.7.8
ml R/4.3.2

# Create header for group CSV
echo "Subject,ROI,SUVR,Centiloid" > group_CL.csv

for subj in sub-01 sub-02 sub-03 sub-04 sub-05 sub-06 sub-07 sub-08 sub-09 sub-10; do
    
    # Extract SUVR
    fslstats pet/${subj}_pet_in_MNI_smoothed.nii.gz -k ${subj}_ROIs.nii.gz -M > ${subj}_SUVR.txt

    # Write subject SUVR CSV
    echo "Subject,ROI,SUVR" > ${subj}_SUVR.csv
    echo "${subj},ROI1,$(cat ${subj}_SUVR.txt)" >> ${subj}_SUVR.csv

    # Convert to Centiloid
    Rscript -e "suvr <- read.csv('${subj}_SUVR.csv'); \
                 suvr\$Centiloid <- (suvr\$SUVR * 100) / 1.5; \
                 write.csv(suvr, '${subj}_CL.csv', row.names=FALSE)"

    # Append participant data to group CSV (skip header)
    tail -n +2 ${subj}_CL.csv >> group_CL.csv
done

# Step 5b: Group-level Quality Check
for subj in sub-01 sub-02 sub-03; do
    fsleyes pet/${subj}_pet_in_MNI_smoothed.nii.gz ${subj}_ROIs.nii.gz -cm red
done

# Step 6b: Group Statistical Analysis
Rscript -e "data <- read.csv('group_CL.csv'); \
             standard <- read.csv('published_centiloid.csv'); \
             model <- lm(data\$Centiloid ~ standard\$Centiloid); \
             summary(model)"

#!/bin/bash
# Master Batch Processing Script for PET-NeuroProject (SUB4_5 VERSION)
# Runs the pipeline for subjects 04 to 05 ONLY

# Define the range of subjects
start_sub=4
end_sub=5

# Log file
log_file="batch_processing_log_SUB4_5_$(date +%Y%m%d_%H%M%S).txt"
# Master CSV file for results (Absolute path to ensure sub-scripts find it)
master_csv="$(pwd)/all_subjects_results_SUB4_5.csv"

# Determine the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Remove existing master CSV to ensure a fresh start
if [ -f "$master_csv" ]; then
    echo "Removing existing master CSV: $master_csv" | tee -a "$log_file"
    rm "$master_csv"
fi

echo "Starting SUB4_5 Batch Processing at $(date)" | tee -a "$log_file"
echo "Results will be saved to: $master_csv" | tee -a "$log_file"

for ((i=start_sub; i<=end_sub; i++)); do
    # Format subject ID with leading zero (e.g., 1 -> 01)
    subject_id=$(printf "%02d" $i)
    
    echo "==================================================" | tee -a "$log_file"
    echo "Processing Subject ID: $subject_id" | tee -a "$log_file"
    echo "==================================================" | tee -a "$log_file"
    
    # Run Step 1: Data Structure
    echo "Running 01_datastructure.sh..." | tee -a "$log_file"
    "${SCRIPT_DIR}/01_datastructure.sh" "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 01_datastructure.sh failed for $subject_id. Check log." | tee -a "$log_file"
        # Decide whether to continue or skip to next subject. 
        # Usually if data structure fails, the rest will fail.
        continue
    fi
    
    # Run Step 2: MRIQC
    echo "Running 02_mriqc.sh..." | tee -a "$log_file"
    "${SCRIPT_DIR}/02_mriqc.sh" "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 02_mriqc.sh failed for $subject_id. Check log." | tee -a "$log_file"
    fi
    
    # Run Step 3: Preprocessing
    echo "Running 03_preprocessing.sh..." | tee -a "$log_file"
    "${SCRIPT_DIR}/03_preprocessing.sh" "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 03_preprocessing.sh failed for $subject_id. Check log." | tee -a "$log_file"
        continue
    fi
    
    # Run Step 4: Analysis
    echo "Running 04_analysis.sh..." | tee -a "$log_file"
    # Pass the master CSV as the second argument
    "${SCRIPT_DIR}/04_analysis.sh" "$subject_id" "$master_csv" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 04_analysis.sh failed for $subject_id. Check log." | tee -a "$log_file"
    fi
    
    echo "Finished Subject $subject_id at $(date)" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
    
done

echo "==================================================" | tee -a "$log_file"
echo "Running MRIQC Group Analysis..." | tee -a "$log_file"
echo "==================================================" | tee -a "$log_file"

"${SCRIPT_DIR}/02_mriqc.sh" group >> "$log_file" 2>&1

echo "SUB4_5 Batch Processing Complete. See $log_file for details."

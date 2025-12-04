#!/bin/bash
# Master Batch Processing Script for PET-NeuroProject
# Runs the full pipeline for subjects 01 to 25

# Define the range of subjects
start_sub=1
end_sub=25

# Log file
log_file="batch_processing_log_$(date +%Y%m%d_%H%M%S).txt"
# Master CSV file for results
master_csv="all_subjects_results.csv"

# Remove existing master CSV to ensure a fresh start
if [ -f "$master_csv" ]; then
    echo "Removing existing master CSV: $master_csv" | tee -a "$log_file"
    rm "$master_csv"
fi

echo "Starting Batch Processing at $(date)" | tee -a "$log_file"
echo "Results will be saved to: $master_csv" | tee -a "$log_file"

for ((i=start_sub; i<=end_sub; i++)); do
    # Format subject ID with leading zero (e.g., 1 -> 01)
    subject_id=$(printf "%02d" $i)
    
    echo "==================================================" | tee -a "$log_file"
    echo "Processing Subject ID: $subject_id" | tee -a "$log_file"
    echo "==================================================" | tee -a "$log_file"
    
    # Run Step 1: Data Structure
    echo "Running 01_datastructure.sh..." | tee -a "$log_file"
    ./01_datastructure.sh "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 01_datastructure.sh failed for $subject_id. Check log." | tee -a "$log_file"
        # Decide whether to continue or skip to next subject. 
        # Usually if data structure fails, the rest will fail.
        continue
    fi
    
    # Run Step 2: MRIQC
    echo "Running 02_mriqc.sh..." | tee -a "$log_file"
    ./02_mriqc.sh "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 02_mriqc.sh failed for $subject_id. Check log." | tee -a "$log_file"
        # Continue? MRIQC failure might not block preprocessing, but good to note.
    fi
    
    # Run Step 3: Preprocessing
    echo "Running 03_preprocessing.sh..." | tee -a "$log_file"
    ./03_preprocessing.sh "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 03_preprocessing.sh failed for $subject_id. Check log." | tee -a "$log_file"
        continue
    fi
    
    # Run Step 4: Analysis
    echo "Running 04_analysis.sh..." | tee -a "$log_file"
    # Pass the master CSV as the second argument
    ./04_analysis.sh "$subject_id" "$master_csv" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 04_analysis.sh failed for $subject_id. Check log." | tee -a "$log_file"
    fi
    
    echo "Finished Subject $subject_id at $(date)" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
    
done

echo "==================================================" | tee -a "$log_file"
echo "Running MRIQC Group Analysis..." | tee -a "$log_file"
echo "==================================================" | tee -a "$log_file"

./02_mriqc.sh group >> "$log_file" 2>&1

echo "Batch Processing Complete. See $log_file for details."

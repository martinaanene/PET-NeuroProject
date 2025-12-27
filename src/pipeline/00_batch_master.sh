#!/bin/bash
# Master Batch Processing Script for PET-NeuroProject
# Runs the full pipeline for subjects 01 to 25

# Define the range of subjects
# Default to 1-25 if not provided
start_sub=${1:-1}
end_sub=${2:-25}

# Determine the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Log file
log_file="batch_processing_log_sub${start_sub}-${end_sub}_$(date +%Y%m%d_%H%M%S).txt"
# Master CSV file for results (Absolute path to ensure sub-scripts find it)
master_csv="${PROJECT_ROOT}/results/tables/all_subjects_results.csv"

# Ensure the directory exists
mkdir -p "$(dirname "$master_csv")"


# Remove existing master CSV to ensure a fresh start ONLY IF starting from subject 1
if [ "$start_sub" -eq 1 ] && [ -f "$master_csv" ]; then
    echo "Removing existing master CSV: $master_csv" | tee -a "$log_file"
    rm "$master_csv"
fi

echo "Starting Batch Processing for subjects $start_sub to $end_sub at $(date)" | tee -a "$log_file"
echo "Results will be saved to: $master_csv" | tee -a "$log_file"

for ((i=start_sub; i<=end_sub; i++)); do
    # Format subject ID with leading zero (e.g., 1 -> 01)
    subject_id=$(printf "%02d" $i)
    
    echo "==================================================" | tee -a "$log_file"
    echo "Processing Subject ID: $subject_id" | tee -a "$log_file"
    echo "Disk Usage Check:" | tee -a "$log_file"
    df -h | tee -a "$log_file"
    echo "==================================================" | tee -a "$log_file"
    
    # Run Step 1: Data Organization (01_data_org.sh)
    echo "Running 01_data_org.sh..." | tee -a "$log_file"
    "${SCRIPT_DIR}/01_data_org.sh" "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 01_data_org.sh failed for $subject_id. Check log." | tee -a "$log_file"
        # Decide whether to continue or skip to next subject. 
        # Usually if data structure fails, the rest will fail.
        continue
    fi
    
    # Run Step 2: MRIQC (DISABLED TEMPORARILY due to crashes)
    # echo "Running 02_mriqc.sh..." | tee -a "$log_file"
    # "${SCRIPT_DIR}/02_mriqc.sh" "$subject_id" >> "$log_file" 2>&1
    # if [ $? -ne 0 ]; then
    #     echo "ERROR: 02_mriqc.sh failed for $subject_id. Check log." | tee -a "$log_file"
    # fi
    
    # Run Step 3: Preprocessing
    echo "Running 03_preprocessing.sh..." | tee -a "$log_file"
    "${SCRIPT_DIR}/03_preprocessing.sh" "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: 03_preprocessing.sh failed for $subject_id. Check log." | tee -a "$log_file"
        continue
    fi

    # Run Visual QC (visual_qc.sh)
    echo "Running visual_qc.sh..." | tee -a "$log_file"
    "${SCRIPT_DIR}/../qc/visual_qc.sh" "$subject_id" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: visual_qc.sh failed for $subject_id. Check log." | tee -a "$log_file"
        # Non-blocking failure
    fi

    
    # Run Step 4: Analysis (analysis.sh)
    echo "Running analysis.sh..." | tee -a "$log_file"
    # Pass the master CSV as the second argument
    "${SCRIPT_DIR}/../Analysis/analysis.sh" "$subject_id" "$master_csv" >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: analysis.sh failed for $subject_id. Check log." | tee -a "$log_file"
    fi
    
    echo "Finished Subject $subject_id at $(date)" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
    
done

echo "==================================================" | tee -a "$log_file"
echo "Running MRIQC Group Analysis..." | tee -a "$log_file"
echo "==================================================" | tee -a "$log_file"

# "${SCRIPT_DIR}/02_mriqc.sh" group >> "$log_file" 2>&1

echo "==================================================" | tee -a "$log_file"
echo "Generating HTML QC Report..." | tee -a "$log_file"
echo "==================================================" | tee -a "$log_file"

if command -v python3 &> /dev/null; then
    python3 "${SCRIPT_DIR}/../qc/generate_report.py" >> "$log_file" 2>&1
else
    echo "WARNING: python3 not found, skipping report generation." | tee -a "$log_file"
fi


echo "Batch Processing Complete. See $log_file for details."

import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats
import numpy as np
import glob
import os
import sys

# =================================================================================
# STATISTICAL ANALYSIS SCRIPT
#
# This script performs a linear correlation analysis between:
# 1. Calculated Global Cortical SUVR vs. Reference SUVR
# 2. Calculated Centiloid vs. Reference Centiloid
#
# Inputs:
# - Calculated Results: CSV file(s) ending in *_global_cortical_results.csv
# - Reference Data: Centiloid_Project_Values.csv (Headers: Subject, SUVR, Centiloid)
# =================================================================================

def main():
    # --- 1. FIND AND LOAD CALCULATED RESULTS ---
    # ---------------------------------------------------------------------------------
    print("--- Loading Calculated Results ---")
    
    # Simple logic: Check argument or default to current directory
    if len(sys.argv) > 1:
        results_file = sys.argv[1]
    else:
        results_file = "all_subjects_results.csv"

    if not os.path.exists(results_file):
        print(f"ERROR: Results file not found: {results_file}")
        print("Please upload 'all_subjects_results.csv' to the same folder as this script.")
        sys.exit(1)

    print(f"Reading results from: {results_file}")
    
    try:
        df_calc = pd.read_csv(results_file)
    except Exception as e:
        print(f"ERROR: Could not read {results_file}: {e}")
        sys.exit(1)

    if df_calc.empty:
        print("ERROR: Results file is empty.")
        sys.exit(1)

    print("Calculated Data Preview:")
    print(df_calc.head())
    print("-" * 30)


    # --- 2. LOAD REFERENCE DATA ---
    # ---------------------------------------------------------------------------------
    print("--- Loading Reference Data ---")
    
    ref_file = "Centiloid_Project_Values.csv"
    
    if not os.path.exists(ref_file):
        print(f"ERROR: Reference file not found: {ref_file}")
        print("Please upload 'Centiloid_Project_Values.csv' to the same folder as this script.")
        sys.exit(1)

    try:
        df_ref = pd.read_csv(ref_file)
        # Expected headers: Subject, SUVR, Centiloid
        # Normalize headers just in case
        df_ref.columns = [c.strip() for c in df_ref.columns]
    except Exception as e:
        print(f"ERROR: Could not read reference file: {e}")
        sys.exit(1)

    print("Reference Data Preview:")
    print(df_ref.head())
    print("-" * 30)


    # --- 3. MERGE DATASETS ---
    # ---------------------------------------------------------------------------------
    print("--- Merging Datasets ---")
    # Ensure subject IDs match format. 
    # 04_analysis.sh outputs "sub-02". Reference might be "sub-02" or "02".
    # Let's try to standardize to string for merging.
    
    df_calc['subject_id'] = df_calc['subject_id'].astype(str).str.strip()
    df_ref['Subject'] = df_ref['Subject'].astype(str).str.strip()

    # Merge on subject ID
    df_merged = pd.merge(df_calc, df_ref, left_on='subject_id', right_on='Subject', how='inner')

    if df_merged.empty:
        print("ERROR: No matching subjects found between calculated and reference data.")
        print("Check your Subject IDs in both files.")
        sys.exit(1)

    print(f"Successfully merged {len(df_merged)} subjects.")
    print("-" * 30)


    # --- 4. PERFORM CORRELATION ANALYSIS ---
    # ---------------------------------------------------------------------------------
    
    # A. SUVR Correlation
    x_suvr = df_merged['global_cortical_suvr']
    y_suvr = df_merged['SUVR'] # Reference SUVR
    
    r_suvr, p_suvr = stats.pearsonr(x_suvr, y_suvr)
    
    # B. Centiloid Correlation
    x_cl = df_merged['global_cortical_centiloid']
    y_cl = df_merged['Centiloid'] # Reference Centiloid
    
    r_cl, p_cl = stats.pearsonr(x_cl, y_cl)


    # --- 5. PRINT RESULTS ---
    # ---------------------------------------------------------------------------------
    print("\n=== STATISTICAL ANALYSIS RESULTS ===")
    print(f"Number of Subjects: {len(df_merged)}")
    print("\n1. Global Cortical SUVR Correlation:")
    print(f"   Pearson r: {r_suvr:.4f}")
    print(f"   p-value:   {p_suvr:.4e}")
    
    print("\n2. Centiloid Value Correlation:")
    print(f"   Pearson r: {r_cl:.4f}")
    print(f"   p-value:   {p_cl:.4e}")
    print("====================================\n")


    # --- 6. GENERATE PLOTS ---
    # ---------------------------------------------------------------------------------
    print("Generating plots...")
    
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))

    # Plot 1: SUVR
    axes[0].scatter(x_suvr, y_suvr, alpha=0.7)
    axes[0].set_title(f'SUVR Correlation\nr={r_suvr:.3f}, p={p_suvr:.3e}')
    axes[0].set_xlabel('Calculated SUVR')
    axes[0].set_ylabel('Reference SUVR')
    # Add regression line
    m, b = np.polyfit(x_suvr, y_suvr, 1)
    axes[0].plot(x_suvr, m*x_suvr + b, color='red', linestyle='--')
    axes[0].grid(True, linestyle=':', alpha=0.6)

    # Plot 2: Centiloid
    axes[1].scatter(x_cl, y_cl, color='green', alpha=0.7)
    axes[1].set_title(f'Centiloid Correlation\nr={r_cl:.3f}, p={p_cl:.3e}')
    axes[1].set_xlabel('Calculated Centiloid')
    axes[1].set_ylabel('Reference Centiloid')
    # Add regression line
    m, b = np.polyfit(x_cl, y_cl, 1)
    axes[1].plot(x_cl, m*x_cl + b, color='red', linestyle='--')
    axes[1].grid(True, linestyle=':', alpha=0.6)

    plt.tight_layout()
    output_plot = "correlation_plots.png"
    plt.savefig(output_plot)
    print(f"Plots saved to: {output_plot}")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
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
    # --- 1. SET ENVIRONMENT & PATHS ---
    # ---------------------------------------------------------------------------------
    print("--- Configuring Environment ---")
    
    try:
        from google.colab import drive
        IN_COLAB = True
    except ImportError:
        IN_COLAB = False

    if IN_COLAB:
        print(">> Detected Google Colab. Mounting Drive...")
        drive.mount('/content/drive')
        
        # User-defined Colab Structure:
        # Root: MyDrive/PET-NeuroProject
        # Inputs: /csv/
        # Outputs: /results/
        project_root = "/content/drive/MyDrive/PET-NeuroProject"
        
        csv_dir = os.path.join(project_root, "csv")
        output_dir = os.path.join(project_root, "results")
        
        # Define Input Files
        results_file = os.path.join(csv_dir, "all_subjects_results.csv")
        ref_file = os.path.join(csv_dir, "Centiloid_Project_Values.csv")
        
        print(f">> Colab Project Root: {project_root}")
        print(f">> Input Folder: {csv_dir}")
        print(f">> Output Folder: {output_dir}")

        # Ensure output directory exists
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            print(f"Created output directory: {output_dir}")

    else:
        # Fallback to Original Local Structure (Neurodesk)
        print(">> Detected Local Environment.")
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(os.path.dirname(script_dir))
        
        # Define Input Files
        if len(sys.argv) > 1:
            results_file = sys.argv[1]
        else:
            results_file = os.path.join(project_root, "results", "tables", "all_subjects_results.csv")

        ref_file = os.path.join(project_root, "data", "references", "centiloid_values.csv")
        
        # Define Output Dir
        output_dir = os.path.join(project_root, "results", "reports")
        
        # Ensure output directory exists (Local)
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            print(f"Created output directory: {output_dir}")


    # --- 2. CHECK INPUT FILES ---
    # ---------------------------------------------------------------------------------
    if not os.path.exists(results_file):
        print(f"ERROR: Results file not found: {results_file}")
        if IN_COLAB:
            print("Check that 'all_subjects_results.csv' is in your Drive under 'PET-NeuroProject/csv/'")
        else:
            print("Check standard local path or provide file as argument.")
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


    # --- 3. LOAD REFERENCE DATA ---
    # ---------------------------------------------------------------------------------
    print("--- Loading Reference Data ---")
    
    if not os.path.exists(ref_file):
        print(f"ERROR: Reference file not found: {ref_file}")
        if IN_COLAB:
             print("Check that 'Centiloid_Project_Values.csv' is in your Drive under 'PET-NeuroProject/csv/'")
        else:
             print("Check standard local path.")
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


    # --- 4. MERGE DATASETS ---
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


    # --- 5. PERFORM CORRELATION ANALYSIS ---
    # ---------------------------------------------------------------------------------
    
    # A. SUVR Correlation
    x_suvr = df_merged['global_cortical_suvr']
    y_suvr = df_merged['SUVR'] # Reference SUVR
    
    r_suvr, p_suvr = stats.pearsonr(x_suvr, y_suvr)
    
    # B. Centiloid Correlation
    x_cl = df_merged['global_cortical_centiloid']
    y_cl = df_merged['Centiloid'] # Reference Centiloid
    
    r_cl, p_cl = stats.pearsonr(x_cl, y_cl)


    # --- 6. PRINT RESULTS ---
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


    # --- 7. GENERATE PLOTS ---
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
    output_plot = os.path.join(output_dir, "correlation_plots.png")
    plt.savefig(output_plot)
    print(f"Plots saved to: {output_plot}")

if __name__ == "__main__":
    main()

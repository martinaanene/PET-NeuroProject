
import json
import sys
import glob
import os

def merge_jsons(output_file, input_files):
    """
    Merges multiple BIDS JSON sidecars into one.
    - Consolidates FrameDuration and FrameTimesStart.
    - Injects missing required keys.
    """
    if not input_files:
        print("Error: No input files provided.")
        sys.exit(1)

    # Load the first JSON as the base
    try:
        with open(input_files[0], 'r') as f:
            merged_data = json.load(f)
    except Exception as e:
        print(f"Error reading {input_files[0]}: {e}")
        sys.exit(1)

    # If there are multiple files, we assume they are split parts of a sequence
    # and we need to append frame timing info.
    if len(input_files) > 1:
        print(f"Merging metadata from {len(input_files)} files...")
        
        # Ensure lists exist
        if 'FrameDuration' not in merged_data: merged_data['FrameDuration'] = []
        if 'FrameTimesStart' not in merged_data: merged_data['FrameTimesStart'] = []
        
        # Iterate through the rest
        for next_file in input_files[1:]:
            try:
                with open(next_file, 'r') as f:
                    next_data = json.load(f)
                    
                    # Extend lists
                    if 'FrameDuration' in next_data:
                        merged_data['FrameDuration'].extend(next_data['FrameDuration'])
                    if 'FrameTimesStart' in next_data:
                        merged_data['FrameTimesStart'].extend(next_data['FrameTimesStart'])
            except Exception as e:
                print(f"Warning: Could not merge {next_file}: {e}")

    # Inject missing required BIDS fields if they don't exist
    defaults = {
        "TracerName": "Unknown",
        "TracerRadionuclide": "Unknown",
        "ReconFilterSize": 0,
        "Units": "Bq/mL",
        "InstitutionName": "Unknown",
        "Manufacturer": "Unknown",
        "InjectedRadioactivity": 0,
        "InjectedRadioactivityUnits": "MBq",
        "InjectedMass": 0,
        "InjectedMassUnits": "ug",
        "ScanStart": "00:00:00",
        "InjectionStart": "00:00:00",
        "AcquisitionMode": "unknown",
        "ImageDecayCorrected": False,
        "ImageDecayCorrectionTime": 0,
        "ReconMethodName": "Unknown",
        "ReconMethodParameterLabels": ["none"],
        "ReconMethodParameterValues": [0],
        "ReconMethodParameterUnits": ["none"],
        "ReconFilterType": "Unknown",
        "AttenuationCorrection": "Unknown",
        "SpecificRadioactivity": 0,
        "SpecificRadioactivityUnits": "Bq/g",
        "ModeOfAdministration": "bolus",
        "TimeZero": "00:00:00"
    }
    
    for key, value in defaults.items():
        if key not in merged_data:
            print(f"Injecting missing key: {key}")
            merged_data[key] = value

    # Write out
    try:
        with open(output_file, 'w') as f:
            json.dump(merged_data, f, indent=4)
        print(f"Successfully wrote fixed JSON to {output_file}")
    except Exception as e:
        print(f"Error writing output: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python fix_bids_json.py <output_json> <input_json1> [input_json2 ...]")
        sys.exit(1)
    
    output_json = sys.argv[1]
    input_jsons = sys.argv[2:]
    
    merge_jsons(output_json, input_jsons)

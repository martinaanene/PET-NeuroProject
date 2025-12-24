import os
import glob
import sys
from datetime import datetime

def generate_report():
    # Define paths
    base_dir = os.path.expanduser("~/Desktop/pet_pipeline_output")
    qc_dir = os.path.join(base_dir, "QC")
    output_report = os.path.join(qc_dir, "index.html")
    
    print(f"Generating QC Report at: {output_report}")
    
    # Find all subjects in QC dir
    subjects = sorted([d for d in os.listdir(qc_dir) if d.startswith("sub-") and os.path.isdir(os.path.join(qc_dir, d))])
    
    if not subjects:
        print("No subject QC folders found.")
        return

    # Start HTML content
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>PET-NeuroProject QC Report</title>
        <style>
            body {{ font-family: sans-serif; margin: 20px; }}
            h1 {{ color: #333; }}
            .subject-container {{ border-bottom: 2px solid #ccc; padding: 20px 0; }}
            .subject-header {{ font-size: 1.5em; font-weight: bold; margin-bottom: 10px; }}
            .images-row {{ display: flex; gap: 10px; overflow-x: auto; }}
            .image-box {{ flex: 1; min-width: 300px; }}
            img {{ width: 100%; border: 1px solid #ddd; border-radius: 5px; }}
            .label {{ text-align: center; font-weight: bold; margin-top: 5px; color: #555; }}
            .status {{ margin-left: 10px; font-size: 0.8em; }}
            .status.pass {{ color: green; }}
            .status.fail {{ color: red; }}
        </style>
    </head>
    <body>
        <h1>PET-NeuroProject Quality Control Report</h1>
        <p>Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        <p>Total Subjects: {len(subjects)}</p>
    """

    for sub in subjects:
        sub_qc_path = os.path.join(qc_dir, sub)
        
        # Image paths (relative to report location)
        img_coreg = f"{sub}/qc_coreg.png"
        img_norm = f"{sub}/qc_norm.png"
        img_masks = f"{sub}/qc_masks.png"
        
        # Check if files exist
        has_coreg = os.path.exists(os.path.join(sub_qc_path, "qc_coreg.png"))
        has_norm = os.path.exists(os.path.join(sub_qc_path, "qc_norm.png"))
        has_masks = os.path.exists(os.path.join(sub_qc_path, "qc_masks.png"))
        
        html += f"""
        <div class="subject-container">
            <div class="subject-header">
                {sub} 
            </div>
            <div class="images-row">
        """
        
        # Coregistration
        html += '<div class="image-box">'
        if has_coreg:
            html += f'<img src="{img_coreg}" alt="Coregistration"><div class="label">Coregistration</div>'
        else:
            html += '<div style="height:200px; background:#f0f0f0; display:flex; align-items:center; justify-content:center;">Missing</div>'
        html += '</div>'
        
        # Normalization
        html += '<div class="image-box">'
        if has_norm:
            html += f'<img src="{img_norm}" alt="Normalization"><div class="label">Normalization</div>'
        else:
            html += '<div style="height:200px; background:#f0f0f0; display:flex; align-items:center; justify-content:center;">Missing</div>'
        html += '</div>'
        
        # Masks
        html += '<div class="image-box">'
        if has_masks:
            html += f'<img src="{img_masks}" alt="Mask Alignment"><div class="label">Mask Alignment</div>'
        else:
            html += '<div style="height:200px; background:#f0f0f0; display:flex; align-items:center; justify-content:center;">Missing</div>'
        html += '</div>'
        
        html += """
            </div>
        </div>
        """

    html += """
    </body>
    </html>
    """
    
    with open(output_report, "w") as f:
        f.write(html)
        
    print("Report generation complete.")

if __name__ == "__main__":
    generate_report()

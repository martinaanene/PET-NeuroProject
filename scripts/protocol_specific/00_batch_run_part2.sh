#!/bin/bash
# Wrapper script for Batch Processing Part 2 (Subjects 14-25)

# Determine the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Starting Batch Part 2..."
"${SCRIPT_DIR}/00_batch_run.sh" 14 25

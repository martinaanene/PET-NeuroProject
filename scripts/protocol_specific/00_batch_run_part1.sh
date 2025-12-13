#!/bin/bash
# Wrapper script for Batch Processing Part 1 (Subjects 1-13)

# Determine the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Starting Batch Part 1..."
"${SCRIPT_DIR}/00_batch_run.sh" 1 10

#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building claude-sandbox image..."
docker build -t claude-sandbox "$SCRIPT_DIR"

echo ""
echo "Done! Image 'claude-sandbox' is ready."
echo "Run 'claude-sandbox' from any directory to start."

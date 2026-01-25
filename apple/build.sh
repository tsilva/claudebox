#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building claude-sandbox-apple image..."
container build -t claude-sandbox-apple "$SCRIPT_DIR/.."

echo ""
echo "Done! Image 'claude-sandbox-apple' is ready."
echo "Run 'claude-sandbox-apple' from any directory to start."

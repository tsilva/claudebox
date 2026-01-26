#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Apple Container CLI is available
if ! command -v container &>/dev/null; then
  echo "Error: Apple Container CLI is not installed or not in PATH"
  echo "Please install with: brew install --cask container"
  echo "Requires macOS 26+ and Apple Silicon"
  exit 1
fi

echo "Building claude-sandbox-apple image..."
container build -t claude-sandbox-apple "$SCRIPT_DIR/.."

echo ""
echo "Done! Image 'claude-sandbox-apple' is ready."
echo "Run 'claude-sandbox-apple' from any directory to start."

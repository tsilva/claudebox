#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Docker is available
if ! command -v docker &>/dev/null; then
  echo "Error: Docker is not installed or not in PATH"
  echo "Please install Docker Desktop: https://docs.docker.com/get-docker/"
  exit 1
fi

echo "Building claude-sandbox image..."
docker build -t claude-sandbox "$SCRIPT_DIR/.."

echo ""
echo "Done! Image 'claude-sandbox' is ready."
echo "Run 'claude-sandbox' from any directory to start."

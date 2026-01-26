#!/bin/bash
set -e

# Check if Docker is available
if ! command -v docker &>/dev/null; then
  echo "Error: Docker is not installed or not in PATH"
  exit 1
fi

echo "Removing claude-sandbox image..."
docker image rm claude-sandbox 2>/dev/null || echo "Image not found, skipping"

echo ""
echo "Note: The shell function in your .zshrc/.bashrc was not removed."
echo "To remove it manually, edit your shell config and delete the claude-sandbox function."
echo ""
echo "Uninstall complete."

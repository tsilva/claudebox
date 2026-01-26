#!/bin/bash
set -e

# Check if Apple Container CLI is available
if ! command -v container &>/dev/null; then
  echo "Error: Apple Container CLI is not installed or not in PATH"
  exit 1
fi

echo "Removing claude-sandbox-apple image..."
container image rm claude-sandbox-apple 2>/dev/null || echo "Image not found, skipping"

echo ""
echo "Note: The shell function in your .zshrc/.bashrc was not removed."
echo "To remove it manually, edit your shell config and delete the claude-sandbox-apple function."
echo ""
echo "Uninstall complete."

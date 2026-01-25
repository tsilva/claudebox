#!/bin/bash
set -e

echo "Removing claude-sandbox-apple image..."
container image rm claude-sandbox-apple 2>/dev/null || echo "Image not found, skipping"

echo ""
echo "Note: The shell function in your .zshrc/.bashrc was not removed."
echo "To remove it manually, edit your shell config and delete the claude-sandbox-apple function."
echo ""
echo "Uninstall complete."

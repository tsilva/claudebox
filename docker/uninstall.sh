#!/bin/bash
set -e

# Prompt for confirmation
read -p "This will remove the claude-sandbox image and shell function. Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Uninstall cancelled."
  exit 0
fi

# Check if Docker is available
if ! command -v docker &>/dev/null; then
  echo "Error: Docker is not installed or not in PATH"
  exit 1
fi

echo "Removing claude-sandbox image..."
docker image rm claude-sandbox 2>/dev/null || echo "Image not found, skipping"

# Detect shell config file
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
else
  SHELL_RC=""
fi

# Remove shell function if shell config exists
if [ -n "$SHELL_RC" ]; then
  if grep -q "^# Claude Sandbox - run Claude Code in an isolated Docker container$" "$SHELL_RC" 2>/dev/null; then
    echo "Removing claude-sandbox function from $SHELL_RC..."
    # Remove from comment line through closing brace (function end)
    sed -i.bak '/^# Claude Sandbox - run Claude Code in an isolated Docker container$/,/^}$/d' "$SHELL_RC"
    rm -f "$SHELL_RC.bak"
    echo "Shell function removed."
  else
    echo "Shell function not found in $SHELL_RC, skipping"
  fi
else
  echo "No shell config file found, skipping function removal"
fi

echo ""
echo "Uninstall complete."
echo ""
echo "Run: source $SHELL_RC"

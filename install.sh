#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the image first
"$SCRIPT_DIR/build.sh"

# Shell function to add
SHELL_FUNCTION='
# Claude Sandbox - run Claude Code in an isolated Docker container
claude-sandbox() {
  mkdir -p ~/.claude-sandbox/claude-config
  docker run -it --rm \
    -v "$(pwd)":/workspace \
    -v ~/.claude-sandbox/claude-config:/home/claude/.claude \
    claude-sandbox "$@"
}'

# Detect shell config file
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
else
  SHELL_RC="$HOME/.zshrc"
fi

# Check if already installed
if grep -q "claude-sandbox()" "$SHELL_RC" 2>/dev/null; then
  echo "claude-sandbox function already exists in $SHELL_RC"
  echo "Please manually update the function or remove it and re-run install.sh"
else
  echo "$SHELL_FUNCTION" >> "$SHELL_RC"
  echo "Added claude-sandbox function to $SHELL_RC"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Run: source $SHELL_RC"
echo ""
echo "First-time setup (authenticate with Claude subscription):"
echo "  claude-sandbox login"
echo ""
echo "Then from any project directory:"
echo "  cd <your-project> && claude-sandbox"

#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the image first
"$SCRIPT_DIR/build.sh"

# Shell function to add
SHELL_FUNCTION='
# Claude Sandbox - run Claude Code in an isolated container
claude-sandbox() {
  if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY is not set"
    return 1
  fi
  container run -it \
    -v "$(pwd)":/workspace \
    -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    claude-sandbox "$@"
}
'

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
else
  echo "$SHELL_FUNCTION" >> "$SHELL_RC"
  echo "Added claude-sandbox function to $SHELL_RC"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Run: source $SHELL_RC"
echo "Then: cd <your-project> && claude-sandbox"

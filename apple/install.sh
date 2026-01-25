#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the image first
"$SCRIPT_DIR/build.sh"

# Shell function to add
SHELL_FUNCTION='
# Claude Sandbox (Apple Container) - run Claude Code in an isolated container
claude-sandbox-apple() {
  mkdir -p ~/.claude-sandbox/claude-config
  [ -s ~/.claude-sandbox/.claude.json ] || echo '{}' > ~/.claude-sandbox/.claude.json
  container run -it --rm \
    -v "$(pwd)":/workspace \
    -v ~/.claude-sandbox/claude-config:/home/claude/.claude \
    -v ~/.claude-sandbox/.claude.json:/home/claude/.claude.json \
    claude-sandbox-apple "$@"
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
if grep -q "claude-sandbox-apple()" "$SHELL_RC" 2>/dev/null; then
  echo "claude-sandbox-apple function already exists in $SHELL_RC"
  echo "Please manually update the function or remove it and re-run install.sh"
else
  echo "$SHELL_FUNCTION" >> "$SHELL_RC"
  echo "Added claude-sandbox-apple function to $SHELL_RC"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Run: source $SHELL_RC"
echo ""
echo "First-time setup (authenticate with Claude subscription):"
echo "  claude-sandbox-apple login"
echo ""
echo "Then from any project directory:"
echo "  cd <your-project> && claude-sandbox-apple"

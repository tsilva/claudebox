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
  [ -s ~/.claude-sandbox/.claude.json ] || echo '\''{}'\'' > ~/.claude-sandbox/.claude.json

  local entrypoint_args=()
  local cmd_args=("$@")
  local extra_mounts=()
  local workdir
  workdir="$(pwd)"

  if [ "${1:-}" = "shell" ]; then
    entrypoint_args=(--entrypoint /bin/bash)
    cmd_args=()
  fi

  # Parse project config if it exists
  if [ -f ".claude-sandbox.json" ] && command -v jq &>/dev/null; then
    while IFS= read -r mount_spec; do
      [ -n "$mount_spec" ] && extra_mounts+=(-v "$mount_spec")
    done < <(jq -r '\''(.mounts // [])[] |
      .path + ":" + .path + (if .readonly then ":ro" else "" end)'\'' \
      .claude-sandbox.json 2>/dev/null)
  fi

  container run -it --rm \
    --workdir "$workdir" \
    -v "$workdir:$workdir" \
    -v ~/.claude-sandbox/claude-config:/home/claude/.claude \
    -v ~/.claude-sandbox/.claude.json:/home/claude/.claude.json \
    "${extra_mounts[@]}" \
    "${entrypoint_args[@]}" \
    claude-sandbox-apple "${cmd_args[@]}"
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
echo ""
echo "To inspect the sandbox environment:"
echo "  claude-sandbox-apple shell"

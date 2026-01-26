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

# Build the image first
"$SCRIPT_DIR/build.sh"

# Shell function to add
SHELL_FUNCTION='
# Claude Sandbox (Apple Container) - run Claude Code in an isolated container
claude-sandbox-apple() {
  mkdir -p ~/.claude-sandbox/claude-config
  # Atomic file creation to avoid race conditions
  local json_file=~/.claude-sandbox/.claude.json
  if [ ! -s "$json_file" ]; then
    local tmp_file
    tmp_file=$(mktemp)
    echo '\''{}'\'' > "$tmp_file"
    mv -n "$tmp_file" "$json_file" 2>/dev/null || rm -f "$tmp_file"
  fi

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
  if [ -f ".claude-sandbox.json" ]; then
    if ! command -v jq &>/dev/null; then
      echo "Warning: jq not installed, skipping .claude-sandbox.json mounts" >&2
      echo "Install with: brew install jq" >&2
    else
      local jq_error
      jq_error=$(jq -e '\''type == "object"'\'' .claude-sandbox.json 2>&1 >/dev/null) || {
        echo "Warning: Invalid .claude-sandbox.json: $jq_error" >&2
      }
      while IFS= read -r mount_spec; do
        if [ -n "$mount_spec" ]; then
          # Validate path exists and has no dangerous characters
          local mount_path="${mount_spec%%:*}"
          if [[ "$mount_path" =~ [[:cntrl:]] ]]; then
            echo "Warning: Skipping mount with invalid characters: $mount_path" >&2
            continue
          fi
          if [ ! -e "$mount_path" ]; then
            echo "Warning: Mount path does not exist: $mount_path" >&2
            continue
          fi
          extra_mounts+=(-v "$mount_spec")
        fi
      done < <(jq -r '\''(.mounts // [])[] |
        .path + ":" + .path + (if .readonly then ":ro" else "" end)'\'' \
        .claude-sandbox.json 2>/dev/null)
    fi
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
  echo "Warning: Neither .zshrc nor .bashrc found, creating $SHELL_RC"
  echo "If you use a different shell, add the function to your shell config manually."
fi

# Check if already installed (use precise pattern to avoid matching comments)
if grep -q "^claude-sandbox-apple()[[:space:]]*{" "$SHELL_RC" 2>/dev/null; then
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

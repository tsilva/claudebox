#!/bin/bash
#
# common.sh - Shared functions for claude-sandbox container scripts
#
# Required variables (must be set before sourcing):
#   RUNTIME_CMD   - Command to run (e.g., docker)
#   IMAGE_NAME    - Container image name
#   FUNCTION_NAME - Installed script name
#   RUNTIME_NAME  - Human-readable runtime name
#   INSTALL_HINT  - Installation instructions for missing runtime
#   REPO_ROOT     - Path to repository root
#

set -e

# Validate that all required configuration variables are set
validate_config() {
  local missing=()
  local required_vars=(RUNTIME_CMD IMAGE_NAME FUNCTION_NAME RUNTIME_NAME INSTALL_HINT REPO_ROOT)

  for var in "${required_vars[@]}"; do
    [ -z "${!var:-}" ] && missing+=("$var")
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Error: Missing required configuration variables: ${missing[*]}" >&2
    exit 1
  fi
}

# Check if the runtime CLI is available and the daemon is running
check_runtime() {
  if ! command -v "$RUNTIME_CMD" &>/dev/null; then
    echo "Error: $RUNTIME_NAME is not installed or not in PATH"
    echo "$INSTALL_HINT"
    exit 1
  fi

  if ! "$RUNTIME_CMD" info &>/dev/null 2>&1; then
    echo "Error: $RUNTIME_NAME daemon is not running." >&2
    echo "Please start $RUNTIME_NAME Desktop and try again." >&2
    exit 1
  fi
}

# Validate config and check runtime in one call
ensure_ready() {
  validate_config
  check_runtime
}

# Detect shell config file (.zshrc or .bashrc)
# Sets SHELL_RC variable
detect_shell_rc() {
  if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  else
    SHELL_RC="$HOME/.zshrc"
    echo "Warning: Neither .zshrc nor .bashrc found, creating $SHELL_RC"
    echo "If you use a different shell, add the function to your shell config manually."
  fi
}

# Read version from VERSION file
get_version() {
  local version_file="${REPO_ROOT}/VERSION"
  if [ -f "$version_file" ]; then
    cat "$version_file" | tr -d '[:space:]'
  else
    echo "unknown"
  fi
}

# Build container image
do_build() {
  ensure_ready

  echo "Building $IMAGE_NAME image..."
  "$RUNTIME_CMD" build -t "$IMAGE_NAME" "$REPO_ROOT"

  echo ""
  echo "Done! Image '$IMAGE_NAME' is ready."
  echo "Run '$FUNCTION_NAME' from any directory to start."
}

# Install standalone script
do_install() {
  # Build the image first (calls ensure_ready)
  do_build

  detect_shell_rc

  # Generate and install the standalone script
  local bin_dir="$HOME/.claude-sandbox/bin"
  local script_path="$bin_dir/$FUNCTION_NAME"
  mkdir -p "$bin_dir"

  sed -e "s|PLACEHOLDER_RUNTIME_CMD|$RUNTIME_CMD|g" \
    -e "s|PLACEHOLDER_IMAGE_NAME|$IMAGE_NAME|g" \
    -e "s|PLACEHOLDER_FUNCTION_NAME|$FUNCTION_NAME|g" \
    "${REPO_ROOT}/scripts/claude-sandbox-template.sh" > "$script_path"
  chmod +x "$script_path"
  echo "Installed $script_path"

  # Add PATH entry if not already present
  local path_line='export PATH="$HOME/.claude-sandbox/bin:$PATH"'
  if ! grep -qF '.claude-sandbox/bin' "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# claude-sandbox" >> "$SHELL_RC"
    echo "$path_line" >> "$SHELL_RC"
    echo "Added PATH entry to $SHELL_RC"
  else
    echo "PATH entry already present in $SHELL_RC"
  fi

  echo ""
  echo "Installation complete!"
  echo ""
  echo "Run: source $SHELL_RC"
  echo ""
  echo "First-time setup (authenticate with Claude subscription):"
  echo "  $FUNCTION_NAME login"
  echo ""
  echo "Then from any project directory:"
  echo "  cd <your-project> && $FUNCTION_NAME"
  echo ""
  echo "To inspect the sandbox environment:"
  echo "  $FUNCTION_NAME shell"
}

# Uninstall image and shell function
do_uninstall() {
  ensure_ready

  # Prompt for confirmation
  read -p "This will remove the $IMAGE_NAME image and shell function. Continue? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
  fi

  echo "Removing $IMAGE_NAME image..."
  "$RUNTIME_CMD" image rm "$IMAGE_NAME" 2>/dev/null || echo "Image not found, skipping"

  # Remove standalone script
  local script_path="$HOME/.claude-sandbox/bin/$FUNCTION_NAME"
  if [ -f "$script_path" ]; then
    rm -f "$script_path"
    echo "Removed $script_path"
  else
    echo "Script not found at $script_path, skipping"
  fi

  detect_shell_rc

  # Remove PATH entry and comment from shell config
  if grep -qF '.claude-sandbox/bin' "$SHELL_RC" 2>/dev/null; then
    echo "Removing PATH entry from $SHELL_RC..."
    sed -i.bak '/^# claude-sandbox$/d;/\.claude-sandbox\/bin/d' "$SHELL_RC"
    rm -f "$SHELL_RC.bak"
    echo "PATH entry removed."
  else
    echo "PATH entry not found in $SHELL_RC, skipping"
  fi

  echo ""
  echo "Uninstall complete."
  echo ""
  echo "Run: source $SHELL_RC"
}

# Stop all running containers for this image
do_kill_containers() {
  ensure_ready

  echo "Finding running $IMAGE_NAME containers..."

  local containers
  containers=$("$RUNTIME_CMD" ps -q --filter "ancestor=$IMAGE_NAME" 2>/dev/null)

  if [ -z "$containers" ]; then
    echo "No $IMAGE_NAME containers found running."
    return 0
  fi

  echo "Stopping containers..."
  for id in $containers; do
    echo "  - $id"
    "$RUNTIME_CMD" stop "$id" 2>/dev/null || "$RUNTIME_CMD" kill "$id" 2>/dev/null || true
  done

  echo ""
  echo "All $IMAGE_NAME containers stopped."
}

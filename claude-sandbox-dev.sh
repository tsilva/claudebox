#!/bin/bash
#
# claude-sandbox-dev.sh - Development CLI for claude-sandbox
#
# Usage: ./claude-sandbox-dev.sh <command>
#
# Commands:
#   build      Build the Docker image
#   install    Build image and install standalone script
#   uninstall  Remove image and standalone script
#   kill       Stop all running containers
#   update     Pull latest changes and rebuild
#
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="claude-sandbox"
SCRIPT_NAME="claude-sandbox"

# Check if Docker CLI is available and the daemon is running
check_runtime() {
  if ! command -v docker &>/dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    echo "Please install Docker Desktop: https://docs.docker.com/get-docker/"
    exit 1
  fi

  if ! docker info &>/dev/null 2>&1; then
    echo "Error: Docker daemon is not running." >&2
    echo "Please start Docker Desktop and try again." >&2
    exit 1
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
  check_runtime

  echo "Building $IMAGE_NAME image..."
  docker build -t "$IMAGE_NAME" "$REPO_ROOT"

  echo ""
  echo "Done! Image '$IMAGE_NAME' is ready."
  echo "Run '$SCRIPT_NAME' from any directory to start."
}

# Install standalone script
do_install() {
  # Build the image first (calls check_runtime)
  do_build

  # Detect shell rc
  if [ -f "$HOME/.zshrc" ]; then
    shell_rc="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    shell_rc="$HOME/.bashrc"
  else
    shell_rc="$HOME/.zshrc"
    echo "Warning: Neither .zshrc nor .bashrc found, creating $shell_rc"
    echo "If you use a different shell, add the function to your shell config manually."
  fi

  # Generate and install the standalone script
  local bin_dir="$HOME/.claude-sandbox/bin"
  local script_path="$bin_dir/$SCRIPT_NAME"
  mkdir -p "$bin_dir"

  sed -e "s|PLACEHOLDER_IMAGE_NAME|$IMAGE_NAME|g" \
    -e "s|PLACEHOLDER_FUNCTION_NAME|$SCRIPT_NAME|g" \
    "${REPO_ROOT}/scripts/claude-sandbox-template.sh" > "$script_path"
  chmod +x "$script_path"
  echo "Installed $script_path"

  # Add PATH entry if not already present
  local path_line='export PATH="$HOME/.claude-sandbox/bin:$PATH"'
  if ! grep -qF '.claude-sandbox/bin' "$shell_rc" 2>/dev/null; then
    echo "" >> "$shell_rc"
    echo "# claude-sandbox" >> "$shell_rc"
    echo "$path_line" >> "$shell_rc"
    echo "Added PATH entry to $shell_rc"
  else
    echo "PATH entry already present in $shell_rc"
  fi

  echo ""
  echo "Installation complete!"
  echo ""
  echo "Run: source $shell_rc"
  echo ""
  echo "First-time setup (authenticate with Claude subscription):"
  echo "  $SCRIPT_NAME login"
  echo ""
  echo "Then from any project directory:"
  echo "  cd <your-project> && $SCRIPT_NAME"
  echo ""
  echo "To inspect the sandbox environment:"
  echo "  $SCRIPT_NAME shell"
}

# Uninstall image and standalone script
do_uninstall() {
  check_runtime

  # Prompt for confirmation
  read -p "This will remove the $IMAGE_NAME image and standalone script. Continue? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
  fi

  echo "Removing $IMAGE_NAME image..."
  docker image rm "$IMAGE_NAME" 2>/dev/null || echo "Image not found, skipping"

  # Remove standalone script
  local script_path="$HOME/.claude-sandbox/bin/$SCRIPT_NAME"
  if [ -f "$script_path" ]; then
    rm -f "$script_path"
    echo "Removed $script_path"
  else
    echo "Script not found at $script_path, skipping"
  fi

  # Detect shell rc
  if [ -f "$HOME/.zshrc" ]; then
    shell_rc="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    shell_rc="$HOME/.bashrc"
  else
    shell_rc="$HOME/.zshrc"
  fi

  # Remove PATH entry and comment from shell config
  if grep -qF '.claude-sandbox/bin' "$shell_rc" 2>/dev/null; then
    echo "Removing PATH entry from $shell_rc..."
    sed -i.bak '/^# claude-sandbox$/d;/\.claude-sandbox\/bin/d' "$shell_rc"
    rm -f "$shell_rc.bak"
    echo "PATH entry removed."
  else
    echo "PATH entry not found in $shell_rc, skipping"
  fi

  echo ""
  echo "Uninstall complete."
  echo ""
  echo "Run: source $shell_rc"
}

# Stop all running containers for this image
do_kill_containers() {
  check_runtime

  echo "Finding running $IMAGE_NAME containers..."

  local containers
  containers=$(docker ps -q --filter "ancestor=$IMAGE_NAME" 2>/dev/null)

  if [ -z "$containers" ]; then
    echo "No $IMAGE_NAME containers found running."
    return 0
  fi

  echo "Stopping containers..."
  for id in $containers; do
    echo "  - $id"
    docker stop "$id" 2>/dev/null || docker kill "$id" 2>/dev/null || true
  done

  echo ""
  echo "All $IMAGE_NAME containers stopped."
}

cmd="${1:-}"

case "$cmd" in
  build)
    do_build
    ;;
  install)
    do_install
    ;;
  uninstall)
    do_uninstall
    ;;
  kill)
    do_kill_containers
    ;;
  update)
    cd "$REPO_ROOT"
    echo "Pulling latest changes..."
    git pull
    do_build
    ;;
  *)
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  build      Build the Docker image"
    echo "  install    Build image and install standalone script"
    echo "  uninstall  Remove image and standalone script"
    echo "  kill       Stop all running containers"
    echo "  update     Pull latest changes and rebuild"
    exit 1
    ;;
esac

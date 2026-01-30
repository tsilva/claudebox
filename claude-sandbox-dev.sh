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

# Docker configuration
RUNTIME_CMD="docker"
IMAGE_NAME="claude-sandbox"
FUNCTION_NAME="claude-sandbox"
RUNTIME_NAME="Docker"
INSTALL_HINT="Please install Docker Desktop: https://docs.docker.com/get-docker/"

source "$REPO_ROOT/scripts/common.sh"

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

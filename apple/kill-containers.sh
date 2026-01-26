#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RUNTIME_CMD="container"
IMAGE_NAME="claude-sandbox-apple"
FUNCTION_NAME="claude-sandbox-apple"
RUNTIME_NAME="Apple Container CLI"
INSTALL_HINT="Please install with: brew install --cask container
Requires macOS 26+ and Apple Silicon"
FUNCTION_COMMENT="Claude Sandbox (Apple Container) - run Claude Code in an isolated container"

source "$REPO_ROOT/scripts/common.sh"
do_kill_containers
